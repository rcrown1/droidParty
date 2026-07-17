//
//  CapabilityModels.swift
//  SWSphero
//
//  Value types for the Droid Capabilities Lab.
//
//  These models describe animations, sounds, LED targets, and other
//  droid capabilities in a droid-agnostic way. The CapabilityRegistry
//  provides per-droid-type catalogs of these descriptors.
//

import Foundation
import SwiftUI

// MARK: - Animation Descriptor

/// Describes a single onboard animation routine.
///
/// Animation IDs are device-specific uint8 values sent via the
/// Animatronic play_animation command (DID=0x17, CID=0x05).
struct AnimationDescriptor: Identifiable, Hashable, Sendable {
    let id: UInt8
    let name: String
    let category: String
    
    var displayName: String { name }
    var displayID: String { String(format: "0x%02X (%d)", id, id) }
}

// MARK: - Sound Descriptor

/// Describes a single onboard sound/audio file.
///
/// Sound IDs are device-specific uint16 values sent via the
/// IO play_audio_file command (DID=0x1A, CID=0x07).
///
/// Quality ratings per droid (from hardware testing):
///   0 = silent, 1 = very short blip, 2 = short sound, 3 = rich sequence, 9 = test-only
struct SoundDescriptor: Identifiable, Hashable, Sendable {
    let id: UInt16
    let name: String
    let category: String
    /// Quality rating on R2-D2: 0=silent, 1=blip, 2=short, 3=rich, 9=test-only
    var d2Rating: Int = 0
    /// Quality rating on R2-Q5: 0=silent, 1=blip, 2=short, 3=rich, 9=test-only
    var q5Rating: Int = 0
    /// Quality rating on BB-8. BB-8 has no speaker; the sound actually plays
    /// on its R2-D2 proxy, but the entry lives in the BB-8 catalog so the
    /// UI can categorize/select it. Default 3 (rich) — BB-8's canonical
    /// sound library is small and every entry is worth surfacing.
    var bb8Rating: Int = 3
    /// Quality rating on BB-9E. Same story: BB-9E has no speaker; sounds
    /// are played by R2-Q5 proxy. Default 3 (rich).
    var bb9eRating: Int = 3
    /// If true, this sound should not appear in the sound menu (e.g. motor, head spin).
    /// It is played contextually by the system.
    var isContextual: Bool = false

    var displayName: String { name }
    var displayID: String { String(format: "0x%04X (%d)", id, id) }

    /// Returns the quality rating for a specific droid type.
    func rating(for droidType: DroidType) -> Int {
        switch droidType {
        case .r2d2: return d2Rating
        case .r2q5: return q5Rating
        case .bb8:  return bb8Rating
        case .bb9e: return bb9eRating
        default: return 0
        }
    }
}

// MARK: - LED Target

/// Identifies a controllable LED or LED group on a droid.
///
/// Different droid families have different LED layouts:
/// - R2-D2/R2-Q5: front RGB (3 channels), logic displays, back RGB (3 channels), holo projector
/// - BB-9E: body RGB (3 channels), aiming LED, head LED
/// - BB-8 (legacy): body RGB (v1 setRGBLED) + back LED (v1 setBackLED)
enum LEDTarget: String, CaseIterable, Identifiable, Sendable {
    case frontRGB        // R2-D2/R2-Q5 front LED (RGB)
    case backRGB         // R2-D2/R2-Q5 back LED (RGB)
    case logicDisplays   // R2-D2/R2-Q5 logic display intensity
    case holoProjector   // R2-D2/R2-Q5 holoprojector intensity
    case bodyRGB         // BB-9E body LED (RGB)
    case headLED         // BB-9E head LED (single channel)
    case aimingLED       // BB-9E aiming LED (single channel)
    case backLED         // BB-8 back aiming LED (single channel, v1)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .frontRGB:      return "Front LEDs"
        case .backRGB:       return "Back LEDs"
        case .logicDisplays: return "Logic Displays"
        case .holoProjector: return "Holo Projector"
        case .bodyRGB:       return "Body LEDs"
        case .headLED:       return "Head LED"
        case .aimingLED:     return "Aiming LED"
        case .backLED:       return "Back LED"
        }
    }
    
    var shortName: String {
        switch self {
        case .frontRGB:      return "Front"
        case .backRGB:       return "Back"
        case .logicDisplays: return "Logic"
        case .holoProjector: return "Holo"
        case .bodyRGB:       return "Body"
        case .headLED:       return "Head"
        case .aimingLED:     return "Aim"
        case .backLED:       return "Back"
        }
    }
    
    /// Whether this target accepts RGB color values (3 channels)
    /// vs a single brightness value (1 channel).
    var isRGB: Bool {
        switch self {
        case .frontRGB, .backRGB, .bodyRGB: return true
        case .logicDisplays, .holoProjector, .headLED, .aimingLED, .backLED: return false
        }
    }
    
    /// SF Symbol name for the Operate screen LED overlay.
    var iconName: String {
        switch self {
        case .frontRGB:      return "lightbulb.fill"
        case .backRGB:       return "lightbulb.max.fill"
        case .logicDisplays: return "display"
        case .holoProjector: return "film.stack.fill"
        case .bodyRGB:       return "circle.fill"
        case .headLED:       return "light.overhead.right.fill"
        case .aimingLED:     return "scope"
        case .backLED:       return "flashlight.on.fill"
        }
    }
}

