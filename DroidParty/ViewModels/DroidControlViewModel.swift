//
//  DroidControlViewModel.swift
//  DroidParty
//
//  Per-droid Operate-screen view model. Wraps a DroidPresence — the
//  presence already owns the four controllers; this VM just projects
//  their state into published values that the SwiftUI view can bind to
//  and forwards user actions.
//
//  Difference from SWSphero's DriveViewModel:
//   * Bound to a specific presence at init — no "first ready" auto-attach.
//   * No auto-calibration timer (droids are on a shelf, plugged in).
//   * No simulation mode (the whole point is real hardware).
//

import Foundation
import Combine

@MainActor
final class DroidControlViewModel: ObservableObject {

    // MARK: Published state

    @Published var driveState = DriveState()
    @Published var headingState = HeadingState()
    @Published var joystickVector = JoystickVector.zero
    @Published var isConnected: Bool = false
    @Published var droidDisplayName: String = ""

    @Published var maxSpeedPercent: Double = 60 {
        didSet { presence.drive.setMaxSpeed(maxSpeedPercent / 100.0) }
    }
    @Published var deadZone: Double = 0.12 {
        didSet { presence.drive.setDeadZone(deadZone) }
    }
    @Published var isCalibrating: Bool = false

    // Sound
    @Published var soundCategories: [String] = []
    @Published var lastPlayedCategory: String? = nil

    // Animations
    @Published var animationCategories: [String] = []
    @Published var lastPlayedAnimationCategory: String? = nil
    @Published var hasAnimationControl: Bool = false

    // Head
    @Published var headAngle: Double = 0
    @Published var hasHeadControl: Bool = false
    @Published var hasSoundControl: Bool = false
    @Published var hasLegControl: Bool = false
    @Published var currentLegAction: R2LegAction = .stop

    // LEDs
    @Published var hasLEDControl: Bool = false
    @Published var ledTargets: [LEDTarget] = []
    @Published var ledColors: [LEDTarget: LEDColor] = [:]
    @Published var activeEffect: [LEDTarget: LEDEffect] = [:]

    // Sensor & battery
    @Published var sensorData = SensorData()
    @Published var batteryState = BatteryState()
    @Published var isStreamingSensors: Bool = false

    // MARK: Dependencies

    let presence: DroidPresence
    var droidType: DroidType { presence.droidType }
    var sequenceRunner: SequenceRunner { presence.sequences }

    private let bleManager: BLEManager
    private var cancellables = Set<AnyCancellable>()

    // Motor sound tracking
    private var isMotorSoundPlaying = false

    // LED effect tasks
    private var effectTasks: [LEDTarget: Task<Void, Never>] = [:]

    // MARK: Init

    init(presence: DroidPresence, bleManager: BLEManager) {
        self.presence = presence
        self.bleManager = bleManager
        self.droidDisplayName = presence.displayName
        setupBindings()
        // If the presence is already connected when the view first appears,
        // pull its capabilities into published state.
        if presence.isConnected, let device = presence.device {
            self.reflectAttached(device: device)
        }
    }

    private func setupBindings() {
        presence.drive.$driveState
            .receive(on: DispatchQueue.main)
            .assign(to: &$driveState)

        presence.drive.$headingState
            .receive(on: DispatchQueue.main)
            .assign(to: &$headingState)

        presence.sensors.$sensorData
            .receive(on: DispatchQueue.main)
            .assign(to: &$sensorData)

        presence.sensors.$batteryState
            .receive(on: DispatchQueue.main)
            .assign(to: &$batteryState)

        // React to the presence's device changing state — the fleet
        // model owns attaching; we just mirror the resulting capabilities.
        presence.$device
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device in
                guard let self else { return }
                if let device, device.connectionState == .ready {
                    self.reflectAttached(device: device)
                } else if device == nil || device?.connectionState != .ready {
                    self.reflectDetached()
                }
            }
            .store(in: &cancellables)

