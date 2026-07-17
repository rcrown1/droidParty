//
//  BLEManager.swift
//  SWSphero
//
//  Central BLE manager handling scanning, connection, service discovery,
//  characteristic interaction, handshake, and keepalive.
//
//  This is the primary transport layer. It is protocol-agnostic in its core
//  scanning/connection logic but delegates to DroidProtocol implementations
//  for handshake sequences and packet parsing.
//

import Foundation
import CoreBluetooth
import Combine
import os.log

// MARK: - BLE Manager

@MainActor
final class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    /// All discovered droid devices, keyed by peripheral UUID.
    @Published private(set) var discoveredDroids: [UUID: DroidDevice] = [:]
    
    /// Whether we are currently scanning for peripherals.
    @Published private(set) var isScanning: Bool = false
    
    /// Bluetooth adapter state.
    @Published private(set) var centralState: CBManagerState = .unknown
    
    /// Most recent BLE event description (for quick status display).
    @Published private(set) var lastEvent: String = ""
    
    /// Publishes parsed packet metadata for subscriber controllers (e.g., SensorController).
    let packetReceived = PassthroughSubject<(deviceID: UUID, metadata: PacketMetadata), Never>()
    
    // MARK: - Internal State
    
    private var centralManager: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var peripheralDelegates: [UUID: PeripheralDelegate] = [:]
    private var keepaliveTimers: [UUID: Task<Void, Never>] = [:]
    
    /// Dedicated serial queue for CoreBluetooth delegate callbacks.
    /// Using a dedicated queue prevents the main queue from being overwhelmed
    /// by rapid BLE notifications, which can cause characteristic.value to be
    /// overwritten before the callback is processed — resulting in lost bytes.
    private let bleQueue = DispatchQueue(label: "com.swsphero.ble", qos: .userInitiated)
    
    /// Cached CBCharacteristic references keyed by [peripheralUUID: [characteristicUUID: CBCharacteristic]].
    /// Populated during service/characteristic discovery on bleQueue, read from @MainActor for writes.
    /// This avoids accessing peripheral.services from the wrong queue.
    fileprivate var characteristicCache: [UUID: [CBUUID: CBCharacteristic]] = [:]
    
    /// Continuation-based async bridges for connection/disconnection.
    private var connectionContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    
    /// Tracks reconnection attempts per device.
    private var reconnectAttempts: [UUID: Int] = [:]
    private let maxReconnectAttempts = 3
    
    private let logger: BLELogger
    private let registry: ProtocolRegistry
    
    // MARK: - Configuration
    
    /// Whether to auto-filter for known Sphero devices during scanning.
    /// When false, ALL BLE peripherals are reported (useful for exploration).
    var filterForSpheroDevices: Bool = true
    
    /// Whether to auto-subscribe to response notifications after service discovery.
    var autoSubscribeNotifications: Bool = true
    
    // MARK: - Init
    
    init(logger: BLELogger? = nil, registry: ProtocolRegistry? = nil) {
        self.logger = logger ?? BLELogger.shared
        self.registry = registry ?? ProtocolRegistry.shared
        super.init()
        // Use the dedicated BLE serial queue for CoreBluetooth callbacks.
        // This ensures rapid notifications don't lose bytes. All CBPeripheral
        // operations (write, setNotify) must be dispatched to this queue.
        self.centralManager = CBCentralManager(delegate: self, queue: bleQueue)
    }
    
    // MARK: - Scanning
    
    /// Start scanning for BLE peripherals.
    func startScanning() {
        guard centralState == .poweredOn else {
            logger.warning(.scan, "Cannot scan: Bluetooth is \(centralState.displayName)")
            return
        }
        
        isScanning = true
        lastEvent = "Scanning..."
        logger.info(.scan, "Started BLE scanning")
        
        // Scan with duplicate reporting enabled for RSSI updates
        bleQueue.async {
            self.centralManager.scanForPeripherals(
                withServices: nil, // Scan for all — we filter in didDiscover
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }
    
    /// Stop scanning for BLE peripherals.
    func stopScanning() {
        bleQueue.async {
            self.centralManager.stopScan()
        }
        isScanning = false
        lastEvent = "Scan stopped"
        logger.info(.scan, "Stopped BLE scanning")
    }
    
    // MARK: - Connection
    
    /// Connect to a discovered droid.
    func connect(to deviceID: UUID) async throws {
        guard let peripheral = peripherals[deviceID] else {
            throw BLEError.peripheralNotFound
        }
        
        // Reset reconnect counter on manual connect
        reconnectAttempts.removeValue(forKey: deviceID)
        
        updateDeviceState(deviceID, state: .connecting)
        logger.info(.connect, "Connecting to \(deviceID.uuidString.prefix(8))...")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuations[deviceID] = continuation
            self.bleQueue.async {
                self.centralManager.connect(peripheral, options: nil)
            }
        }
        
        // Connection succeeded — now discover services
        updateDeviceState(deviceID, state: .discovering)
        logger.info(.connect, "Connected. Discovering services...")
        
        let proto = protocolForDevice(deviceID)
        
        // Create and configure the peripheral delegate
        let delegate = PeripheralDelegate(
            deviceID: deviceID,
            droidProtocol: proto,
            manager: self
        )
        peripheralDelegates[deviceID] = delegate
        
        // Set delegate and discover services on bleQueue (where CBPeripheral lives)
        bleQueue.async {
            peripheral.delegate = delegate
            peripheral.discoverServices(nil) // nil = discover all
        }
    }
    
    /// Disconnect from a connected droid.
    ///
    /// Plays a farewell sound sequence before severing the connection, giving the
    /// droid time to play the audio before the BLE link drops.
    func disconnect(from deviceID: UUID) {
        guard let peripheral = peripherals[deviceID] else { return }
        
        // Cancel keepalive
        keepaliveTimers[deviceID]?.cancel()
        keepaliveTimers.removeValue(forKey: deviceID)
        
        // Prevent auto-reconnect after deliberate disconnect
        reconnectAttempts[deviceID] = maxReconnectAttempts
        
        updateDeviceState(deviceID, state: .disconnecting)
        logger.info(.connect, "Disconnecting from \(deviceID.uuidString.prefix(8))...")
        
        // Play farewell sequence then sever the connection
        Task {
            if let device = discoveredDroids[deviceID] {
                await playFarewellSequence(for: deviceID, droidType: device.droidType)
            }
            self.bleQueue.async {
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    // MARK: - Handshake
    
    /// Perform the droid wake/init handshake after service/characteristic discovery.
    ///
    /// Confirmed sequence (from spherov2.js core.ts and freer2 project):
    /// 1. Write "usetheforce...band" to 00020005 (anti—DoS) — with response
    /// 2. Subscribe to 00020002 (DFU control) for notifications
    /// 3. Subscribe to 00010002 (API v2) for notifications
    /// 4. Wait for first notification on 00010002 (handshake confirmation from droid)
    /// 5. Send wake command (DID=0x13, CID=0x0D) as v2 packet on 00010002
    ///
    /// For R2-D2/R2-Q5 (dual-processor droids), post-wake commands need
    /// TID/SID routing to reach the STM32 processor.
    func performHandshake(for deviceID: UUID) async {
        guard let peripheral = peripherals[deviceID] else { return }
        
        updateDeviceState(deviceID, state: .handshaking)
        let proto = protocolForDevice(deviceID)
        let steps = proto.handshakeSequence()
        let isRSeries = proto.family == .rSeries
        
        logger.info(.handshake, "Starting handshake for \(deviceID.uuidString.prefix(8)) (family: \(proto.family))")
        
        // Step 1: Write anti-DoS and any legacy init commands.
        // The anti-DoS MUST be written BEFORE subscribing to notifications.
        for (index, step) in steps.enumerated() {
            guard let characteristic = findCharacteristic(step.characteristicUUID, on: peripheral) else {
                logger.warning(.handshake, "Step \(index + 1): Characteristic \(step.characteristicUUID) not found — skipping")
                continue
            }
            
            let packet = BLEPacket(
                direction: .tx,
                characteristicUUID: step.characteristicUUID.uuidString,
                rawData: step.data
            )
            logger.logPacket(packet, message: "Handshake step \(index + 1)/\(steps.count)")
            
            // Use write-with-response when available (matches spherov2.js behavior).
            let writeType: CBCharacteristicWriteType
            if characteristic.properties.contains(.write) {
                writeType = .withResponse
            } else {
                writeType = .withoutResponse
            }
            let stepData = step.data
            bleQueue.async {
                peripheral.writeValue(stepData, for: characteristic, type: writeType)
            }
            
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms between steps
        }
        
        // Step 2: Subscribe to DFU control characteristic (00020002) for notifications.
        if let dfuChr = findCharacteristic(SpheroUUID.v2DFUControl, on: peripheral) {
            bleQueue.async {
                peripheral.setNotifyValue(true, for: dfuChr)
            }
            logger.info(.handshake, "Subscribed to DFU control (00020002)")
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Step 3: Subscribe to API v2 characteristic (00010002) for notifications.
        if let apiChr = findCharacteristic(SpheroUUID.v2APICommand, on: peripheral) {
            bleQueue.async {
                peripheral.setNotifyValue(true, for: apiChr)
            }
            logger.info(.handshake, "Subscribed to API v2 (00010002)")
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Also subscribe to legacy response characteristic if present
        if let legacyChr = findCharacteristic(SpheroUUID.legacyResponse, on: peripheral) {
            bleQueue.async {
                peripheral.setNotifyValue(true, for: legacyChr)
            }
            logger.info(.handshake, "Subscribed to legacy response")
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Step 4: Wait for handshake confirmation notification.
        // R2-D2 units can take longer than BB-8 to respond after anti-DoS.
        // Use a longer timeout for R-series droids.
        let waitTime: UInt64 = isRSeries ? 1_000_000_000 : 500_000_000
        try? await Task.sleep(nanoseconds: waitTime)
        logger.info(.handshake, "Waited for handshake confirmation (\(isRSeries ? "1.0s R-series" : "0.5s BB-series"))")
        
        // Step 5: Send wake command (DID=0x13 Power, CID=0x0D Wake).
        // This activates the droid's command processor.
        // The wake command targets the BLE processor itself, so no TID/SID needed.
        var encoder = PacketEncoder()
        let wakePacket = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.powerInfo,
            commandID: SpheroV2PowerCommand.wake
        )
        if let apiChr = findCharacteristic(SpheroUUID.v2APICommand, on: peripheral) {
            let packet = BLEPacket(
                direction: .tx,
                characteristicUUID: SpheroUUID.v2APICommand.uuidString,
                rawData: wakePacket
            )
            logger.logPacket(packet, message: "Wake command (DID=0x13, CID=0x0D)")
            let wakeData = wakePacket
            bleQueue.async {
                peripheral.writeValue(wakeData, for: apiChr, type: .withoutResponse)
            }
        }
        
        // Wait for wake to take effect.
        // R-series droids need longer to initialize their STM32 processor.
        let wakeWait: UInt64 = isRSeries ? 1_500_000_000 : 500_000_000
        try? await Task.sleep(nanoseconds: wakeWait)
        logger.info(.handshake, "Wake settle complete (\(isRSeries ? "1.5s R-series" : "0.5s BB-series"))")
        
        // For R-series: send a second (non-routed) wake to ensure STM32 is active.
        // Per spherov2.py reference: standard v2 commands do NOT need TID/SID routing.
        // The BLE chip auto-forwards to the STM32.
        if isRSeries {
            let secondWake = encoder.encodeV2(
                deviceID: SpheroV2DeviceID.powerInfo,
                commandID: SpheroV2PowerCommand.wake
            )
            if let apiChr = findCharacteristic(SpheroUUID.v2APICommand, on: peripheral) {
                let packet = BLEPacket(
                    direction: .tx,
                    characteristicUUID: SpheroUUID.v2APICommand.uuidString,
                    rawData: secondWake
                )
                logger.logPacket(packet, message: "R-series: Second wake (non-routed)")
                let secondWakeData = secondWake
                bleQueue.async {
                    peripheral.writeValue(secondWakeData, for: apiChr, type: .withoutResponse)
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms for STM32 wake
            }
        }
        
        // Mark ready
        updateDeviceState(deviceID, state: .ready)
        logger.info(.handshake, "Handshake complete — droid is ready")
        
        // Start keepalive
        startKeepalive(for: deviceID)
        
        // Play greeting sequence
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms settle
        if let device = discoveredDroids[deviceID] {
            await playGreetingSequence(for: deviceID, droidType: device.droidType)
        }
        
        // Subscribe to any additional Sphero-related notifications
        if autoSubscribeNotifications {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms settle
            subscribeToNotifications(for: deviceID)
        }
    }
    
    // MARK: - Write Operations
    
    /// Write raw data to a specific characteristic on a connected peripheral.
    /// This is the primary method for protocol exploration and debugging.
    func writeRawData(_ data: Data, to characteristicUUID: CBUUID, deviceID: UUID, withResponse: Bool = true) {
        guard let peripheral = peripherals[deviceID] else {
            logger.error(.packet, "Write failed: peripheral not found")
            return
        }
        
        guard let characteristic = findCharacteristic(characteristicUUID, on: peripheral) else {
            logger.error(.packet, "Write failed: characteristic \(characteristicUUID) not found")
            return
        }
        
        let packet = BLEPacket(
            direction: .tx,
            characteristicUUID: characteristicUUID.uuidString,
            rawData: data
        )
        logger.logPacket(packet, message: "Raw write")
        
        let writeType: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse
        // Dispatch write to the BLE queue since CBPeripheral belongs to it
        bleQueue.async {
            peripheral.writeValue(data, for: characteristic, type: writeType)
        }
    }
    
    /// Write an encoded command using the droid's protocol.
    func sendCommand(deviceID: UInt8, commandID: UInt8, payload: Data = Data(), to droidDeviceID: UUID) {
        let proto = protocolForDevice(droidDeviceID)
        let encoded = proto.encodeCommand(deviceID: deviceID, commandID: commandID, payload: payload)
        
        if let cmdChar = proto.commandCharacteristicUUID {
            writeRawData(encoded, to: cmdChar, deviceID: droidDeviceID)
        } else {
            logger.error(.packet, "No command characteristic defined for this droid's protocol")
        }
    }
    
    // MARK: - Sound Playback
    
    /// Play a sound on a connected droid via the v2 playAudioFile command.
    ///
    /// Uses the droid's drive profile to encode the sound command and writes
    /// it to the appropriate characteristic.
    func playSound(for deviceID: UUID, soundID: UInt16) {
        guard let peripheral = peripherals[deviceID],
              peripheral.state == .connected else {
            logger.warning(.packet, "Cannot play sound: peripheral not connected")
            return
        }
        
        guard let device = discoveredDroids[deviceID] else { return }
        
        let profile = DriveProfileFactory.profile(for: device.droidType, discoveredServices: device.discoveredServices)
        var encoder = PacketEncoder()
        
        guard let command = profile.encodeSoundCommand(soundID: soundID, encoder: &encoder) else {
            logger.warning(.packet, "Sound command encoding failed for \(device.droidType.displayName)")
            return
        }
        
        guard let characteristic = findCharacteristic(command.characteristicUUID, on: peripheral) else {
            logger.warning(.packet, "Sound command characteristic not found")
            return
        }
        
        let packet = BLEPacket(
            direction: .tx,
            characteristicUUID: command.characteristicUUID.uuidString,
            rawData: command.data
        )
        logger.logPacket(packet, message: "Play sound (ID: \(soundID))")
        
        // Use writeWithoutResponse for v2 API commands (fire-and-forget)
        let cmdData = command.data
        bleQueue.async {
            peripheral.writeValue(cmdData, for: characteristic, type: .withoutResponse)
        }
    }
    
    /// Play an animation on a connected droid via the v2 playAnimation command.
    func playAnimation(for deviceID: UUID, animationID: UInt8) {
        guard let peripheral = peripherals[deviceID],
              peripheral.state == .connected else { return }
        
        guard let device = discoveredDroids[deviceID] else { return }
        
        let profile = CapabilityProfileFactory.profile(for: device.droidType, discoveredServices: device.discoveredServices)
        var encoder = PacketEncoder()
        
        guard let command = profile.encodePlayAnimation(id: animationID, encoder: &encoder) else { return }
        guard let characteristic = findCharacteristic(command.characteristicUUID, on: peripheral) else { return }
        
        let cmdData = command.data
        bleQueue.async {
            peripheral.writeValue(cmdData, for: characteristic, type: .withoutResponse)
        }
        logger.info(.packet, "Play animation ID=\(animationID)")
    }
    
    /// Play the startup greeting sequence for a droid.
    /// R2-D2: Excited animation + positive sound.
    /// R2-Q5: Excited animation + positive sound.
    /// BB-9E: Greetings animation.
    /// BB-8: Single happy sound (no animation support).
    private func playGreetingSequence(for deviceID: UUID, droidType: DroidType) async {
        switch droidType {
        case .r2d2:
            // Excited animation (ID 12) — droid will wiggle with sound
            playAnimation(for: deviceID, animationID: 12)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            // Follow up with a positive sound
            playSound(for: deviceID, soundID: 3302) // R2_POSITIVE_1
            
        case .r2q5:
            playAnimation(for: deviceID, animationID: 12) // Excited
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // Use a Q5-confirmed positive sound (discovered via hardware testing)
            if let sound = SoundBank.randomSound(category: "Positive", for: .r2q5) {
                playSound(for: deviceID, soundID: sound.id)
            }
            
        case .bb9e:
            playAnimation(for: deviceID, animationID: 11) // Greetings
            
        case .bb8:
            playSound(for: deviceID, soundID: SpheroAudioID.bb8Happy)
            
        case .unknownSphero:
            playSound(for: deviceID, soundID: SpheroAudioID.genericBeep)
        }
        
        logger.info(.handshake, "Greeting sequence played for \(droidType.displayName)")
    }
    
    /// Play the shutdown farewell sequence before disconnecting.
    /// R2-D2: SAD_4 (id 3693). R2-Q5: random rich Sad sound.
    /// Others: single sad sound.
    private func playFarewellSequence(for deviceID: UUID, droidType: DroidType) async {
        switch droidType {
        case .r2d2:
            playSound(for: deviceID, soundID: 3693) // R2_SAD_4
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s for the rich sound
            
        case .r2q5:
            // Q5 now has rich sad sounds from hardware testing
            if let sound = SoundBank.randomSound(category: "Sad", for: .r2q5) {
                playSound(for: deviceID, soundID: sound.id)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s for the rich sound
            }
            
        case .bb9e:
            playSound(for: deviceID, soundID: SpheroAudioID.bb9eSad)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
        default:
            break
        }
        
        logger.info(.connect, "Farewell sequence played for \(droidType.displayName)")
    }
    
    // MARK: - Notification Subscription
    
    /// Subscribe to notifications on relevant characteristics for a device.
    ///
    /// Only subscribes to Sphero protocol-related characteristics to avoid
    /// overwhelming the droid firmware with notification requests on
    /// standard/unrelated services (which can cause disconnections).
    func subscribeToNotifications(for deviceID: UUID) {
        guard let peripheral = peripherals[deviceID] else { return }
        guard let cachedChars = characteristicCache[deviceID] else { return }
        
        let proto = protocolForDevice(deviceID)
        
        // Build a set of UUIDs we actually care about notifications on
        var relevantUUIDs = Set<CBUUID>()
        if let responseUUID = proto.responseCharacteristicUUID {
            relevantUUIDs.insert(responseUUID)
        }
        if let cmdUUID = proto.commandCharacteristicUUID {
            relevantUUIDs.insert(cmdUUID)
        }
        // Also include legacy response characteristic
        relevantUUIDs.insert(SpheroUUID.legacyResponse)
        
        // Known Sphero service UUID prefixes
        let spheroServicePrefixes = ["22BB746F", "00010001", "00020001", "00020005"]
        
        for (uuid, characteristic) in cachedChars {
            let isNotifiable = characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
            guard isNotifiable else { continue }
            
            let uuidStr = uuid.uuidString
            let isKnownSphero = spheroServicePrefixes.contains { uuidStr.hasPrefix($0) }
            let isRelevant = relevantUUIDs.contains(uuid) || isKnownSphero
            
            if isRelevant {
                let char = characteristic
                bleQueue.async {
                    peripheral.setNotifyValue(true, for: char)
                }
                logger.debug(.service, "Notifications ON for \(uuid)")
            } else {
                logger.trace(.service, "Skipping notifications for non-Sphero characteristic \(uuid)")
            }
        }
    }
    
    // MARK: - Keepalive
    
    /// Start periodic keepalive pings to prevent the droid from sleeping.
    private func startKeepalive(for deviceID: UUID) {
        // Cancel any existing timer
        keepaliveTimers[deviceID]?.cancel()
        
        let proto = protocolForDevice(deviceID)
        let interval = proto.keepaliveInterval
        
        keepaliveTimers[deviceID] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                
                guard !Task.isCancelled else { break }
                guard let self = self else { break }
                
                await MainActor.run {
                    guard let peripheral = self.peripherals[deviceID],
                          peripheral.state == .connected else { return }
                    
                    if let keepalive = proto.keepalivePacket(),
                       let characteristic = self.findCharacteristic(keepalive.characteristicUUID, on: peripheral) {
                        let packet = BLEPacket(
                            direction: .tx,
                            characteristicUUID: keepalive.characteristicUUID.uuidString,
                            rawData: keepalive.data
                        )
                        self.logger.logPacket(packet, message: "Keepalive ping")
                        let keepaliveData = keepalive.data
                        self.bleQueue.async {
                            peripheral.writeValue(keepaliveData, for: characteristic, type: .withoutResponse)
                        }
                    }
                }
            }
        }
        
        logger.info(.keepalive, "Keepalive started (interval: \(interval)s)")
    }
    
    // MARK: - Auto-Reconnect
    
    /// Attempt to reconnect to a droid that disconnected unexpectedly.
    private func attemptReconnect(deviceID: UUID) {
        let attempts = reconnectAttempts[deviceID, default: 0]
        guard attempts < maxReconnectAttempts else {
            logger.warning(.connect, "Max reconnect attempts (\(maxReconnectAttempts)) reached for \(deviceID.uuidString.prefix(8))")
            reconnectAttempts.removeValue(forKey: deviceID)
            return
        }
        
        reconnectAttempts[deviceID] = attempts + 1
        let attempt = attempts + 1
        logger.info(.connect, "Reconnect attempt \(attempt)/\(maxReconnectAttempts) for \(deviceID.uuidString.prefix(8))")
        
        Task {
            // Brief delay before reconnecting to let the BLE stack settle
            try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000) // 500ms * attempt
            
            do {
                try await self.connect(to: deviceID)
                // Success — reset counter
                self.reconnectAttempts.removeValue(forKey: deviceID)
                self.logger.info(.connect, "Reconnected successfully on attempt \(attempt)")
            } catch {
                self.logger.warning(.connect, "Reconnect attempt \(attempt) failed: \(error.localizedDescription)")
                // The didDisconnect delegate will trigger another attempt if needed
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Get the appropriate protocol for a device.
    private func protocolForDevice(_ deviceID: UUID) -> DroidProtocol {
        guard let device = discoveredDroids[deviceID] else {
            return registry.protocolFor(family: .unknown)
        }
        return registry.protocolFor(droidType: device.droidType)
    }
    
    /// Find a characteristic by UUID on a peripheral.
    /// Uses the local cache populated during discovery, avoiding cross-queue
    /// access to CBPeripheral.services.
    private func findCharacteristic(_ uuid: CBUUID, on peripheral: CBPeripheral) -> CBCharacteristic? {
        return characteristicCache[peripheral.identifier]?[uuid]
    }
    
    // Characteristic caching is done inline in PeripheralDelegate.didDiscoverCharacteristicsFor
    // using data captured on bleQueue before dispatch to MainActor.
    
    /// Update a device's connection state.
    func updateDeviceState(_ deviceID: UUID, state: ConnectionState) {
        discoveredDroids[deviceID]?.connectionState = state
    }
    
    /// Accumulated service/characteristic info captured on bleQueue during discovery.
    /// Keyed by [peripheralUUID: [serviceUUID: [(charUUID, properties, isNotifying)]]].
    fileprivate var discoveredServiceInfo: [UUID: [(serviceUUID: String, chars: [(uuid: String, props: CBCharacteristicProperties, isNotifying: Bool)])]] = [:]
    
    /// Record discovered characteristics for a service (called from PeripheralDelegate on MainActor
    /// with data already captured on bleQueue).
    func recordDiscoveredService(
        _ deviceID: UUID,
        serviceUUID: String,
        characteristics: [(uuid: String, props: CBCharacteristicProperties, isNotifying: Bool)]
    ) {
        var existing = discoveredServiceInfo[deviceID] ?? []
        // Replace if we already have this service (re-discovery)
        existing.removeAll { $0.serviceUUID == serviceUUID }
        existing.append((serviceUUID: serviceUUID, chars: characteristics))
        discoveredServiceInfo[deviceID] = existing
        
        // Rebuild the UI model from accumulated info
        var services: [DiscoveredService] = []
        for svc in existing {
            var chars: [DiscoveredCharacteristic] = []
            for c in svc.chars {
                chars.append(DiscoveredCharacteristic(
                    id: c.uuid,
                    uuid: c.uuid,
                    name: SpheroCharacteristicIdentifier.name(for: c.uuid),
                    properties: CharacteristicProperties(cbProperties: c.props),
                    isNotifying: c.isNotifying
                ))
            }
            services.append(DiscoveredService(
                id: svc.serviceUUID,
                uuid: svc.serviceUUID,
                name: SpheroServiceIdentifier.name(for: svc.serviceUUID),
                characteristics: chars
            ))
        }
        discoveredDroids[deviceID]?.discoveredServices = services
    }
    
    /// Sorted array of discovered droids for display.
    var sortedDroids: [DroidDevice] {
        discoveredDroids.values.sorted { a, b in
            // Connected droids first, then by RSSI
            if a.connectionState.isConnected != b.connectionState.isConnected {
                return a.connectionState.isConnected
            }
            return a.rssi > b.rssi
        }
    }
    
    /// Remove stale devices that haven't been seen recently.
    func pruneStaleDevices(olderThan seconds: TimeInterval = 30) {
        let cutoff = Date().addingTimeInterval(-seconds)
        let staleIDs = discoveredDroids.filter { $0.value.lastSeen < cutoff && !$0.value.connectionState.isConnected }
        for id in staleIDs.keys {
            discoveredDroids.removeValue(forKey: id)
            peripherals.removeValue(forKey: id)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            self.centralState = state
            self.logger.info(.system, "Bluetooth state: \(state.displayName)")
            self.lastEvent = "Bluetooth: \(state.displayName)"
        }
    }
    
    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let deviceID = peripheral.identifier
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString }
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let rssiValue = RSSI.intValue
        
        Task { @MainActor in
            // Filter: only process Sphero devices (or all if filter is off)
            if self.filterForSpheroDevices {
                guard DroidIdentifier.isSpheroDevice(
                    name: name,
                    serviceUUIDs: serviceUUIDs,
                    manufacturerData: manufacturerData
                ) else { return }
            }
            
            let droidType = DroidIdentifier.classify(
                name: name,
                serviceUUIDs: serviceUUIDs,
                manufacturerData: manufacturerData
            )
            
            // Store CBPeripheral reference (required for connection)
            self.peripherals[deviceID] = peripheral
            
            if var existing = self.discoveredDroids[deviceID] {
                // Update existing entry
                existing.rssi = rssiValue
                existing.lastSeen = Date()
                if existing.connectionState == .disconnected {
                    // Only update type if we get better info
                    if droidType != .unknownSphero || existing.droidType == .unknownSphero {
                        // Keep the more specific classification
                    }
                }
                self.discoveredDroids[deviceID] = existing
            } else {
                // New discovery
                let device = DroidDevice(
                    id: deviceID,
                    peripheralName: name,
                    droidType: droidType,
                    rssi: rssiValue,
                    manufacturerData: manufacturerData,
                    advertisedServiceUUIDs: serviceUUIDs
                )
                self.discoveredDroids[deviceID] = device
                
                self.logger.info(.scan, "Discovered: \(device.displayName) (\(droidType.displayName)) RSSI: \(rssiValue)")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let deviceID = peripheral.identifier
        Task { @MainActor in
            self.logger.info(.connect, "Connected to \(deviceID.uuidString.prefix(8))")
            self.lastEvent = "Connected"
            
            // Resume the connection continuation
            if let continuation = self.connectionContinuations.removeValue(forKey: deviceID) {
                continuation.resume()
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let deviceID = peripheral.identifier
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        Task { @MainActor in
            self.logger.error(.connect, "Connection failed: \(errorMsg)")
            self.updateDeviceState(deviceID, state: .error(errorMsg))
            self.lastEvent = "Connection failed"
            
            if let continuation = self.connectionContinuations.removeValue(forKey: deviceID) {
                continuation.resume(throwing: error ?? BLEError.connectionFailed)
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceID = peripheral.identifier
        Task { @MainActor in
            self.keepaliveTimers[deviceID]?.cancel()
            self.keepaliveTimers.removeValue(forKey: deviceID)
            self.peripheralDelegates.removeValue(forKey: deviceID)
            
            if let error = error {
                self.logger.warning(.connect, "Disconnected unexpectedly: \(error.localizedDescription)")
                self.updateDeviceState(deviceID, state: .error("Disconnected: \(error.localizedDescription)"))
                
                // Auto-reconnect on unexpected disconnections
                self.logger.info(.connect, "Attempting auto-reconnect...")
                self.attemptReconnect(deviceID: deviceID)
            } else {
                self.logger.info(.connect, "Disconnected cleanly")
                self.updateDeviceState(deviceID, state: .disconnected)
            }
            self.lastEvent = "Disconnected"
        }
    }
}

// MARK: - Peripheral Delegate

/// Per-peripheral delegate that handles service/characteristic discovery and data.
/// Separated from BLEManager to cleanly manage per-device state.
///
/// IMPORTANT: CoreBluetooth may deliver v2 response packets as individual
/// 1-byte fragments (one didUpdateValueFor callback per byte). This delegate
/// maintains a persistent reassembly buffer per characteristic to accumulate
/// fragments until a complete v2 packet (0x8D...0xD8) is received.
private class PeripheralDelegate: NSObject, CBPeripheralDelegate {
    let deviceID: UUID
    let droidProtocol: DroidProtocol
    weak var manager: BLEManager?
    
    private var pendingServiceDiscoveries: Int = 0
    
    /// Persistent reassembly buffer per characteristic UUID.
    /// Accumulates fragmented v2 bytes until a complete packet is formed.
    private var reassemblyBuffers: [String: Data] = [:]
    
    /// Tracks the last received data per characteristic to deduplicate
    /// repeated didUpdateValueFor callbacks with the same value.
    private var lastReceivedData: [String: Data] = [:]
    
    /// Maximum buffer size before discarding (prevents unbounded memory growth).
    private let maxBufferSize = 256
    
    init(deviceID: UUID, droidProtocol: DroidProtocol, manager: BLEManager) {
        self.deviceID = deviceID
        self.droidProtocol = droidProtocol
        self.manager = manager
    }
    
    // MARK: - Service Discovery
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Capture service info on bleQueue before dispatching
        let services = peripheral.services ?? []
        let serviceUUIDs = services.map { $0.uuid.uuidString }
        
        // Kick off characteristic discovery immediately on bleQueue (where we already are)
        let serviceCount = services.count
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
        Task { @MainActor in
            guard self.manager != nil else { return }
            let logger = BLELogger.shared
            
            if let error = error {
                logger.error(.service, "Service discovery error: \(error.localizedDescription)")
                return
            }
            
            logger.info(.service, "Discovered \(serviceCount) services")
            
            for uuid in serviceUUIDs {
                logger.debug(.service, "  Service: \(uuid) — \(SpheroServiceIdentifier.name(for: uuid) ?? "Unknown")")
            }
            
            self.pendingServiceDiscoveries = serviceCount
        }
    }
    
    // MARK: - Characteristic Discovery
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Capture characteristics immediately on bleQueue before dispatching to MainActor.
        // This ensures CBPeripheral properties are read on the correct queue.
        let chars = service.characteristics ?? []
        let charInfos: [(uuid: CBUUID, ref: CBCharacteristic, propsRaw: CBCharacteristicProperties, isNotifying: Bool)] = chars.map {
            ($0.uuid, $0, $0.properties, $0.isNotifying)
        }
        let serviceUUIDStr = service.uuid.uuidString
        let serviceUUID = service.uuid
        
        Task { @MainActor in
            guard let manager = self.manager else { return }
            let logger = BLELogger.shared
            
            if let error = error {
                logger.error(.service, "Characteristic discovery error: \(error.localizedDescription)")
                return
            }
            
            logger.info(.service, "Service \(serviceUUID): \(charInfos.count) characteristics")
            
            for info in charInfos {
                let props = CharacteristicProperties(cbProperties: info.propsRaw)
                logger.debug(.service, "  Char: \(info.uuid) [\(props.labels.joined(separator: ", "))] — \(SpheroCharacteristicIdentifier.name(for: info.uuid.uuidString) ?? "Unknown")")
            }
            
            // Cache characteristic references for later writes from MainActor
            for info in charInfos {
                manager.characteristicCache[self.deviceID, default: [:]][info.uuid] = info.ref
            }
            
            self.pendingServiceDiscoveries -= 1
            
            // Update the device model using pre-captured data (no peripheral.services access)
            manager.recordDiscoveredService(
                self.deviceID,
                serviceUUID: serviceUUIDStr,
                characteristics: charInfos.map { (uuid: $0.uuid.uuidString, props: $0.propsRaw, isNotifying: $0.isNotifying) }
            )
            
            // When all services are done, trigger handshake
            if self.pendingServiceDiscoveries <= 0 {
                logger.info(.service, "All services and characteristics discovered")
                await manager.performHandshake(for: self.deviceID)
            }
        }
    }
    
    // MARK: - Value Updates (Notifications and Reads)
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // CRITICAL: Capture characteristic.value IMMEDIATELY on the BLE queue
        // before it can be overwritten by the next notification.
        // This callback runs on BLEManager's dedicated serial bleQueue.
        let capturedData: Data?
        if error == nil {
            capturedData = characteristic.value.flatMap { Data($0) }
        } else {
            capturedData = nil
        }
        let charUUID = characteristic.uuid.uuidString
        let serviceUUID = characteristic.service?.uuid.uuidString
        let isNotifying = characteristic.isNotifying
        let capturedError = error
        
        Task { @MainActor in
            guard self.manager != nil else { return }
            let logger = BLELogger.shared
            
            if let capturedError = capturedError {
                logger.error(.packet, "Read error on \(charUUID): \(capturedError.localizedDescription)")
                return
            }
            
            guard let data = capturedData, !data.isEmpty else { return }
            
            let charKey = charUUID
            let direction: PacketDirection = isNotifying ? .notification : .rx
            
            // --- V2 packet reassembly ---
            // Sphero droids may send responses as multiple BLE notifications.
            // With the dedicated BLE queue, each callback's captured data should
            // be unique (no lost bytes from main queue overwrite).
            // We still deduplicate as a safety measure.
            if let lastData = self.lastReceivedData[charKey], lastData == data {
                return // Duplicate — skip
            }
            self.lastReceivedData[charKey] = data
            
            // Check if this chunk starts a new v2 packet
            if data.first == 0x8D {
                if data.count >= 6, data.last == 0xD8 {
                    // Complete packet in a single notification
                    self.reassemblyBuffers.removeValue(forKey: charKey)
                    self.handleReassembledV2Packet(data, charKey: charKey, serviceUUID: serviceUUID, direction: direction)
                    return
                }
                // Partial — start buffering
                self.reassemblyBuffers[charKey] = Data(data)
                return
            }
            
            // Check if we have an active reassembly buffer
            if var buffer = self.reassemblyBuffers[charKey] {
                buffer.append(contentsOf: data)
                
                if buffer.last == 0xD8 && buffer.count >= 6 {
                    self.reassemblyBuffers.removeValue(forKey: charKey)
                    self.handleReassembledV2Packet(buffer, charKey: charKey, serviceUUID: serviceUUID, direction: direction)
                } else if buffer.count > self.maxBufferSize {
                    logger.warning(.packet, "Reassembly buffer overflow (\(buffer.count)B) — discarding")
                    self.reassemblyBuffers.removeValue(forKey: charKey)
                } else {
                    self.reassemblyBuffers[charKey] = buffer
                }
                return
            }
            
            // Data not part of a v2 frame — try v1 parse
            if data.first == 0xFF {
                self.handleV1Packet(data, charKey: charKey, serviceUUID: serviceUUID, direction: direction)
            }
        }
    }
    
    /// Parse and log a fully reassembled v2 packet.
    private func handleReassembledV2Packet(_ data: Data, charKey: String, serviceUUID: String?, direction: PacketDirection) {
        let logger = BLELogger.shared
        let parseResult = self.droidProtocol.parseResponse(data)
        let packet = BLEPacket(direction: direction, characteristicUUID: charKey, serviceUUID: serviceUUID, rawData: data)
        
        switch parseResult {
        case .success(let metadata):
            let enriched = BLEPacket(direction: direction, characteristicUUID: charKey, serviceUUID: serviceUUID, rawData: data, parsedMetadata: metadata)
            logger.logPacket(enriched, message: "Response: \(metadata.description ?? "parsed")")
            self.manager?.packetReceived.send((deviceID: self.deviceID, metadata: metadata))
        case .checksumError:
            logger.logPacket(packet, message: "CHECKSUM ERROR (\(data.count)B) [\(data.map { String(format: "%02X", $0) }.joined(separator: " "))]")
        case .incomplete:
            logger.logPacket(packet, message: "Incomplete v2 packet (\(data.count)B)")
        case .unknownFormat:
            logger.logPacket(packet, message: "Unknown v2 format (\(data.count)B)")
        }
    }
    
    /// Parse and log v1 packet(s).
    /// A single BLE notification may contain multiple concatenated V1 packets
    /// (e.g., a sync response followed by an async sensor notification).
    private func handleV1Packet(_ data: Data, charKey: String, serviceUUID: String?, direction: PacketDirection) {
        let logger = BLELogger.shared
        var remaining = data
        
        while remaining.count >= 6, remaining.first == 0xFF {
            // Calculate the length of the first V1 packet in the buffer
            let packetLength: Int
            let sop2 = remaining[remaining.startIndex + 1]
            
            if sop2 == 0xFE {
                // Async: FF FE ID_MSB ID_LSB DLEN_MSB DLEN_LSB [DATA] CHK
                guard remaining.count >= 7 else { break }
                let dlenMSB = Int(remaining[remaining.startIndex + 4])
                let dlenLSB = Int(remaining[remaining.startIndex + 5])
                let dlen = (dlenMSB << 8) | dlenLSB
                packetLength = 6 + dlen  // header(6) + data+checksum(dlen)
            } else if sop2 == 0xFF {
                // Sync: FF FF MRSP SEQ DLEN [DATA] CHK
                guard remaining.count >= 5 else { break }
                let dlen = Int(remaining[remaining.startIndex + 4])
                packetLength = 5 + dlen  // header(5) + data+checksum(dlen)
            } else {
                break  // Unknown SOP2
            }
            
            guard remaining.count >= packetLength else { break }
            
            let packetData = Data(remaining.prefix(packetLength))
            let parseResult = self.droidProtocol.parseResponse(packetData)
            
            switch parseResult {
            case .success(let metadata):
                let enriched = BLEPacket(direction: direction, characteristicUUID: charKey, serviceUUID: serviceUUID, rawData: packetData, parsedMetadata: metadata)
                logger.logPacket(enriched, message: "V1 Response: \(metadata.description ?? "parsed")")
                self.manager?.packetReceived.send((deviceID: self.deviceID, metadata: metadata))
            default:
                break
            }
            
            remaining = Data(remaining.dropFirst(packetLength))
        }
    }
    
    // MARK: - Write Confirmation
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            let logger = BLELogger.shared
            if let error = error {
                logger.error(.packet, "Write error on \(characteristic.uuid): \(error.localizedDescription)")
            } else {
                logger.trace(.packet, "Write confirmed on \(characteristic.uuid)")
            }
        }
    }
    
    // MARK: - Notification State Change
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Capture state on bleQueue before dispatching to MainActor
        let charUUID = characteristic.uuid.uuidString
        let isNotifying = characteristic.isNotifying
        let capturedError = error
        
        Task { @MainActor in
            guard let manager = self.manager else { return }
            let logger = BLELogger.shared
            
            if let capturedError = capturedError {
                logger.error(.service, "Notification subscription error on \(charUUID): \(capturedError.localizedDescription)")
            } else {
                let state = isNotifying ? "ON" : "OFF"
                logger.info(.service, "Notifications \(state) for \(charUUID)")
            }
            
            // Update notification state in the accumulated service info
            if var serviceInfos = manager.discoveredServiceInfo[self.deviceID] {
                for i in serviceInfos.indices {
                    for j in serviceInfos[i].chars.indices {
                        if serviceInfos[i].chars[j].uuid == charUUID {
                            serviceInfos[i].chars[j].isNotifying = isNotifying
                        }
                    }
                }
                manager.discoveredServiceInfo[self.deviceID] = serviceInfos
            }
        }
    }
}

// MARK: - BLE Errors

enum BLEError: LocalizedError {
    case peripheralNotFound
    case connectionFailed
    case bluetoothOff
    case characteristicNotFound
    case writeFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .peripheralNotFound:       return "Peripheral not found"
        case .connectionFailed:         return "Connection failed"
        case .bluetoothOff:             return "Bluetooth is powered off"
        case .characteristicNotFound:   return "Characteristic not found"
        case .writeFailure(let reason): return "Write failed: \(reason)"
        }
    }
}

// MARK: - CBManagerState Extension

extension CBManagerState {
    var displayName: String {
        switch self {
        case .unknown:      return "Unknown"
        case .resetting:    return "Resetting"
        case .unsupported:  return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff:   return "Powered Off"
        case .poweredOn:    return "Powered On"
        @unknown default:   return "Unknown (\(rawValue))"
        }
    }
}
