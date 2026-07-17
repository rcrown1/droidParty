//
//  CapabilityController.swift
//  SWSphero
//
//  Command dispatch controller for capability lab actions: animations,
//  sounds, LEDs, head position, and leg actions.
//
//  Follows the same pattern as DriveController: encodes commands through
//  a CapabilityProfile and writes via BLEManager.
//

import Foundation
import Combine
import CoreBluetooth
import UIKit

// MARK: - Capability Controller

@MainActor
final class CapabilityController: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var volume: UInt8 = 200
    @Published private(set) var idleAnimationsEnabled: Bool = true
    @Published private(set) var lastCommandDescription: String = ""
    
    // MARK: - Dependencies
    
    private let bleManager: BLEManager
    private let logger: BLELogger
    private var capabilityProfile: CapabilityProfile
    private var driveProfile: DriveProfile
    private var encoder = PacketEncoder()
    
    /// The device ID of the connected droid.
    private(set) var deviceID: UUID?
    
    // MARK: - Safety
    
    private var backgroundObserver: NSObjectProtocol?
    
    // MARK: - Init
    
    init(bleManager: BLEManager, logger: BLELogger? = nil) {
        self.bleManager = bleManager
        self.logger = logger ?? BLELogger.shared
        self.capabilityProfile = BB8LegacyCapabilityProfile()
        self.driveProfile = MockDriveProfile()
        setupSafetyObservers()
    }
    
    deinit {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Configuration
    
    /// Attach to a specific droid for capability testing.
    func attach(to device: DroidDevice) {
        deviceID = device.id
        capabilityProfile = CapabilityProfileFactory.profile(
            for: device.droidType,
            discoveredServices: device.discoveredServices
        )
        driveProfile = DriveProfileFactory.profile(
            for: device.droidType,
            discoveredServices: device.discoveredServices
        )
        logger.info(.capability, "Attached capability controller: \(capabilityProfile.profileName) for \(device.displayName)")
    }
    
    /// Detach from the current droid.
    func detach() {
        stopAll()
        deviceID = nil
        logger.info(.capability, "Capability controller detached")
    }
    
    var currentProfile: CapabilityProfile {
        capabilityProfile
    }
    
    // MARK: - Animation Commands
    
    func playAnimation(id: UInt8) {
        guard let cmd = capabilityProfile.encodePlayAnimation(id: id, encoder: &encoder) else {
            logger.warning(.capability, "Play animation unsupported by \(capabilityProfile.profileName)")
            return
        }
        sendCommand(cmd)
        lastCommandDescription = "Animation #\(id)"
        logger.info(.capability, "Play animation ID=\(id)")
    }
    
    func stopAnimation() {
        guard let cmd = capabilityProfile.encodeStopAnimation(encoder: &encoder) else { return }
        sendCommand(cmd)
        lastCommandDescription = "Stop animation"
        logger.info(.capability, "Stop animation")
    }
    
    func setIdleAnimations(enabled: Bool) {
        guard let cmd = capabilityProfile.encodeEnableIdleAnimations(enabled: enabled, encoder: &encoder) else {
            logger.warning(.capability, "Idle animations unsupported")
            return
        }
        sendCommand(cmd)
        idleAnimationsEnabled = enabled
        lastCommandDescription = "Idle animations \(enabled ? "ON" : "OFF")"
        logger.info(.capability, "Idle animations \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Sound Commands
    
    func playSound(id: UInt16, mode: UInt8 = 0x00) {
        guard let cmd = capabilityProfile.encodePlaySound(id: id, mode: mode, encoder: &encoder) else {
            logger.warning(.capability, "Play sound unsupported by \(capabilityProfile.profileName)")
            return
        }
        sendCommand(cmd)
        lastCommandDescription = "Sound #\(id)"
        logger.info(.capability, "Play sound ID=\(id) mode=\(mode)")
    }
    
    func stopSound() {
        guard let cmd = capabilityProfile.encodeStopSound(encoder: &encoder) else { return }
        sendCommand(cmd)
        lastCommandDescription = "Stop sound"
        logger.info(.capability, "Stop sound")
    }
    
    func setVolume(_ vol: UInt8) {
        guard let cmd = capabilityProfile.encodeSetVolume(volume: vol, encoder: &encoder) else {
            logger.warning(.capability, "Set volume unsupported")
            return
        }
        sendCommand(cmd)
        volume = vol
        lastCommandDescription = "Volume \(Int(vol) * 100 / 255)%"
        logger.info(.capability, "Set volume to \(vol) (\(Int(vol) * 100 / 255)%)")
    }
    
    // MARK: - LED Commands
    
    func setLEDs(mask: UInt8, values: [UInt8]) {
        guard let cmd = capabilityProfile.encodeSetLEDs(mask: mask, values: values, encoder: &encoder) else {
            logger.warning(.capability, "Set LEDs unsupported")
            return
        }
        sendCommand(cmd)
        lastCommandDescription = "LEDs mask=0x\(String(format: "%02X", mask))"
        logger.info(.capability, "Set LEDs mask=0x\(String(format: "%02X", mask)) values=\(values.map { String(format: "%02X", $0) }.joined(separator: ","))")
    }
    
    /// Convenience: set an RGB LED target to a color.
    func setRGBLED(target: LEDTarget, color: LEDColor) {
        let (mask, values) = ledMaskAndValues(for: target, color: color)
        setLEDs(mask: mask, values: values)
    }
    
    /// Turn off all LEDs by sending an all-zeros command.
    func allLEDsOff(for droidType: DroidType) {
        let targets = CapabilityRegistry.ledTargets(for: droidType)
        var mask: UInt8 = 0
        var values: [UInt8] = []
        for target in targets {
            let (m, v) = ledMaskAndValues(for: target, color: .off)
            mask |= m
            values.append(contentsOf: v)
        }
        setLEDs(mask: mask, values: values)
    }
    
    // MARK: - Head Position (R-series)
    
    func setHeadPosition(angle: Float) {
        let clampedAngle = min(180.0, max(-160.0, angle))
        guard let cmd = capabilityProfile.encodeSetHeadPosition(angle: clampedAngle, encoder: &encoder) else {
            logger.warning(.capability, "Head position unsupported")
            return
        }
        sendCommand(cmd)
        lastCommandDescription = "Head \(String(format: "%.0f", clampedAngle))°"
        logger.info(.capability, "Set head position to \(clampedAngle)°")
    }
    
    // MARK: - Leg Actions (R-series)
    
    func performLegAction(_ action: R2LegAction) {
        guard let cmd = capabilityProfile.encodePerformLegAction(action, encoder: &encoder) else {
            logger.warning(.capability, "Leg action unsupported")
            return
        }
        sendCommand(cmd)
        lastCommandDescription = "Leg: \(action.displayName)"
        logger.info(.capability, "Perform leg action: \(action.displayName)")
    }
    
    // MARK: - Roll/Drive Commands
    
    /// Roll in a direction at a given speed. Used by sequences for motion.
    func roll(heading: UInt16, speed: UInt8) {
        let cmd = driveProfile.encodeDriveCommand(heading: heading, speed: speed, encoder: &encoder)
        sendCommand(cmd)
        lastCommandDescription = "Roll heading=\(heading)° speed=\(speed)"
        logger.info(.capability, "Roll heading=\(heading)° speed=\(speed)")
    }
    
    /// Stop rolling, maintaining the given heading.
    func stopRoll(heading: UInt16 = 0) {
        let cmd = driveProfile.encodeStopCommand(heading: heading, encoder: &encoder)
        sendCommand(cmd)
        lastCommandDescription = "Stop roll"
        logger.info(.capability, "Stop roll heading=\(heading)°")
    }
    
    // MARK: - Stop All
    
    /// Stop all active capabilities: animation, sound, LEDs off, stop rolling.
    func stopAll() {
        stopAnimation()
        stopSound()
        stopRoll()
        lastCommandDescription = "Stop all"
        logger.info(.capability, "Stop all capabilities")
    }
    
    // MARK: - LED Mask Helpers
    
    /// Convert a LEDTarget + LEDColor into the bitmask + values required by setAllLEDs8BitMask.
    private func ledMaskAndValues(for target: LEDTarget, color: LEDColor) -> (mask: UInt8, values: [UInt8]) {
        switch target {
        // R2-D2/R2-Q5 front RGB: indices 0,1,2
        case .frontRGB:
            return (0b0000_0111, [color.r, color.g, color.b])
        // R2-D2/R2-Q5 back RGB: indices 4,5,6
        case .backRGB:
            return (0b0111_0000, [color.r, color.g, color.b])
        // R2-D2/R2-Q5 logic displays: index 3
        case .logicDisplays:
            return (0b0000_1000, [color.r])
        // R2-D2/R2-Q5 holo projector: index 7
        case .holoProjector:
            return (0b1000_0000, [color.r])
        // BB-9E body RGB: indices 0,1,2
        case .bodyRGB:
            return (0b0000_0111, [color.r, color.g, color.b])
        // BB-9E aiming LED: index 3
        case .aimingLED:
            return (0b0000_1000, [color.r])
        // BB-9E head LED: index 4
        case .headLED:
            return (0b0001_0000, [color.r])
        // BB-8 back LED (v1 protocol — mask ignored, value[0] = brightness)
        case .backLED:
            return (0x00, [color.r])
        }
    }
    
    // MARK: - Command Dispatch (Private)
    
    private func sendCommand(_ cmd: (characteristicUUID: CBUUID, data: Data)) {
        guard let deviceID = deviceID else {
            logger.warning(.capability, "No device attached — command dropped")
            return
        }
        
        bleManager.writeRawData(
            cmd.data,
            to: cmd.characteristicUUID,
            deviceID: deviceID,
            withResponse: false
        )
    }
    
    // MARK: - Safety Observers
    
    private func setupSafetyObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.logger.warning(.safety, "App backgrounding — stopping capability commands")
                controller.stopAll()
            }
        }
    }
    
    /// Called when BLE disconnects.
    func onDisconnect() {
        stopAll()
    }
}
