//
//  SensorData.swift
//  SWSphero
//
//  Sensor telemetry and battery state models.
//
//  V1 SENSOR STREAMING PROTOCOL:
//  BB-8 uses the v1 setDataStreaming command (DID=0x02, CID=0x11).
//  The command payload specifies a sample rate divisor, frame count,
//  sensor selection bitmask, and packet count.
//
//  Sensor data arrives as v1 asynchronous notifications (SOP2=0xFE,
//  asyncID=0x0003). The payload contains big-endian Int16 values
//  in the order defined by the active bitmask.
//
//  Base sample rate is 400 Hz. Divisor of 40 yields 10 Hz.
//

import Foundation

// MARK: - Sensor Data

/// IMU orientation data from the droid's onboard sensors.
struct SensorData: Equatable, Sendable {
    /// Pitch angle in degrees (-180 to 180).
    var pitch: Double = 0
    /// Roll angle in degrees (-180 to 180).
    var roll: Double = 0
    /// Yaw/heading angle in degrees (0 to 360).
    var yaw: Double = 0
    /// When this reading was received.
    var timestamp: Date = Date()
}

// MARK: - Battery State

/// Battery voltage and derived percentage.
struct BatteryState: Equatable, Sendable {
    /// Raw voltage in millivolts from getBatteryVoltage response.
    var voltageMillivolts: UInt16 = 0
    
    /// Estimated charge percentage (0-100).
    /// Uses standard LiPo curve: 3500mV = 0%, 4200mV = 100%.
    var percentage: Int {
        guard voltageMillivolts > 0 else { return 0 }
        let clamped = min(4200, max(3500, Int(voltageMillivolts)))
        return (clamped - 3500) * 100 / 700
    }
    
    /// SF Symbol name for the battery icon.
    var iconName: String {
        switch percentage {
        case 88...100: return "battery.100"
        case 63..<88:  return "battery.75"
        case 38..<63:  return "battery.50"
        case 13..<38:  return "battery.25"
        default:       return "battery.0"
        }
    }
    
    /// Color for battery display: green > 50%, yellow 20-50%, red < 20%.
    var isLow: Bool { percentage < 20 }
    var isMedium: Bool { percentage >= 20 && percentage <= 50 }
}

// MARK: - V1 Sensor Streaming Masks

/// Bitmask constants for the v1 setDataStreaming command.
///
/// These select which sensor values appear in the streaming payload.
/// Values are from the Sphero API documentation.
/// The payload contains big-endian Int16 values in bit-order (MSB first).
enum V1SensorMask {
    // Mask 1 (first 32-bit bitmask in setDataStreaming payload)
    static let accelXRaw: UInt32       = 0x8000_0000
    static let accelYRaw: UInt32       = 0x4000_0000
    static let accelZRaw: UInt32       = 0x2000_0000
    static let gyroXRaw: UInt32        = 0x1000_0000
    static let gyroYRaw: UInt32        = 0x0800_0000
    static let gyroZRaw: UInt32        = 0x0400_0000
    
    static let imuPitchFiltered: UInt32  = 0x0004_0000
    static let imuRollFiltered: UInt32   = 0x0002_0000
    static let imuYawFiltered: UInt32    = 0x0001_0000
    
    static let accelXFiltered: UInt32    = 0x0000_8000
    static let accelYFiltered: UInt32    = 0x0000_4000
    static let accelZFiltered: UInt32    = 0x0000_2000
    
    static let gyroXFiltered: UInt32     = 0x0000_0040
    static let gyroYFiltered: UInt32     = 0x0000_0020
    static let gyroZFiltered: UInt32     = 0x0000_0010
    
    /// IMU pitch + roll + yaw (filtered). 3 × Int16 = 6 bytes per packet.
    static let imuAll: UInt32 = imuPitchFiltered | imuRollFiltered | imuYawFiltered
}

// MARK: - V1 Async Notification IDs

/// Async notification IDs for v1 protocol (SOP2=0xFE).
enum V1AsyncID {
    static let sensorData: UInt16       = 0x0003
    static let collisionDetected: UInt16 = 0x0007
    static let selfLevelComplete: UInt16 = 0x000B
}
