//
//  BB8AnimationRecipes.swift
//  DroidParty
//
//  BB-8 has no onboard animation catalog and no speaker of its own.
//  To keep the animation UI parity with the other droids we synthesize
//  animations from the pieces BB-8 does have: rolling, LED flashes, and
//  audio playback via its R2-D2 proxy. Each recipe here is expressed as
//  a plain `CapabilitySequence` so it can be handed to a SequenceRunner —
//  the runner's existing soundProxy plumbing (wired in FleetViewModel)
//  automatically routes .playSound / .stopSound / .setVolume through
//  R2-D2's CapabilityController while roll / LED steps stay on BB-8's
//  own controllers.
//

import Foundation

enum BB8AnimationRecipes {

    /// Categories exposed on BB-8's animation row, matching the R-series
    /// display order so the UI feels consistent across tabs.
    static let operateCategories: [String] = [
        "Happy", "Angry", "Scared", "Curious", "Sass", "Action"
    ]

    /// Category → recipe mapping. Recipes are constructed fresh each call
    /// (they're value types built from `.roll` / `.setLEDs` / `.playSound`
    /// steps and are cheap to build).
    static func recipe(for category: String) -> CapabilitySequence {
        switch category {
        case "Happy":   return happy
        case "Excited": return excited
        case "Curious": return curious
        case "Sass":    return sass
        case "Angry":   return angry
        case "Scared":  return scared
        case "Action":  return action
        default:        return neutralWiggle
        }
    }

    // MARK: - LED helpers

    private static let bodyRGBMask: UInt8 = 0x07
    private static let backLEDMask: UInt8 = 0x00
    private static let volumeSetup: SequenceStep = .setVolume(200)

    // Random-BB-8 sound picker per category. Returns a `.playSound` step
    // for a BB-8 catalog ID (routed through R2-D2 by the SequenceRunner
    // soundProxy). If nothing matches, returns a no-op-ish `.setVolume`
    // step which is safe.
    private static func bb8Sound(_ category: String) -> SequenceStep {
        if let sound = SoundBank.randomSound(category: category, for: .bb8) {
            return .playSound(id: sound.id)
        }
        return volumeSetup
    }

    // Common cadence: 100ms nudges give the ball a visible wobble without
    // sending it careening across the room.
    private static let wiggleDelay: TimeInterval = 0.35

    // MARK: - Recipes

    /// Happy — quick left/right nudges + bright green pulses.
    static var happy: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-happy",
            name: "BB-8 Happy",
            description: "BB-8 wiggles with green LEDs and a positive sound.",
            steps: [
                volumeSetup,
                bb8Sound("Positive"),
                .setLEDs(mask: bodyRGBMask, values: [0, 255, 0]),
                .roll(heading: 315, speed: 60),
                .delay(wiggleDelay),
                .setLEDs(mask: bodyRGBMask, values: [0, 200, 100]),
                .roll(heading: 45, speed: 60),
                .delay(wiggleDelay),
                .setLEDs(mask: bodyRGBMask, values: [0, 255, 0]),
                .roll(heading: 315, speed: 60),
                .delay(wiggleDelay),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }

    /// Excited — fast little bounces + yellow flashes.
    static var excited: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-excited",
            name: "BB-8 Excited",
            description: "BB-8 hops in place with yellow flashes.",
            steps: [
                volumeSetup,
                bb8Sound("Excited"),
                .setLEDs(mask: bodyRGBMask, values: [255, 255, 0]),
                .roll(heading: 0, speed: 80),
                .delay(0.25),
                .setLEDs(mask: bodyRGBMask, values: [255, 128, 0]),
                .roll(heading: 180, speed: 80),
                .delay(0.25),
                .setLEDs(mask: bodyRGBMask, values: [255, 255, 0]),
                .roll(heading: 0, speed: 80),
                .delay(0.25),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }

