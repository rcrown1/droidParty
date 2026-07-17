//
//  SequenceModels.swift
//  SWSphero
//
//  Value types for capability sequences: ordered lists of timed
//  droid actions (animations, sounds, LEDs, head, legs, delays).
//

import Foundation

// MARK: - Sequence Step

/// A single action in a capability sequence.
enum SequenceStep: Sendable {
    case playAnimation(id: UInt8)
    case stopAnimation
    case playSound(id: UInt16)
    case stopSound
    case setVolume(UInt8)
    case setLEDs(mask: UInt8, values: [UInt8])
    case setHeadPosition(angle: Float)
    case performLegAction(R2LegAction)
    case roll(heading: UInt16, speed: UInt8)
    case stopRoll
    case delay(TimeInterval)
    
    var description: String {
        switch self {
        case .playAnimation(let id):     return "Animation #\(id)"
        case .stopAnimation:              return "Stop Animation"
        case .playSound(let id):          return "Sound #\(id)"
        case .stopSound:                  return "Stop Sound"
        case .setVolume(let v):           return "Volume \(Int(v) * 100 / 255)%"
        case .setLEDs(let mask, _):       return "LEDs mask=0x\(String(format: "%02X", mask))"
        case .setHeadPosition(let angle): return "Head \(String(format: "%.0f", angle))\u{00B0}"
        case .performLegAction(let a):    return "Leg: \(a.displayName)"
        case .roll(let h, let s):         return "Roll \(h)° speed=\(s)"
        case .stopRoll:                   return "Stop Roll"
        case .delay(let t):               return "Wait \(String(format: "%.1f", t))s"
        }
    }
}

// MARK: - Capability Sequence

/// A named, ordered sequence of capability steps.
struct CapabilitySequence: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let steps: [SequenceStep]
    /// Droid families this sequence is compatible with.
    let compatibleFamilies: Set<DroidFamily>
    /// Optional: restrict to specific droid types within compatible families.
    /// When nil, all droids in the compatible families are included.
    let restrictedToTypes: Set<DroidType>?
    
    init(id: String, name: String, description: String, steps: [SequenceStep],
         compatibleFamilies: Set<DroidFamily>, restrictedToTypes: Set<DroidType>? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.compatibleFamilies = compatibleFamilies
        self.restrictedToTypes = restrictedToTypes
    }
}

// MARK: - Starter Sequences

enum StarterSequences {
    
    /// All built-in starter sequences.
    static let all: [CapabilitySequence] = [
        partyDance,
        happyGreeting,
        alertMode,
        lightShow,
        r2Waddle,
        bb9eDramatic,
        bb8Patrol,
        bb8ColorSpin,
    ]
    
    /// Filter sequences compatible with a given droid type.
    static func compatible(with droidType: DroidType) -> [CapabilitySequence] {
        let family = droidType.family
        return all.filter { seq in
            guard seq.compatibleFamilies.contains(family) else { return false }
            if let restricted = seq.restrictedToTypes {
                return restricted.contains(droidType)
            }
            return true
        }
    }
    
    // MARK: - Definitions
    
