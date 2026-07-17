//
//  DriveState.swift
//  SWSphero
//
//  Drive system state tracking.
//

import Foundation

/// Overall state of the drive system for a connected droid.
enum DriveMode: String, Sendable {
    case idle           // Connected but not driving
    case driving        // Actively receiving joystick input
    case stopping       // Transitioning to stop
    case calibrating    // Heading calibration in progress
    case disabled       // Not connected or drive not available
}

/// Snapshot of current drive state for UI display.
struct DriveState: Equatable, Sendable {
    var mode: DriveMode = .disabled
    var currentSpeed: UInt8 = 0
    var currentHeading: UInt16 = 0
    var rawJoystickAngle: Double = 0
    var headingOffset: Double = 0
    var maxSpeedFraction: Double = 1.0  // Default 100%
    var deadZone: Double = 0.12         // Default 0.12
    var commandRate: Double = 10.0      // Commands per second
    var commandsSent: UInt64 = 0
    var lastCommandTime: Date?
    
    /// Calibrated heading = raw heading + offset, wrapped to 0–359.
    var calibratedHeading: UInt16 {
        var h = Double(currentHeading) + headingOffset
        h = h.truncatingRemainder(dividingBy: 360.0)
        if h < 0 { h += 360.0 }
        return UInt16(h) % 360
    }
    
    /// Speed as a percentage string.
    var speedPercent: String {
        let pct = Double(currentSpeed) / 255.0 * 100.0
        return String(format: "%.0f%%", pct)
    }
}

/// Heading calibration state.
struct HeadingState: Equatable, Sendable {
    /// Software heading offset in degrees. Added to all drive commands.
    var offset: Double = 0.0
    
    /// Whether a hardware heading reset has been sent.
    var hardwareResetSent: Bool = false
    
    /// Nudge increment in degrees for fine adjustment.
    var nudgeIncrement: Double = 15.0
    
    /// Wrapped offset for display (0–359).
    var displayOffset: Int {
        var o = offset.truncatingRemainder(dividingBy: 360.0)
        if o < 0 { o += 360.0 }
        return Int(o.rounded()) % 360
    }
}