    /// Curious — slow forward creep with a blue swirl.
    static var curious: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-curious",
            name: "BB-8 Curious",
            description: "BB-8 tilts forward slowly with a blue swirl.",
            steps: [
                volumeSetup,
                bb8Sound("Chatty"),
                .setLEDs(mask: bodyRGBMask, values: [0, 100, 255]),
                .roll(heading: 0, speed: 40),
                .delay(0.6),
                .setLEDs(mask: bodyRGBMask, values: [0, 180, 255]),
                .delay(0.4),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 100, 255]),
                .delay(0.4),
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }

    /// Sass — a saucy spin.
    static var sass: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-sass",
            name: "BB-8 Sass",
            description: "BB-8 does a saucy pivot with magenta.",
            steps: [
                volumeSetup,
                bb8Sound("Negative"),
                .setLEDs(mask: bodyRGBMask, values: [200, 0, 200]),
                .roll(heading: 90, speed: 70),
                .delay(0.35),
                .setLEDs(mask: bodyRGBMask, values: [255, 0, 255]),
                .roll(heading: 270, speed: 70),
                .delay(0.35),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }

    /// Angry — hard shake, red strobe.
    static var angry: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-angry",
            name: "BB-8 Angry",
            description: "Aggressive red strobe with punchy back-and-forth motion.",
            steps: [
                volumeSetup,
                bb8Sound("Alarm"),
                .setLEDs(mask: bodyRGBMask, values: [255, 0, 0]),
                .roll(heading: 90, speed: 100),
                .delay(0.2),
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
                .roll(heading: 270, speed: 100),
                .delay(0.2),
                .setLEDs(mask: bodyRGBMask, values: [255, 0, 0]),
                .roll(heading: 90, speed: 100),
                .delay(0.2),
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
                .roll(heading: 270, speed: 100),
                .delay(0.2),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }

    /// Scared — jittery little retreat with yellow flicker.
    static var scared: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-scared",
            name: "BB-8 Scared",
            description: "BB-8 retreats jitterily with yellow flicker.",
            steps: [
                volumeSetup,
                bb8Sound("Sad"),
                .setLEDs(mask: bodyRGBMask, values: [255, 255, 100]),
                .roll(heading: 180, speed: 60),
                .delay(0.3),
                .setLEDs(mask: bodyRGBMask, values: [80, 80, 40]),
                .delay(0.15),
                .setLEDs(mask: bodyRGBMask, values: [255, 255, 100]),
                .roll(heading: 200, speed: 60),
                .delay(0.3),
                .setLEDs(mask: bodyRGBMask, values: [80, 80, 40]),
                .delay(0.15),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }

    /// Action — a quick patrol lap with cycling colors.
    static var action: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-action",
            name: "BB-8 Action",
            description: "BB-8 makes a quick patrol lap with color cycling.",
            steps: [
                volumeSetup,
                bb8Sound("Hey"),
                .setLEDs(mask: bodyRGBMask, values: [255, 0, 0]),
                .roll(heading: 0, speed: 90),
                .delay(0.5),
                .setLEDs(mask: bodyRGBMask, values: [0, 255, 0]),
                .roll(heading: 90, speed: 90),
                .delay(0.5),
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 255]),
                .roll(heading: 180, speed: 90),
                .delay(0.5),
                .setLEDs(mask: bodyRGBMask, values: [255, 255, 0]),
                .roll(heading: 270, speed: 90),
                .delay(0.5),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }

    /// Fallback for unmapped categories — a short white wiggle.
    static var neutralWiggle: CapabilitySequence {
        CapabilitySequence(
            id: "bb8-anim-neutral",
            name: "BB-8 Wiggle",
            description: "A quick left-right wiggle.",
            steps: [
                volumeSetup,
                .setLEDs(mask: bodyRGBMask, values: [255, 255, 255]),
                .roll(heading: 315, speed: 60),
                .delay(0.3),
                .roll(heading: 45, speed: 60),
                .delay(0.3),
                .stopRoll,
                .setLEDs(mask: bodyRGBMask, values: [0, 0, 0]),
            ],
            compatibleFamilies: [.bbSeries]
        )
    }
}
