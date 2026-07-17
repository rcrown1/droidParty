//
//  JoystickVector.swift
//  SWSphero
//
//  Represents the normalized output of a virtual joystick and the
//  derived drive parameters (heading, speed) after dead zone and calibration.
//

import Foundation

// MARK: - Joystick Vector

/// Raw normalized joystick position.
/// Origin is center, x ranges -1…1 (left/right), y ranges -1…1 (down/up).
struct JoystickVector: Equatable, Sendable {
    let x: Double   // -1.0 (left) to 1.0 (right)
    let y: Double   // -1.0 (down) to 1.0 (up)
    
    static let zero = JoystickVector(x: 0, y: 0)
    
    /// Distance from center (0…1, clamped).
    var magnitude: Double {
        min(1.0, sqrt(x * x + y * y))
    }
    
    /// Angle in degrees (0 = forward/up, clockwise).
    /// Sphero heading convention: 0 = forward, 90 = right, 180 = back, 270 = left.
    var angleDegrees: Double {
        guard magnitude > 0.001 else { return 0 }
        // atan2 gives angle from positive X axis, counter-clockwise.
        // We need angle from positive Y axis (forward), clockwise.
        let radians = atan2(x, y) // Note: atan2(x, y) not atan2(y, x)
        var degrees = radians * 180.0 / .pi
        if degrees < 0 { degrees += 360.0 }
        return degrees
    }
    
    /// Whether the joystick is within the dead zone.
    func isInDeadZone(_ deadZone: Double) -> Bool {
        magnitude < deadZone
    }
}

// MARK: - Drive Parameters

/// Computed drive parameters derived from joystick input + calibration.
struct DriveParameters: Equatable, Sendable {
    /// Heading in degrees (0–359), with calibration offset applied.
    let heading: UInt16
    
    /// Speed (0–255), scaled by max speed setting.
    let speed: UInt8
    
    /// Whether this represents a stop command (speed = 0).
    var isStopped: Bool { speed == 0 }
    
    static let stop = DriveParameters(heading: 0, speed: 0)
    
    /// Compute drive parameters from a joystick vector.
    ///
    /// - Parameters:
    ///   - vector: Raw joystick position.
    ///   - deadZone: Minimum magnitude before registering input (0…1).
    ///   - maxSpeedFraction: Maximum speed as fraction of 255 (0…1).
    ///   - headingOffset: Calibration offset in degrees (added to raw heading).
    /// - Returns: Drive parameters ready for command encoding.
    static func from(
        vector: JoystickVector,
        deadZone: Double,
        maxSpeedFraction: Double,
        headingOffset: Double
    ) -> DriveParameters {
        // Dead zone check
        guard !vector.isInDeadZone(deadZone) else {
            return .stop
        }
        
        // Remap magnitude: dead zone → 1.0 maps to 0.0 → 1.0
        let remapped = (vector.magnitude - deadZone) / (1.0 - deadZone)
        let clampedMagnitude = min(1.0, max(0.0, remapped))
        
        // Speed: magnitude * max speed, scaled to 0–255
        let speedFloat = clampedMagnitude * maxSpeedFraction * 255.0
        let speed = UInt8(min(255, max(0, Int(speedFloat.rounded()))))
        
        // Heading: joystick angle + calibration offset, wrapped to 0–359
        var heading = vector.angleDegrees + headingOffset
        heading = heading.truncatingRemainder(dividingBy: 360.0)
        if heading < 0 { heading += 360.0 }
        let headingInt = UInt16(heading.rounded()) % 360
        
        return DriveParameters(heading: headingInt, speed: speed)
    }
}
