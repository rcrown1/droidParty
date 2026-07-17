//
//  SensorController.swift
//  SWSphero
//
//  Manages sensor streaming (IMU data) and battery level queries.
//
//  BB-8 uses V1 setDataStreaming (DID=0x02, CID=0x11) for IMU streaming.
//  Battery voltage uses V2 getBatteryVoltage (DID=0x13, CID=0x03) for all droids.
//
//  Subscribes to BLEManager.packetReceived to receive async notifications
//  containing sensor payloads and battery responses.
//

import Foundation
import Combine
import CoreBluetooth

@MainActor
final class SensorController: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var sensorData = SensorData()
    @Published private(set) var batteryState = BatteryState()
    @Published private(set) var isStreaming = false
    
    // MARK: - Dependencies
    
    private let bleManager: BLEManager
    private let logger: BLELogger
    private var encoder = PacketEncoder()
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var deviceID: UUID?
    private var droidType: DroidType = .unknownSphero
    private var batteryTimer: Task<Void, Never>?
    private var pendingV1BatteryQuery = false
    
    // MARK: - Init
    
    init(bleManager: BLEManager, logger: BLELogger? = nil) {
        self.bleManager = bleManager
        self.logger = logger ?? BLELogger.shared
    }
    
    // MARK: - Attach / Detach
    
    func attach(to device: DroidDevice) {
        deviceID = device.id
        droidType = device.droidType
        subscribeToPackets()
        queryBattery()
        startBatteryPolling()
        logger.info(.sensor, "Sensor controller attached for \(device.displayName)")
    }
    
    func detach() {
        stopStreaming()
        batteryTimer?.cancel()
        batteryTimer = nil
        cancellables.removeAll()
        pendingV1BatteryQuery = false
        deviceID = nil
        logger.info(.sensor, "Sensor controller detached")
    }
    
    func onDisconnect() {
        isStreaming = false
        batteryTimer?.cancel()
        batteryTimer = nil
        cancellables.removeAll()
        pendingV1BatteryQuery = false
    }
    
    // MARK: - Sensor Streaming (BB-8 V1)
    
    /// Start IMU streaming at 10 Hz. BB-8 only (V1 protocol).
    func startStreaming() {
        guard !isStreaming else { return }
        guard droidType == .bb8 else {
            logger.info(.sensor, "Sensor streaming not yet supported for \(droidType)")
            return
        }
        
        let packet = encoder.encodeV1SetDataStreaming(
            divisor: 40,        // 400 Hz / 40 = 10 Hz
            frameCount: 1,
            mask: V1SensorMask.imuAll,
            packetCount: 0      // Stream forever
        )
        
        sendV1Command(packet)
        isStreaming = true
        logger.info(.sensor, "Started IMU streaming at 10 Hz")
    }
    
    /// Stop sensor streaming by sending mask=0.
    func stopStreaming() {
        guard isStreaming else { return }
        
        let packet = encoder.encodeV1SetDataStreaming(
            divisor: 40,
            frameCount: 1,
            mask: 0,            // No sensors = stop streaming
            packetCount: 0
        )
        
        sendV1Command(packet)
        isStreaming = false
        logger.info(.sensor, "Stopped sensor streaming")
    }
    
    // MARK: - Battery Query
    
    /// Query battery voltage. Uses V1 getPowerState for BB-8, V2 for other droids.
    func queryBattery() {
        guard let deviceID else { return }
        
        if droidType == .bb8 {
            // V1: getPowerState (DID=0x00, CID=0x20) — no payload
            let packet = encoder.encodeV1(
                deviceID: SpheroV1DeviceID.core,
                commandID: SpheroV1CoreCommand.getPowerState
            )
            pendingV1BatteryQuery = true
            sendV1Command(packet)
            logger.trace(.sensor, "Queried battery (V1 getPowerState)")
        } else {
            // V2: getBatteryVoltage (DID=0x13, CID=0x03)
            let packet = encoder.encodeV2(
                deviceID: SpheroV2DeviceID.powerInfo,
                commandID: SpheroV2PowerCommand.getBatteryVoltage
            )
            bleManager.writeRawData(
                packet,
                to: SpheroUUID.v2APICommand,
                deviceID: deviceID,
                withResponse: false
            )
            logger.trace(.sensor, "Queried battery (V2 getBatteryVoltage)")
        }
    }
    
    /// Poll battery every 60 seconds while connected.
    private func startBatteryPolling() {
        batteryTimer?.cancel()
        batteryTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                self?.queryBattery()
            }
        }
    }
    
    // MARK: - Packet Subscription
    
    private func subscribeToPackets() {
        cancellables.removeAll()
        
        bleManager.packetReceived
            .filter { [weak self] in $0.deviceID == self?.deviceID }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_, metadata) in
                self?.handlePacket(metadata)
            }
            .store(in: &cancellables)
    }
    
    private func handlePacket(_ metadata: PacketMetadata) {
        // V1 async sensor data
        if metadata.asyncID == V1AsyncID.sensorData,
           let payload = metadata.payload, !payload.isEmpty {
            parseSensorPayload(payload)
            return
        }
        
        // V1 battery response (getPowerState returns 8-byte payload)
        if pendingV1BatteryQuery,
           metadata.protocolVersion == .v1,
           metadata.asyncID == nil,
           metadata.errorCode == 0x00,
           let payload = metadata.payload, payload.count == 8 {
            pendingV1BatteryQuery = false
            parseV1PowerStatePayload(payload)
            return
        }
        
        // V2 battery voltage response (DID=0x13, CID=0x03)
        if metadata.deviceID == SpheroV2DeviceID.powerInfo,
           metadata.commandID == SpheroV2PowerCommand.getBatteryVoltage {
            if let payload = metadata.payload, !payload.isEmpty {
                parseBatteryPayload(payload)
            } else {
                logger.warning(.sensor, "Battery response had empty/nil payload")
            }
            return
        }
    }
    
    // MARK: - Sensor Payload Parsing
    
    /// Parse IMU data from V1 async sensor notification.
    /// With imuAll mask, payload is 3 × Int16 big-endian = 6 bytes.
    private func parseSensorPayload(_ payload: Data) {
        guard payload.count >= 6 else {
            logger.warning(.sensor, "Sensor payload too short: \(payload.count) bytes")
            return
        }
        
        let pitch = Double(readInt16BE(payload, offset: 0))
        let roll = Double(readInt16BE(payload, offset: 2))
        var yaw = Double(readInt16BE(payload, offset: 4))
        
        // Wrap yaw to 0-360
        if yaw < 0 { yaw += 360.0 }
        
        sensorData = SensorData(
            pitch: pitch,
            roll: roll,
            yaw: yaw,
            timestamp: Date()
        )
    }
    
    /// Parse V1 getPowerState response.
    /// Payload: [RecVer, PowerState, Voltage_MSB, Voltage_LSB, NumCharges_MSB, NumCharges_LSB, TimeSinceChg_MSB, TimeSinceChg_LSB]
    /// Voltage is in 1/100ths of a volt (centivolts).
    private func parseV1PowerStatePayload(_ payload: Data) {
        let centivolts = readUInt16BE(payload, offset: 2)
        let millivolts = UInt16(centivolts) * 10
        
        batteryState = BatteryState(voltageMillivolts: millivolts)
        let powerState = payload[payload.startIndex + 1]
        let stateDesc = powerState == 1 ? "Charging" : powerState == 2 ? "OK" : powerState == 3 ? "Low" : "Unknown(\(powerState))"
        logger.info(.sensor, "Battery (V1): \(millivolts)mV (\(batteryState.percentage)%) state=\(stateDesc)")
    }
    
    /// Parse battery voltage from V2 response.
    /// Known payload formats:
    /// - 1 byte state + 2 bytes voltage (BB-9E, R2 units): [state, v_hi, v_lo]
    /// - 2 bytes voltage only: [v_hi, v_lo]
    /// Voltage may be in millivolts (3500–4200 range) or centivolts (350–420 range).
    private func parseBatteryPayload(_ payload: Data) {
        let payloadHex = payload.map { String(format: "%02X", $0) }.joined(separator: " ")
        logger.info(.sensor, "Battery (V2) raw payload(\(payload.count)): [\(payloadHex)]")
        
        let rawVoltage: UInt16
        if payload.count >= 3 {
            // [state, voltage_hi, voltage_lo]
            rawVoltage = readUInt16BE(payload, offset: 1)
        } else {
            rawVoltage = readUInt16BE(payload, offset: 0)
        }
        
        // Auto-detect scale: if value is < 1000, it's likely centivolts (×10 to get mV)
        let millivolts: UInt16
        if rawVoltage > 0 && rawVoltage < 1000 {
            millivolts = rawVoltage * 10
        } else {
            millivolts = rawVoltage
        }
        
        batteryState = BatteryState(voltageMillivolts: millivolts)
        logger.info(.sensor, "Battery (V2): \(millivolts)mV (\(batteryState.percentage)%)")
    }
    
    // MARK: - Byte Helpers
    
    private func readInt16BE(_ data: Data, offset: Int) -> Int16 {
        let hi = Int16(data[data.startIndex + offset]) << 8
        let lo = Int16(data[data.startIndex + offset + 1])
        return hi | lo
    }
    
    private func readUInt16BE(_ data: Data, offset: Int) -> UInt16 {
        let hi = UInt16(data[data.startIndex + offset]) << 8
        let lo = UInt16(data[data.startIndex + offset + 1])
        return hi | lo
    }
    
    // MARK: - Command Dispatch
    
    /// Send a V1-encoded packet via the legacy command characteristic.
    private func sendV1Command(_ data: Data) {
        guard let deviceID else {
            logger.warning(.sensor, "No device attached — command dropped")
            return
        }
        
        bleManager.writeRawData(
            data,
            to: SpheroUUID.legacyCommand,
            deviceID: deviceID,
            withResponse: false
        )
    }
}