// MARK: - LED Color

/// Simple RGB color value for LED commands.
struct LEDColor: Equatable, Hashable, Sendable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    
    static let off = LEDColor(r: 0, g: 0, b: 0)
    static let white = LEDColor(r: 255, g: 255, b: 255)
    static let red = LEDColor(r: 255, g: 0, b: 0)
    static let green = LEDColor(r: 0, g: 255, b: 0)
    static let blue = LEDColor(r: 0, g: 0, b: 255)
    static let yellow = LEDColor(r: 255, g: 255, b: 0)
    static let cyan = LEDColor(r: 0, g: 255, b: 255)
    static let magenta = LEDColor(r: 255, g: 0, b: 255)
    
    /// Colors cycled through when tapping an LED button on the Operate screen.
    static let cycleColors: [LEDColor] = [.red, .green, .blue, .white, .off]
    
    /// Full rainbow for the cycle-colors effect.
    static let rainbowColors: [LEDColor] = [.red, .yellow, .green, .cyan, .blue, .magenta]
    
    /// SwiftUI Color representation for icon tinting.
    var swiftUIColor: Color {
        if r == 0 && g == 0 && b == 0 {
            return .gray
        }
        return Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}

// MARK: - LED Effect

/// Light effects available via long-press on LED buttons.
enum LEDEffect: String, CaseIterable, Identifiable, Sendable {
    case flashRedBlue
    case flashWhiteOff
    case cycleColors
    case fadeInOut
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .flashRedBlue:  return "Flash Red/Blue"
        case .flashWhiteOff: return "Strobe"
        case .cycleColors:   return "Cycle Colors"
        case .fadeInOut:      return "Breathe"
        }
    }
    
    var iconName: String {
        switch self {
        case .flashRedBlue:  return "light.beacon.max.fill"
        case .flashWhiteOff: return "bolt.fill"
        case .cycleColors:   return "rainbow"
        case .fadeInOut:      return "wave.3.up"
        }
    }
}

// MARK: - R2 Leg Action

/// Leg/stance actions for R2-D2 and R2-Q5.
///
/// Sent via the Animatronic perform_leg_action command (DID=0x17, CID=0x0D).
/// Values match the spherov2.py R2LegActions enum.
enum R2LegAction: UInt8, CaseIterable, Identifiable, Sendable {
    case stop     = 0
    case tripod   = 1  // Three-leg stance (required for rolling)
    case bipod    = 2  // Two-leg stance (default standing)
    case waddle   = 3  // Side-to-side waddle animation
    
    var id: UInt8 { rawValue }
    
    var displayName: String {
        switch self {
        case .stop:   return "Stop"
        case .tripod: return "Tripod (3 legs)"
        case .bipod:  return "Bipod (2 legs)"
        case .waddle: return "Waddle"
        }
    }
    
    /// Whether this action involves physical motion.
    var involvesMotion: Bool {
        switch self {
        case .stop:   return false
        case .tripod: return true
        case .bipod:  return true
        case .waddle: return true
        }
    }
}

// MARK: - Capability Set

/// Describes what capability categories a specific droid supports.
///
/// Used by the UI to show/hide sections in the Capabilities Lab,
/// and by the controller to guard against unsupported commands.
struct CapabilitySet: Equatable, Sendable {
    var hasAnimations: Bool = false
    var hasSound: Bool = false
    var hasRGBLEDs: Bool = false
    var hasSingleLED: Bool = false
    var hasHeadPosition: Bool = false
    var hasLegActions: Bool = false
    
    /// Whether any capability beyond basic LED is available.
    var hasAnyAdvanced: Bool {
        hasAnimations || hasSound || hasHeadPosition || hasLegActions
    }
}