    static let happyGreeting = CapabilitySequence(
        id: "happy-greeting",
        name: "Happy Greeting",
        description: "A cheerful greeting animation with sound and lights.",
        steps: [
            .setVolume(200),
            .playSound(id: 2600),         // Excited sound
            .delay(0.3),
            .playAnimation(id: 12),        // R2 Excited / BB9E Nervous
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [0, 255, 0]),  // Front/body green
            .delay(2.0),
            .setLEDs(mask: 0b0000_0111, values: [0, 0, 0]),    // LEDs off
            .stopAnimation,
        ],
        compatibleFamilies: [.rSeries, .bbSeries],
        restrictedToTypes: [.r2d2, .r2q5, .bb9e]
    )
    
    static let alertMode = CapabilitySequence(
        id: "alert-mode",
        name: "Alert Mode",
        description: "Red warning lights with alarm sound.",
        steps: [
            .setVolume(255),
            .setLEDs(mask: 0b0000_0111, values: [255, 0, 0]),  // Red
            .playSound(id: 1737),          // Alarm
            .delay(1.0),
            .setLEDs(mask: 0b0000_0111, values: [0, 0, 0]),    // Off
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [255, 0, 0]),  // Red
            .delay(1.0),
            .setLEDs(mask: 0b0000_0111, values: [0, 0, 0]),    // Off
            .stopSound,
        ],
        compatibleFamilies: [.rSeries, .bbSeries],
        restrictedToTypes: [.r2d2, .r2q5, .bb9e]
    )
    
    static let lightShow = CapabilitySequence(
        id: "light-show",
        name: "Light Show",
        description: "Cycle through RGB colors on all LEDs.",
        steps: [
            .setLEDs(mask: 0b0000_0111, values: [255, 0, 0]),    // Red
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [0, 255, 0]),    // Green
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [0, 0, 255]),    // Blue
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [255, 255, 0]),  // Yellow
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [255, 0, 255]),  // Magenta
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [0, 255, 255]),  // Cyan
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [255, 255, 255]),// White
            .delay(0.5),
            .setLEDs(mask: 0b0000_0111, values: [0, 0, 0]),      // Off
        ],
        compatibleFamilies: [.rSeries, .bbSeries]
    )
    
    static let r2Waddle = CapabilitySequence(
        id: "r2-waddle",
        name: "R2 Waddle Dance",
        description: "R2 waddles, plays a happy sound, then returns to bipod.",
        steps: [
            .setVolume(200),
            .performLegAction(.tripod),
            .delay(1.5),
            .playSound(id: 2919),          // Laugh
            .performLegAction(.waddle),
            .delay(3.0),
            .stopSound,
            .performLegAction(.bipod),
            .delay(1.0),
        ],
        compatibleFamilies: [.rSeries]
    )
    
    static let bb9eDramatic = CapabilitySequence(
        id: "bb9e-dramatic",
        name: "BB-9E Dramatic Entrance",
        description: "Ominous red glow with dramatic head movement.",
        steps: [
            .setVolume(220),
            .setLEDs(mask: 0b0000_0111, values: [150, 0, 0]),  // Dim red
            .delay(0.5),
            .playAnimation(id: 31),        // BB9E Ominous
            .setLEDs(mask: 0b0001_0000, values: [255]),         // Head LED on
            .delay(2.0),
            .setLEDs(mask: 0b0000_0111, values: [255, 0, 0]),  // Bright red
            .playSound(id: 1329),           // BB9E Alarm
            .delay(2.0),
            .setLEDs(mask: 0b0000_0111, values: [0, 0, 0]),    // Off
            .setLEDs(mask: 0b0001_0000, values: [0]),           // Head LED off
            .stopAnimation,
            .stopSound,
        ],
        compatibleFamilies: [.bbSeries],
        restrictedToTypes: [.bb9e]
    )
    
    // MARK: - BB-8 Motion Sequences
    
    static let bb8Patrol = CapabilitySequence(
        id: "bb8-patrol",
        name: "BB-8 Patrol",
        description: "BB-8 rolls in a square patrol pattern with scanning lights.",
        steps: [
            .setLEDs(mask: 0x07, values: [0, 100, 255]),     // Blue body
            .roll(heading: 0, speed: 80),
            .delay(1.5),
            .stopRoll,
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [255, 255, 0]),     // Yellow
            .roll(heading: 90, speed: 80),
            .delay(1.5),
            .stopRoll,
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [0, 255, 100]),     // Green
            .roll(heading: 180, speed: 80),
            .delay(1.5),
            .stopRoll,
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [255, 100, 0]),     // Orange
            .roll(heading: 270, speed: 80),
            .delay(1.5),
            .stopRoll,
            .setLEDs(mask: 0x07, values: [255, 255, 255]),   // White flash
            .delay(0.5),
            .setLEDs(mask: 0x07, values: [0, 0, 0]),         // Off
        ],
        compatibleFamilies: [.bbSeries],
        restrictedToTypes: [.bb8]
    )
    
    static let bb8ColorSpin = CapabilitySequence(
        id: "bb8-color-spin",
        name: "BB-8 Color Spin",
        description: "BB-8 spins in place while cycling through rainbow colors.",
        steps: [
            .setLEDs(mask: 0x07, values: [255, 0, 0]),       // Red
            .roll(heading: 0, speed: 60),
            .delay(0.4),
            .setLEDs(mask: 0x07, values: [255, 127, 0]),     // Orange
            .delay(0.4),
            .setLEDs(mask: 0x07, values: [255, 255, 0]),     // Yellow
            .delay(0.4),
            .setLEDs(mask: 0x07, values: [0, 255, 0]),       // Green
            .delay(0.4),
            .setLEDs(mask: 0x07, values: [0, 0, 255]),       // Blue
            .delay(0.4),
            .setLEDs(mask: 0x07, values: [148, 0, 211]),     // Violet
            .delay(0.4),
            .stopRoll,
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [255, 0, 0]),       // Red
            .roll(heading: 180, speed: 60),
            .delay(0.4),
            .setLEDs(mask: 0x07, values: [0, 255, 0]),       // Green
            .delay(0.4),
            .setLEDs(mask: 0x07, values: [0, 0, 255]),       // Blue
            .delay(0.4),
            .stopRoll,
            .setLEDs(mask: 0x07, values: [255, 255, 255]),   // White
            .delay(0.5),
            .setLEDs(mask: 0x07, values: [0, 0, 0]),         // Off
        ],
        compatibleFamilies: [.bbSeries],
        restrictedToTypes: [.bb8]
    )

    // MARK: Party Dance
    //
    // Coordinated broadcast routine used by the "All" tab. Each droid runs
    // its own compatible copy in parallel — R-series adds head + leg moves,
    // BB-series adds an aiming-light flash. LEDs cycle in sync (approximately)
    // because BLEManager batches writes per peripheral.
    static let partyDance = CapabilitySequence(
        id: "party-dance",
        name: "Party Dance",
        description: "Coordinated color-cycle and animation across the whole fleet.",
        steps: [
            // Bright entrance
            .setLEDs(mask: 0x07, values: [255, 255, 255]),
            .delay(0.4),
            // Cycle rainbow
            .setLEDs(mask: 0x07, values: [255, 0, 0]),
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [255, 128, 0]),
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [255, 255, 0]),
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [0, 255, 0]),
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [0, 128, 255]),
            .delay(0.3),
            .setLEDs(mask: 0x07, values: [148, 0, 211]),
            .delay(0.3),
            // Head wave (R-series ignores if unsupported, factory returns no-ops)
            .setHeadPosition(angle: -90),
            .delay(0.5),
            .setHeadPosition(angle: 90),
            .delay(0.5),
            .setHeadPosition(angle: 0),
            // Leg action for R-series
            .performLegAction(.waddle),
            .delay(1.5),
            .performLegAction(.stop),
            // Cool-down
            .setLEDs(mask: 0x07, values: [0, 0, 0]),
        ],
        compatibleFamilies: [.bbSeries, .rSeries]
    )
}
