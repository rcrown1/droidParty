//
//  ScannerViewModel.swift
//  SWSphero
//
//  ViewModel for the scanner/discovery screen.
//

import Foundation
import CoreBluetooth
import Combine

@MainActor
final class ScannerViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var droids: [DroidDevice] = []
    @Published var isScanning: Bool = false
    @Published var bluetoothReady: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var filterSpheroOnly: Bool = true {
        didSet {
            bleManager.filterForSpheroDevices = filterSpheroOnly
        }
    }
    
    // MARK: - Dependencies
    
    let bleManager: BLEManager
    private var cancellables = Set<AnyCancellable>()
    private var pruneTask: Task<Void, Never>?
    private var autoStopTask: Task<Void, Never>?
    
    /// Duration in seconds before scanning automatically stops.
    let scanDuration: UInt64 = 2
    
    // MARK: - Init
    
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe BLE manager state changes
        bleManager.$discoveredDroids
            .map { dict in dict.values.sorted { $0.rssi > $1.rssi } }
            .receive(on: DispatchQueue.main)
            .assign(to: &$droids)
        
        bleManager.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)
        
        bleManager.$centralState
            .map { $0 == .poweredOn }
            .receive(on: DispatchQueue.main)
            .assign(to: &$bluetoothReady)
        
        bleManager.$lastEvent
            .receive(on: DispatchQueue.main)
            .assign(to: &$statusMessage)
    }
    
    // MARK: - Actions
    
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    func startScanning() {
        bleManager.startScanning()
        startPruneTimer()
        startAutoStopTimer()
    }
    
    func stopScanning() {
        bleManager.stopScanning()
        pruneTask?.cancel()
        pruneTask = nil
        autoStopTask?.cancel()
        autoStopTask = nil
    }
    
    /// Automatically stop scanning after `scanDuration` seconds.
    private func startAutoStopTimer() {
        autoStopTask?.cancel()
        autoStopTask = Task {
            try? await Task.sleep(nanoseconds: scanDuration * 1_000_000_000)
            guard !Task.isCancelled else { return }
            stopScanning()
        }
    }
    
    func connectToDroid(_ droid: DroidDevice) {
        Task {
            do {
                try await bleManager.connect(to: droid.id)
            } catch {
                BLELogger.shared.error(.connect, "Connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    func disconnectDroid(_ droid: DroidDevice) {
        bleManager.disconnect(from: droid.id)
    }
    
    /// Remove stale peripherals periodically while scanning.
    private func startPruneTimer() {
        pruneTask?.cancel()
        pruneTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                guard !Task.isCancelled else { break }
                bleManager.pruneStaleDevices()
            }
        }
    }
}