        presence.$isReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
    }

    private func reflectAttached(device: DroidDevice) {
        droidDisplayName = device.displayName
        isConnected = true
        presence.drive.setMaxSpeed(maxSpeedPercent / 100.0)

        let caps = presence.capability.currentProfile.capabilitySet
        hasHeadControl = caps.hasHeadPosition
        hasSoundControl = caps.hasSound
        hasLegControl = caps.hasLegActions
        hasAnimationControl = caps.hasAnimations
        soundCategories = CapabilityRegistry.operateSoundCategories(for: device.droidType)
        animationCategories = CapabilityRegistry.operateAnimationCategories(for: device.droidType)

        let targets = CapabilityRegistry.ledTargets(for: device.droidType)
        ledTargets = targets
        hasLEDControl = !targets.isEmpty
        ledColors = Dictionary(uniqueKeysWithValues: targets.map { ($0, LEDColor.off) })
    }

    private func reflectDetached() {
        isConnected = false
        soundCategories = []
        animationCategories = []
        hasHeadControl = false
        hasSoundControl = false
        hasLegControl = false
        hasAnimationControl = false
        currentLegAction = .stop
        isMotorSoundPlaying = false
        isStreamingSensors = false
        cancelAllEffects()
        ledTargets = []
        ledColors = [:]
        activeEffect = [:]
        hasLEDControl = false
    }

    // MARK: Joystick

    func joystickMoved(to vector: JoystickVector) {
        joystickVector = vector
        presence.drive.updateJoystick(vector)

        // R2-D2 motor sound
        if hasSoundControl && !isMotorSoundPlaying && vector.magnitude > deadZone {
            if droidType == .r2d2 {
                presence.capability.playSound(id: SoundBank.motorSoundID)
                isMotorSoundPlaying = true
            }
        }

        if !isStreamingSensors && vector.magnitude > deadZone {
            presence.sensors.startStreaming()
            isStreamingSensors = true
        }
    }

    func joystickReleased() {
        joystickVector = .zero
        presence.drive.joystickReleased()

        if isMotorSoundPlaying {
            presence.capability.stopSound()
            isMotorSoundPlaying = false
        }
        if isStreamingSensors {
            presence.sensors.stopStreaming()
            isStreamingSensors = false
        }
    }

    // MARK: Stop / Power

    func emergencyStop() {
        presence.drive.emergencyStop()
        if isMotorSoundPlaying {
            presence.capability.stopSound()
            isMotorSoundPlaying = false
        }
        if isStreamingSensors {
            presence.sensors.stopStreaming()
            isStreamingSensors = false
        }
    }

    /// Disconnects this droid (BLEManager plays the farewell sequence).
    func powerOff() {
        guard let device = presence.device else { return }
        emergencyStop()
        bleManager.disconnect(from: device.id)
    }

    // MARK: Calibration

    func toggleCalibration() {
        if isCalibrating {
            confirmCalibration()
        } else {
            presence.drive.enterCalibrationMode()
            isCalibrating = true
        }
    }

    func confirmCalibration() {
        presence.drive.calibrateHeading()
        presence.drive.exitCalibrationMode()
        isCalibrating = false
        if hasSoundControl, let sound = SoundBank.randomSound(category: "Positive", for: droidType) {
            presence.capability.playSound(id: sound.id)
        }
    }

    func cancelCalibration() {
        presence.drive.exitCalibrationMode()
        isCalibrating = false
    }

    // MARK: Sound / Animation categories

    func playSoundCategory(_ category: String) {
        guard hasSoundControl,
              SoundBank.hasPlayableSounds(category: category, for: droidType) else { return }
        lastPlayedCategory = category
        if let sound = SoundBank.randomSound(category: category, for: droidType) {
            presence.capability.playSound(id: sound.id)
        }
    }

    func stopSound() {
        presence.capability.stopSound()
        lastPlayedCategory = nil
    }

    func playAnimationCategory(_ category: String) {
        guard hasAnimationControl,
              AnimationBank.hasAnimations(category: category, for: droidType) else { return }
        lastPlayedAnimationCategory = category
        if let anim = AnimationBank.randomAnimation(category: category, for: droidType) {
            presence.capability.playAnimation(id: anim.id)
        }
    }

    func stopAnimation() {
        presence.capability.stopAnimation()
        lastPlayedAnimationCategory = nil
    }

    // MARK: Direct playback (favorites)

    func playSound(id: UInt16) {
        presence.capability.playSound(id: id)
    }

    func playAnimation(id: UInt8) {
        presence.capability.playAnimation(id: id)
    }

    // MARK: Head

    func setHeadPosition(_ angle: Double) {
        headAngle = angle
        presence.capability.setHeadPosition(angle: Float(angle))
    }

    func headMoveStarted() {
        if hasSoundControl && (droidType == .r2d2 || droidType == .r2q5) {
            presence.capability.playSound(id: SoundBank.headSpinSoundID)
        }
    }

    func headMoveEnded() { }

    // MARK: Legs

    func performLegAction(_ action: R2LegAction) {
        presence.capability.performLegAction(action)
        currentLegAction = action
    }

    // MARK: LED

    func cycleLEDColor(for target: LEDTarget) {
        cancelEffect(on: target)
        let current = ledColors[target] ?? .off
        let nextColor: LEDColor
        if target.isRGB {
            let cycle = LEDColor.cycleColors
            if let idx = cycle.firstIndex(of: current) {
                nextColor = cycle[(idx + 1) % cycle.count]
            } else {
                nextColor = cycle[0]
            }
        } else {
            nextColor = (current.r == 0) ? LEDColor(r: 255, g: 255, b: 255) : .off
        }
        ledColors[target] = nextColor
        presence.capability.setRGBLED(target: target, color: nextColor)
    }

    func startEffect(_ effect: LEDEffect, on target: LEDTarget) {
        cancelEffect(on: target)
        activeEffect[target] = effect

        let isRGB = target.isRGB
        effectTasks[target] = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                switch effect {
                case .flashRedBlue:
                    self.sendLED(target: target, color: .red)
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { break }
                    self.sendLED(target: target, color: isRGB ? .blue : .off)
                    try? await Task.sleep(for: .milliseconds(300))

                case .flashWhiteOff:
                    self.sendLED(target: target, color: .white)
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { break }
                    self.sendLED(target: target, color: .off)
                    try? await Task.sleep(for: .milliseconds(200))

                case .cycleColors:
                    let colors = isRGB
                        ? LEDColor.rainbowColors
                        : [LEDColor(r: 255, g: 0, b: 0), .off]
                    for color in colors {
                        guard !Task.isCancelled else { return }
                        self.sendLED(target: target, color: color)
                        try? await Task.sleep(for: .milliseconds(400))
                    }

                case .fadeInOut:
                    for brightness in stride(from: 0, through: 255, by: 25) {
                        guard !Task.isCancelled else { return }
                        let b = UInt8(clamping: brightness)
                        let color = isRGB ? LEDColor(r: b, g: b, b: b) : LEDColor(r: b, g: 0, b: 0)
                        self.sendLED(target: target, color: color)
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    for brightness in stride(from: 255, through: 0, by: -25) {
                        guard !Task.isCancelled else { return }
                        let b = UInt8(clamping: brightness)
                        let color = isRGB ? LEDColor(r: b, g: b, b: b) : LEDColor(r: b, g: 0, b: 0)
                        self.sendLED(target: target, color: color)
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                }
            }
        }
    }

    func stopEffect(on target: LEDTarget) {
        cancelEffect(on: target)
        ledColors[target] = .off
        presence.capability.setRGBLED(target: target, color: .off)
    }

    private func cancelEffect(on target: LEDTarget) {
        effectTasks[target]?.cancel()
        effectTasks[target] = nil
        activeEffect[target] = nil
    }

    private func cancelAllEffects() {
        for (_, task) in effectTasks { task.cancel() }
        effectTasks.removeAll()
        activeEffect.removeAll()
    }

    private func sendLED(target: LEDTarget, color: LEDColor) {
        ledColors[target] = color
        presence.capability.setRGBLED(target: target, color: color)
    }

    // MARK: Lifecycle

    func onDisappear() {
        if isMotorSoundPlaying {
            presence.capability.stopSound()
            isMotorSoundPlaying = false
        }
        if isStreamingSensors {
            presence.sensors.stopStreaming()
            isStreamingSensors = false
        }
        cancelAllEffects()
        presence.drive.onViewDisappear()
    }
}
