//
//  FleetViewModel.swift
//  DroidParty
//
//  Manages the four DroidPresences that make up a droid party.
//  Each presence owns its own DriveController / CapabilityController /
//  SensorController / SequenceRunner scoped to a single droid.
//
//  On launch, FleetViewModel scans for known peripheral UUIDs (persisted
//  in UserDefaults, keyed by DroidType) and connects to each in parallel.
//  Unknown droids that show up during a discovery-mode scan can be
//  claimed as a slot from FleetSettingsView.
//

import Foundation
import Combine
import CoreBluetooth

// MARK: - DroidPresence

/// One slot in the fleet — a single droid type and all the controllers
/// wired up for it. `device` is nil until BLEManager first sees the
/// peripheral; `attach(device:)` is called when it reaches `.ready`.
@MainActor
final class DroidPresence: ObservableObject, Identifiable {
    let droidType: DroidType
    nonisolated var id: DroidType { droidType }

    @Published var device: DroidDevice?
    @Published var isReady: Bool = false

    let drive: DriveController
    let capability: CapabilityController
    let sensors: SensorController
    let sequences: SequenceRunner

    private let bleManager: BLEManager

    init(droidType: DroidType, bleManager: BLEManager) {
        self.droidType = droidType
        self.bleManager = bleManager
        let drive = DriveController(bleManager: bleManager)
        let cap = CapabilityController(bleManager: bleManager)
        let sensors = SensorController(bleManager: bleManager)
        self.drive = drive
        self.capability = cap
        self.sensors = sensors
        self.sequences = SequenceRunner(controller: cap)
    }

    /// Wire up the controllers to a newly-ready device.
    func attach(device: DroidDevice) {
        self.device = device
        self.isReady = device.connectionState == .ready
        drive.attach(to: device)
        capability.attach(to: device)
        sensors.attach(to: device)
    }

    /// Called when this presence's peripheral disconnects.
    func onDisconnected() {
        drive.onDisconnect()
        capability.onDisconnect()
        sensors.onDisconnect()
        isReady = false
        sequences.cancel()
    }

    /// User-triggered detach (Forget droid).
    func detach() {
        drive.detach()
        capability.detach()
        sensors.detach()
        device = nil
        isReady = false
        sequences.cancel()
    }

    var displayName: String {
        device?.displayName ?? droidType.displayName
    }

    var connectionState: ConnectionState {
        device?.connectionState ?? .disconnected
    }

    var isConnected: Bool {
        device?.connectionState.isConnected == true
    }
}

// MARK: - FleetViewModel

@MainActor
final class FleetViewModel: ObservableObject {

    // MARK: Constants

    /// Fixed slot order for the tab bar.
    static let slotOrder: [DroidType] = [.bb8, .bb9e, .r2d2, .r2q5]

    private let knownDroidsKey = "knownDroids_v1"

    // MARK: State

    let bleManager: BLEManager
    let presences: [DroidType: DroidPresence]

    @Published private(set) var knownDroids: [DroidType: UUID] = [:]
    @Published var isScanning: Bool = false
    @Published var isDiscoveryMode: Bool = false
    @Published var statusMessage: String = ""

    private var cancellables = Set<AnyCancellable>()
    private var scanStopTask: Task<Void, Never>?
    private var attemptedConnects: Set<UUID> = []

