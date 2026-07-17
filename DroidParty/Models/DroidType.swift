//
//  DroidType.swift
//  SWSphero
//
//  Droid type identification and classification.
//
//  REVERSE ENGINEERING NOTES:
//  - BB-8 and BB-9E are "BB-series" droids sharing a rolling-ball form factor
//    and a closely related BLE protocol derived from Sphero's SPRKk/SPRK+ lineage.
//  - R2-D2 and R2-Q5 are "R-series" droids with bipedal/tripod locomotion and
//    likely share a protocol variant that includes head rotation and stance control.
//  - All four droids were manufactured by Sphero (2015–2017) and communicate via BLE.
//  - Protocol differences between families are expected but not fully mapped yet.
//

import Foundation

// MARK: - Droid Family

/// High-level grouping of Sphero Star Wars droids by mechanical platform and protocol family.
enum DroidFamily: String, CaseIterable, Sendable {
    case bbSeries   // Rolling ball droids (BB-8, BB-9E)
    case rSeries    // Bipedal/tripod astromech droids (R2-D2, R2-Q5)
    case unknown
    
    var displayName: String {
        switch self {
        case .bbSeries: return "BB-Series"
        case .rSeries:  return "R-Series"
        case .unknown:   return "Unknown"
        }
    }
}

// MARK: - Droid Type

/// Specific droid model identification.
enum DroidType: String, CaseIterable, Identifiable, Codable, Sendable {
    case bb8
    case bb9e
    case r2d2
    case r2q5
    case unknownSphero
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .bb8:           return "BB-8"
        case .bb9e:          return "BB-9E"
        case .r2d2:          return "R2-D2"
        case .r2q5:          return "R2-Q5"
        case .unknownSphero: return "Unknown Sphero"
        }
    }
    
    var family: DroidFamily {
        switch self {
        case .bb8, .bb9e:     return .bbSeries
        case .r2d2, .r2q5:    return .rSeries
        case .unknownSphero:  return .unknown
        }
    }
    
    /// SF Symbol name for UI display (fallback when image asset is unavailable).
    var iconName: String {
        switch self {
        case .bb8:           return "circle.circle"
        case .bb9e:          return "circle.circle.fill"
        case .r2d2:          return "figure.stand"
        case .r2q5:          return "figure.stand.line.dotted.figure.stand"
        case .unknownSphero: return "questionmark.circle"
        }
    }
    
    /// Asset catalog image name for this droid type. Nil for unknown variants.
    var imageName: String? {
        switch self {
        case .bb8:           return "DroidBB8"
        case .bb9e:          return "DroidBB9E"
        case .r2d2:          return "DroidR2D2"
        case .r2q5:          return "DroidR2Q5"
        case .unknownSphero: return nil
        }
    }
    
    /// Description of known capabilities for this droid type.
    /// These are aspirational — actual capability detection happens at the protocol level.
    var expectedCapabilities: Set<DroidCapability> {
        switch self {
        case .bb8:
            // BB-8 is a legacy v1 droid: no onboard animations, no speaker
            return [.drive, .headRotation, .ledMain, .ledBack]
        case .bb9e:
            return [.drive, .headRotation, .ledMain, .ledBack, .animation, .sound]
        case .r2d2:
            return [.drive, .headRotation, .ledFront, .stanceControl, .waddle,
                    .animation, .sound, .headPosition, .legAction]
        case .r2q5:
            return [.drive, .headRotation, .ledFront, .stanceControl, .waddle,
                    .animation, .sound, .headPosition, .legAction]
        case .unknownSphero:
            return [.drive]
        }
    }
}

// MARK: - Droid Capability

/// Known or suspected capabilities of Sphero Star Wars droids.
/// Used for UI hints and future feature gating.
enum DroidCapability: String, CaseIterable, Sendable {
    case drive           // Locomotion control
    case headRotation    // Independent head/dome rotation
    case ledMain         // Primary LED (BB-series body glow)
    case ledBack         // Rear aiming LED (BB-series)
    case ledFront        // Front logic display LEDs (R-series)
    case stanceControl   // Bipod/tripod stance switching (R-series)
    case waddle          // Waddle animation (R-series)
    case animation       // Canned animation sequences
    case sound           // Onboard speaker / audio playback
    case headPosition    // Dome rotation to specific angle (R-series)
    case legAction       // Bipod/tripod/waddle leg transitions (R-series)
    
    var displayName: String {
        switch self {
        case .drive:         return "Drive"
        case .headRotation:  return "Head Rotation"
        case .ledMain:       return "Main LED"
        case .ledBack:       return "Back LED"
        case .ledFront:      return "Front LEDs"
        case .stanceControl: return "Stance Control"
        case .waddle:        return "Waddle"
        case .animation:     return "Animations"
        case .sound:         return "Sound"
        case .headPosition:  return "Head Position"
        case .legAction:     return "Leg Action"
        }
    }
}

