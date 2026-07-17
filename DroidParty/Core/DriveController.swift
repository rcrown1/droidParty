//
//  DriveController.swift
//  SWSphero
//
//  Central drive controller managing rate-limited command dispatch,
//  safety stops, and lifecycle management.
//

import Foundation
import Combine
import CoreBluetooth
import UIKit

// MARK: - Drive Controller

@MainActor
final class DriveController: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var driveState = DriveState()
    @Published private(set) var headingState = HeadingState()
    @Published private(set) var isSimulationMode: Bool = false
    
    // MARK: - Dependencies
    
    private let bleManager: BLEManager
    private let logger: BLELogger
    private var driveProfile: DriveProfile
    private var encoder = PacketEncoder()
    
    /// The device ID of the connected droid.
    private var deviceID: UUID?
    
    // MARK: - Rate Limiting
    
    private var driveTimer: Task<Void, Never>?
    private var pendingDriveParams: DriveParameters?
    private var lastSendTime: Date = .distantPast
    
    /// Minimum interval between drive commands (computed from commandRate).
    private var commandInterval: TimeInterval {
        1.0 / driveState.commandRate
    }
    
    // MARK: - Safety
    
    private var backgroundObserver: NSObjectProtocol?
    
    // MARK: - Init
    
    init(bleManager: BLEManager, logger: BLELogger? = nil) {
        self.bleManager = bleManager
        self.logger = logger ?? BLELogger.shared
        self.driveProfile = MockDriveProfile()
        setupSafetyObservers()
    }
    
    deinit {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Configuration
    
    /// Attach to a specific droid for driving.
    func attach(to device: DroidDevice) {
        deviceID = device.id
        driveProfile = DriveProfileFactory.profile(for: device.droidType, discoveredServices: device.discoveredServices)
        isSimulationMode = false
        driveState.mode = .idle
        
        logger.info(.drive, "Attached drive controller: \(driveProfile.profileName) for \(device.displayName)")
    }
    
    /// Switch to simulation mode (no BLE writes).
    func enableSimulationMode() {
        driveProfile = DriveProfileFactory.mockProfile()
        isSimulationMode = true
        driveState.mode = .idle
        logger.info(.drive, "Simulation mode enabled")
    }
    
    /// Detach from the current droid and stop all drive activity.
    func detach() {
        emergencyStop()
        deviceID = nil
        driveState.mode = .disabled
        logger.info(.drive, "Drive controller detached")
    }
    
    /// Update max speed fraction (0…1).
    func setMaxSpeed(_ fraction: Double) {
        driveState.maxSpeedFraction = min(1.0, max(0.0, fraction))
        logger.debug(.drive, "Max speed set to \(Int(driveState.maxSpeedFraction * 100))%")
    }
    
    /// Update dead zone (0…1).
    func setDeadZone(_ value: Double) {
        driveState.deadZone = min(0.5, max(0.0, value))
        logger.debug(.drive, "Dead zone set to \(String(format: "%.2f", driveState.deadZone))")
    }
    
    /// Update command rate (Hz).
    func setCommandRate(_ hz: Double) {
        driveState.commandRate = min(30, max(1, hz))
        logger.debug(.drive, "Command rate set to \(Int(driveState.commandRate)) Hz")
    }
    
    // MARK: - Joystick Input
    
    /// Process a joystick vector update. Rate-limited — safe to call on every gesture event.
    func updateJoystick(_ vector: JoystickVector) {
        let params = DriveParameters.from(
            vector: vector,
            deadZone: driveState.deadZone,
            maxSpeedFraction: driveState.maxSpeedFraction,
            headingOffset: headingState.offset
        )
        
        driveState.rawJoystickAngle = vector.angleDegrees
        driveState.currentHeading = params.heading
        driveState.currentSpeed = params.speed
        
        if params.isStopped {
            // Immediate stop — don't rate-limit safety commands
            sendStopIfNeeded()
        } else {
            driveState.mode = .driving
            pendingDriveParams = params
            ensureDriveTimerRunning()
        }
    }
    
    /// Called when the joystick is released.
    func joystickReleased() {
        sendStopImmediate()
    }
    
    // MARK: - Emergency Stop
    
    /// Immediately stop the droid. Always succeeds, never rate-limited.
    func emergencyStop() {
        driveTimer?.cancel()
        driveTimer = nil
        pendingDriveParams = nil
        sendStopImmediate()
        logger.warning(.safety, "EMERGENCY STOP")
    }
    
    // MARK: - Heading Calibration
    
    /// Enter calibration mode: disable stabilization, turn on back LED.
    func enterCalibrationMode() {
        driveState.mode = .calibrating
        logger.info(.calibration, "Entering calibration mode")
        
        // Turn off stabilization so the user can rotate the droid freely
        if let cmd = driveProfile.encodeStabilizationCommand(enabled: false, encoder: &encoder) {
            sendCommand(cmd)
        }
        // Turn on back LED as aiming indicator
        if let cmd = driveProfile.encodeBackLEDCommand(brightness: 0xFF, encoder: &encoder) {
            sendCommand(cmd)
        }
    }
    
    /// Exit calibration mode: re-enable stabilization, turn off back LED.
    func exitCalibrationMode() {
        // Re-enable stabilization
        if let cmd = driveProfile.encodeStabilizationCommand(enabled: true, encoder: &encoder) {
            sendCommand(cmd)
        }
        // Turn off back LED
        if let cmd = driveProfile.encodeBackLEDCommand(brightness: 0x00, encoder: &encoder) {
            sendCommand(cmd)
        }
        
        driveState.mode = .idle
        logger.info(.calibration, "Exited calibration mode")
    }
    
    /// Perform hardware heading reset (set current direction as heading 0).
    func calibrateHeading() {
        logger.info(.calibration, "Calibrating heading (hardware reset)")
        
        if let cmd = driveProfile.encodeHeadingResetCommand(encoder: &encoder) {
            sendCommand(cmd)
            headingState.hardwareResetSent = true
            headingState.offset = 0
            logger.info(.calibration, "Hardware heading reset sent, software offset zeroed")
        } else {
            logger.warning(.calibration, "Drive profile does not support heading reset")
        }
    }
    
    /// Nudge heading offset left (counter-clockwise).
    func nudgeHeadingLeft() {
        headingState.offset -= headingState.nudgeIncrement
        logger.debug(.calibration, "Heading offset: \(headingState.displayOffset) deg (nudged left)")
    }
    
    /// Nudge heading offset right (clockwise).
    func nudgeHeadingRight() {
        headingState.offset += headingState.nudgeIncrement
        logger.debug(.calibration, "Heading offset: \(headingState.displayOffset) deg (nudged right)")
    }
    
    /// Zero the software heading offset.
    func zeroHeadingOffset() {
        headingState.offset = 0
        logger.info(.calibration, "Heading offset zeroed")
    }
    
    // MARK: - Command Dispatch (Private)
    
    /// Ensure the rate-limited drive timer is running.
    private func ensureDriveTimerRunning() {
        guard driveTimer == nil else { return }
        
        driveTimer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                
                if let params = self.pendingDriveParams {
                    self.sendDriveCommand(params)
                    self.pendingDriveParams = nil
                }
                
                try? await Task.sleep(nanoseconds: UInt64(self.commandInterval * 1_000_000_000))
            }
        }
    }
    
    /// Send a drive command via BLE (or log-only in simulation).
    private func sendDriveCommand(_ params: DriveParameters) {
        let cmd = driveProfile.encodeDriveCommand(
            heading: params.heading,
            speed: params.speed,
            encoder: &encoder
        )
        
        let packet = BLEPacket(
            direction: .tx,
            characteristicUUID: cmd.characteristicUUID.uuidString,
            rawData: cmd.data
        )
        logger.log(.trace, category: .drive, message: "Drive H=\(params.heading) S=\(params.speed)", packet: packet)
        
        sendCommand(cmd)
        
        driveState.commandsSent += 1
        driveState.lastCommandTime = Date()
        lastSendTime = Date()
    }
    
    /// Send a stop command if the droid is currently driving.
    private func sendStopIfNeeded() {
        guard driveState.mode == .driving else { return }
        sendStopImmediate()
    }
    
    /// Unconditionally send a stop command.
    private func sendStopImmediate() {
        driveTimer?.cancel()
        driveTimer = nil
        pendingDriveParams = nil
        
        let cmd = driveProfile.encodeStopCommand(
            heading: driveState.currentHeading,
            encoder: &encoder
        )
        
        let packet = BLEPacket(
            direction: .tx,
            characteristicUUID: cmd.characteristicUUID.uuidString,
            rawData: cmd.data
        )
        logger.log(.debug, category: .safety, message: "Stop command sent", packet: packet)
        
        sendCommand(cmd)
        
        driveState.currentSpeed = 0
        if driveState.mode == .driving || driveState.mode == .stopping {
            driveState.mode = .idle
        }
    }
    
    /// Write a command to BLE or log-only in simulation mode.
    private func sendCommand(_ cmd: (characteristicUUID: CBUUID, data: Data)) {
        if isSimulationMode {
            logger.trace(.drive, "SIM: Would write \(cmd.data.map { String(format: "%02X", $0) }.joined(separator: " ")) to \(cmd.characteristicUUID)")
            return
        }
        
        guard let deviceID = deviceID else {
            logger.warning(.drive, "No device attached — command dropped")
            return
        }
        
        bleManager.writeRawData(
            cmd.data,
            to: cmd.characteristicUUID,
            deviceID: deviceID,
            withResponse: false // Drive commands use write-without-response for speed
        )
    }
    
    // MARK: - Safety Observers
    
    private func setupSafetyObservers() {
        // Stop driving when app goes to background
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                if controller.driveState.mode == .driving {
                    controller.logger.warning(.safety, "App backgrounding — auto-stop triggered")
                    controller.emergencyStop()
                }
            }
        }
    }
    
    /// Called by views on disappear to ensure safety stop.
    func onViewDisappear() {
        if driveState.mode == .driving {
            logger.warning(.safety, "Drive view disappeared — auto-stop triggered")
            emergencyStop()
        }
    }
    
    /// Called when BLE disconnects.
    func onDisconnect() {
        if driveState.mode == .driving || driveState.mode == .calibrating {
            logger.warning(.safety, "BLE disconnect — auto-stop triggered")
            emergencyStop()
        }
        driveState.mode = .disabled
    }
}