    // MARK: Init

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        var built: [DroidType: DroidPresence] = [:]
        for type in FleetViewModel.slotOrder {
            built[type] = DroidPresence(droidType: type, bleManager: bleManager)
        }
        self.presences = built
        self.knownDroids = FleetViewModel.loadKnownDroids(key: knownDroidsKey)
        setupBindings()
    }

    // MARK: Bindings

    private func setupBindings() {
        bleManager.$discoveredDroids
            .receive(on: DispatchQueue.main)
            .sink { [weak self] droids in
                self?.handleDiscoveredDroids(droids)
            }
            .store(in: &cancellables)
    }

    /// The primary reactive loop. Every time BLEManager's discovered-droids
    /// map changes we:
    ///   1. Route known UUIDs to their presence (updating device + wiring
    ///      controllers when the state first reaches `.ready`).
    ///   2. In discovery mode, opportunistically claim an unknown droid
    ///      whose type has no slot yet.
    ///   3. If we've been scanning and every known droid is ready, stop.
    private func handleDiscoveredDroids(_ droids: [UUID: DroidDevice]) {
        // 1. Update known slots.
        for (type, uuid) in knownDroids {
            guard let presence = presences[type] else { continue }
            if let device = droids[uuid] {
                let wasReady = presence.isReady
                let nowReady = device.connectionState == .ready
                presence.device = device
                presence.isReady = nowReady

                if !wasReady && nowReady {
                    presence.attach(device: device)
                } else if wasReady && !nowReady {
                    presence.onDisconnected()
                    // Auto-reconnect on unexpected drop while scanning.
                    if isScanning {
                        connectIfNeeded(uuid: uuid)
                    }
                }

                if isScanning && device.connectionState == .disconnected {
                    connectIfNeeded(uuid: uuid)
                }
            } else {
                // Peripheral hasn't been seen yet.
                if presence.isReady {
                    presence.onDisconnected()
                }
                presence.device = nil
            }
        }

        // 2. Discovery-mode: claim an unknown droid for an empty slot.
        if isDiscoveryMode {
            for device in droids.values where device.droidType != .unknownSphero {
                let type = device.droidType
                if knownDroids[type] == nil, presences[type] != nil {
                    rememberDroid(type: type, uuid: device.id)
                    connectIfNeeded(uuid: device.id)
                }
            }
        }

        // 3. Stop scanning once every remembered slot is ready.
        if isScanning, !knownDroids.isEmpty {
            let allReady = knownDroids.allSatisfy { _, uuid in
                droids[uuid]?.connectionState == .ready
            }
            if allReady {
                statusMessage = "All droids connected."
                stopScan()
            }
        }
    }

    // MARK: Auto-connect

    /// Called once at app launch. Waits for Bluetooth to power on, then
    /// starts scanning. As known droids appear in the discovered-droids
    /// map, `handleDiscoveredDroids` fires connects for each in parallel.
    /// Scan auto-stops after 20s or when every known slot is ready.
    func autoConnectAll() async {
        await waitForBluetoothReady(timeout: 3)
        guard bleManager.centralState == .poweredOn else {
            statusMessage = "Bluetooth is off."
            return
        }
        if knownDroids.isEmpty {
            statusMessage = "No droids paired. Open Settings → Scan for droids."
            return
        }
        attemptedConnects.removeAll()
        startScan(discovery: false)
    }

    /// User-triggered rescan / reconnect-all.
    func reconnectAll() {
        attemptedConnects.removeAll()
        for (_, presence) in presences where !presence.isConnected {
            presence.device = nil
        }
        startScan(discovery: false)
    }

    /// User-triggered pair-more-droids flow.
    func startDiscoveryScan() {
        isDiscoveryMode = true
        attemptedConnects.removeAll()
        startScan(discovery: true)
    }

    func endDiscoveryScan() {
        isDiscoveryMode = false
        stopScan()
    }

    /// Disconnect and remove a droid from the fleet.
    func forgetDroid(_ type: DroidType) {
        if let uuid = knownDroids[type] {
            bleManager.disconnect(from: uuid)
        }
        presences[type]?.detach()
        knownDroids.removeValue(forKey: type)
        saveKnownDroids()
    }

    /// User-triggered disconnect on one presence.
    func disconnect(_ type: DroidType) {
        guard let uuid = knownDroids[type] else { return }
        bleManager.disconnect(from: uuid)
    }

    // MARK: Broadcast

    /// Fan an action out to every currently-ready presence, optionally
    /// filtered by droid family.
    func broadcast(family: DroidFamily? = nil, _ action: (DroidPresence) -> Void) {
        for type in FleetViewModel.slotOrder {
            guard let presence = presences[type], presence.isConnected else { continue }
            if let family {
                guard presence.droidType.family == family else { continue }
            }
            action(presence)
        }
    }

    // MARK: Persistence

    private static func loadKnownDroids(key: String) -> [DroidType: UUID] {
        guard let raw = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else {
            return [:]
        }
        var out: [DroidType: UUID] = [:]
        for (typeString, uuidString) in raw {
            if let type = DroidType(rawValue: typeString), let uuid = UUID(uuidString: uuidString) {
                out[type] = uuid
            }
        }
        return out
    }

    private func rememberDroid(type: DroidType, uuid: UUID) {
        knownDroids[type] = uuid
        saveKnownDroids()
    }

    private func saveKnownDroids() {
        var raw: [String: String] = [:]
        for (type, uuid) in knownDroids {
            raw[type.rawValue] = uuid.uuidString
        }
        UserDefaults.standard.set(raw, forKey: knownDroidsKey)
    }

    // MARK: Scan helpers

    private func startScan(discovery: Bool) {
        guard bleManager.centralState == .poweredOn else {
            statusMessage = "Bluetooth is not ready."
            return
        }
        bleManager.startScanning()
        isScanning = true
        statusMessage = discovery ? "Scanning for new droids…" : "Reconnecting…"

        scanStopTask?.cancel()
        scanStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(discovery ? 30 : 20))
            guard let self else { return }
            if self.isScanning {
                self.stopScan()
                if !discovery {
                    let missing = self.knownDroids.filter { _, uuid in
                        self.bleManager.discoveredDroids[uuid]?.connectionState != .ready
                    }
                    self.statusMessage = missing.isEmpty
                        ? "All droids connected."
                        : "Timed out waiting for \(missing.count) droid(s)."
                }
            }
        }
    }

    private func stopScan() {
        scanStopTask?.cancel()
        scanStopTask = nil
        if bleManager.isScanning {
            bleManager.stopScanning()
        }
        isScanning = false
    }

    private func connectIfNeeded(uuid: UUID) {
        guard !attemptedConnects.contains(uuid) else { return }
        attemptedConnects.insert(uuid)
        Task { [weak self] in
            do {
                try await self?.bleManager.connect(to: uuid)
            } catch {
                await MainActor.run {
                    self?.statusMessage = "Connect failed: \(error.localizedDescription)"
                    self?.attemptedConnects.remove(uuid)
                }
            }
        }
    }

    private func waitForBluetoothReady(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while bleManager.centralState != .poweredOn && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
