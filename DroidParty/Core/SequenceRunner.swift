//
//  SequenceRunner.swift
//  SWSphero
//
//  Executes CapabilitySequence steps in order with timed delays,
//  dispatching each action through a CapabilityController.
//

import Foundation
import Combine

// MARK: - Sequence Runner State

enum SequenceRunnerState: Equatable {
    case idle
    case running(stepIndex: Int, totalSteps: Int)
    case finished
    case cancelled
}

// MARK: - Sequence Runner

@MainActor
final class SequenceRunner: ObservableObject {
    
    @Published private(set) var state: SequenceRunnerState = .idle
    @Published private(set) var currentSequence: CapabilitySequence?
    
    private let controller: CapabilityController
    private let logger: BLELogger
    private var runTask: Task<Void, Never>?
    
    init(controller: CapabilityController, logger: BLELogger? = nil) {
        self.controller = controller
        self.logger = logger ?? BLELogger.shared
    }
    
    /// Run a sequence. Cancels any currently running sequence.
    func run(_ sequence: CapabilitySequence) {
        cancel()
        
        currentSequence = sequence
        state = .running(stepIndex: 0, totalSteps: sequence.steps.count)
        logger.info(.capability, "Sequence started: \(sequence.name) (\(sequence.steps.count) steps)")
        
        runTask = Task { [weak self] in
            guard let self = self else { return }
            
            for (index, step) in sequence.steps.enumerated() {
                guard !Task.isCancelled else {
                    self.state = .cancelled
                    self.logger.info(.capability, "Sequence cancelled at step \(index + 1)")
                    return
                }
                
                self.state = .running(stepIndex: index, totalSteps: sequence.steps.count)
                self.executeStep(step)
                
                if case .delay(let interval) = step {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } else {
                    // Brief pause between non-delay steps to let commands settle
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
            }
            
            if !Task.isCancelled {
                self.state = .finished
                self.logger.info(.capability, "Sequence finished: \(sequence.name)")
            }
        }
    }
    
    /// Cancel the currently running sequence.
    func cancel() {
        runTask?.cancel()
        runTask = nil
        if case .running = state {
            state = .cancelled
            controller.stopAll()
            logger.info(.capability, "Sequence cancelled by user")
        }
    }
    
    /// Reset state back to idle.
    func reset() {
        cancel()
        state = .idle
        currentSequence = nil
    }
    
    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }
    
    // MARK: - Step Execution
    
    private func executeStep(_ step: SequenceStep) {
        switch step {
        case .playAnimation(let id):
            controller.playAnimation(id: id)
        case .stopAnimation:
            controller.stopAnimation()
        case .playSound(let id):
            controller.playSound(id: id)
        case .stopSound:
            controller.stopSound()
        case .setVolume(let vol):
            controller.setVolume(vol)
        case .setLEDs(let mask, let values):
            controller.setLEDs(mask: mask, values: values)
        case .setHeadPosition(let angle):
            controller.setHeadPosition(angle: angle)
        case .performLegAction(let action):
            controller.performLegAction(action)
        case .roll(let heading, let speed):
            controller.roll(heading: heading, speed: speed)
        case .stopRoll:
            controller.stopRoll()
        case .delay:
            break // Handled by caller
        }
    }
}