// MARK: - Droid Identification Heuristics

/// Attempts to classify a droid based on BLE advertisement data.
///
/// REVERSE ENGINEERING NOTES:
/// - BB-8 typically advertises with a local name containing "BB-" or "BB8".
/// - BB-9E may advertise as "BB-9E" or "GB-" (some firmware versions).
/// - R2-D2 advertises as "D2-" or "R2D2" in some configurations.
/// - R2-Q5 advertises as "Q5-" or "R2Q5".
/// - Sphero droids generally include specific manufacturer data in their
///   advertisement packets. The exact format varies by firmware version.
/// - Service UUIDs in the advertisement can also help distinguish droid families.
///
/// This classifier uses a layered approach:
/// 1. Exact name prefix matching (most reliable)
/// 2. Service UUID pattern matching
/// 3. Manufacturer data analysis (least reliable, firmware-dependent)
struct DroidIdentifier {
    
    /// Classify a discovered peripheral based on available advertisement data.
    /// - Parameters:
    ///   - name: The advertised local name (may be nil or truncated).
    ///   - serviceUUIDs: Advertised service UUIDs from the scan response.
    ///   - manufacturerData: Raw manufacturer-specific data from the advertisement.
    /// - Returns: The best-guess droid type.
    static func classify(
        name: String?,
        serviceUUIDs: [String]?,
        manufacturerData: Data?
    ) -> DroidType {
        // Layer 1: Name-based identification (most reliable)
        if let name = name?.uppercased() {
            if name.contains("BB-8") || name.hasPrefix("BB8") || name.hasPrefix("BB-") && !name.contains("9E") {
                return .bb8
            }
            if name.contains("BB-9E") || name.contains("BB9E") || name.hasPrefix("GB-") {
                return .bb9e
            }
            if name.contains("R2-D2") || name.contains("R2D2") || name.hasPrefix("D2-") {
                return .r2d2
            }
            if name.contains("R2-Q5") || name.contains("R2Q5") || name.hasPrefix("Q5-") {
                return .r2q5
            }
        }
        
        // Layer 2: Service UUID pattern matching
        // ASSUMPTION: Sphero droids advertise with specific service UUIDs.
        // The "Anti-DoS" and "Robot Control" services use known Sphero-specific UUIDs.
        // If we see Sphero service UUIDs but can't identify the specific model,
        // we at least know it's a Sphero device.
        if let uuids = serviceUUIDs {
            let spheroServicePrefixes = [
                "22BB746F",  // Known Sphero BLE service prefix (various)
                "00020001",  // Sphero v2 API service prefix (observed on newer firmware)
            ]
            let isSphero = uuids.contains { uuid in
                let upper = uuid.uppercased().replacingOccurrences(of: "-", with: "")
                return spheroServicePrefixes.contains { upper.hasPrefix($0) }
            }
            if isSphero {
                return .unknownSphero
            }
        }
        
        // Layer 3: Manufacturer data fingerprinting
        // ASSUMPTION: Sphero devices include company ID in manufacturer data.
        // This is speculative and needs validation with real hardware.
        if let data = manufacturerData, data.count >= 2 {
            // Sphero's Bluetooth SIG company ID (hypothesized based on community research)
            // Company IDs are little-endian 16-bit values at the start of manufacturer data.
            let companyID = UInt16(data[0]) | (UInt16(data[1]) << 8)
            // Known Sphero-associated company IDs (may need expansion)
            let spheroCompanyIDs: Set<UInt16> = [0x0138, 0x01A2]
            if spheroCompanyIDs.contains(companyID) {
                return .unknownSphero
            }
        }
        
        // Cannot identify — this is not necessarily a Sphero device.
        // Callers should use this alongside a broader "isSpheroDevice" check.
        return .unknownSphero
    }
    
    /// Quick check: does this look like a Sphero device at all?
    static func isSpheroDevice(
        name: String?,
        serviceUUIDs: [String]?,
        manufacturerData: Data?
    ) -> Bool {
        // Name-based quick check
        if let name = name?.uppercased() {
            let knownPrefixes = ["BB-", "BB8", "BB9", "GB-", "D2-", "R2D", "R2Q", "Q5-", "SK-", "SPRK"]
            if knownPrefixes.contains(where: { name.hasPrefix($0) }) {
                return true
            }
        }
        
        // Service UUID check
        if let uuids = serviceUUIDs {
            let spheroPrefixes = ["22BB746F", "00020001"]
            if uuids.contains(where: { uuid in
                let upper = uuid.uppercased().replacingOccurrences(of: "-", with: "")
                return spheroPrefixes.contains(where: { upper.hasPrefix($0) })
            }) {
                return true
            }
        }
        
        return false
    }
}
