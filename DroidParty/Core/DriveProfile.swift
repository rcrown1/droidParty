//
//  DriveProfile.swift
//  SWSphero
//
//  Per-droid-family drive command encoding profiles.
//
//  REVERSE ENGINEERING NOTES:
//  - All Sphero Star Wars droids use the v2 API protocol for drive commands.
//  - Drive command: DID=0x16 (Driving), CID=0x07 (driveWithHeading)
//    Payload: [speed: UInt8, heading_hi: UInt8, heading_lo: UInt8, flags: UInt8]
//    flags: 0x00 = forward, 0x01 = reverse
//  - Reset yaw: DID=0x16, CID=0x06 (resetYaw), no payload
//  - Stabilization: DID=0x16, CID=0x0C, payload [flag: UInt8]
//  - Back LED: DID=0x1A (UserIO), CID=0x0E (setAllLEDs)
//  - Audio: DID=0x1A (UserIO), CID=0x07 (playAudioFile)
//    Payload: [sound_id_hi, sound_id_lo, playback_mode]
//  - Commands are sent as v2 packets (0x8D...0xD8) to the API v2 characteristic.
//

import Foundation
import CoreBluetooth

// MARK: - Drive Profile Protocol

/// Defines how drive commands are encoded for a specific droid family.
/// Each family may use different packet formats, device IDs, or command IDs.
protocol DriveProfile: Sendable {
    
    /// Human-readable name for logging.
    var profileName: String { get }
    
    /// Whether this profile supports drive commands.
    var supportsDrive: Bool { get }
    
    /// Whether this profile supports hardware heading reset.
    var supportsHeadingReset: Bool { get }
    
    /// Whether this profile supports stabilization toggle (for calibration mode).
    var supportsStabilizationToggle: Bool { get }
    
    /// Encode a drive (roll) command.
    func encodeDriveCommand(heading: UInt16, speed: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)
    
    /// Encode a stop command (speed 0, maintain heading).
    func encodeStopCommand(heading: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)
    
    /// Encode a heading reset command. Sets the current orientation as heading 0.
    func encodeHeadingResetCommand(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Encode a stabilization on/off command (used during calibration).
    func encodeStabilizationCommand(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Encode a set-back-LED brightness command (used as calibration aiming indicator).
    func encodeBackLEDCommand(brightness: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Encode a play-sound command.
    func encodeSoundCommand(soundID: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
}

// MARK: - BB-Series Drive Profile

/// Drive profile for BB-8 and BB-9E.
///
/// REVERSE ENGINEERING NOTES:
/// Uses Sphero v2 API protocol. Drive commands go to the API v2 command
/// characteristic (00010002-574F-4F20-5370-6865726F2121).
///
/// The v2 driveWithHeading command (DID=0x16, CID=0x07) payload is:
/// [speed, heading_MSB, heading_LSB, driveFlags]
/// driveFlags: 0x00 = forward, 0x01 = reverse
struct BBSeriesDriveProfile: DriveProfile {
    
    let profileName = "BB-Series"
    let supportsDrive = true
    let supportsHeadingReset = true
    let supportsStabilizationToggle = true
    
    /// API v2 command characteristic.
    private let cmdCharUUID = SpheroUUID.v2APICommand
    
    func encodeDriveCommand(heading: UInt16, speed: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        let payload = Data([speed, headingMSB, headingLSB, 0x00]) // 0x00 = forward
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.driveWithHeading,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStopCommand(heading: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        let payload = Data([0x00, headingMSB, headingLSB, 0x00]) // speed=0
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.driveWithHeading,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeHeadingResetCommand(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.resetYaw
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStabilizationCommand(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let flag: UInt8 = enabled ? 0x01 : 0x00
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.stabilization,
            payload: Data([flag])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeBackLEDCommand(brightness: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        // Set back LED via the v2 setAllLEDs command.
        // The full setAllLEDs has a complex bitmask payload; for back LED only
        // we use a simplified approach.
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.setAllLEDs,
            payload: Data([0x00, 0x01, brightness]) // LED mask for back aiming LED
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeSoundCommand(soundID: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let hi = UInt8((soundID >> 8) & 0xFF)
        let lo = UInt8(soundID & 0xFF)
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.playAudioFile,
            payload: Data([hi, lo, SpheroAudioPlaybackMode.playImmediately])
        )
        return (cmdCharUUID, packet)
    }
}

// MARK: - Legacy BB-Series Drive Profile (v1 Protocol)

/// Drive profile for original BB-8 droids that only have legacy (v1) BLE services.
///
/// REVERSE ENGINEERING NOTES:
/// The original BB-8 (2015) uses the Sphero v1 packet format (0xFF 0xFF header)
/// and writes commands to the legacy command characteristic 22BB746F-2BA1.
/// It does NOT expose the v2 API service (00010001/00010002).
///
/// V1 roll command: DID=0x02 (Sphero), CID=0x30 (Roll)
/// Payload: [speed, heading_MSB, heading_LSB, state]
///   state: 0x00 = stop, 0x01 = normal (forward), 0x02 = fast rotation
///
/// V1 heading reset: DID=0x02, CID=0x01 (setHeading), payload [heading_MSB, heading_LSB]
/// V1 stabilization: DID=0x02, CID=0x02 (setStabilization), payload [flag]
/// V1 back LED: DID=0x02, CID=0x21 (setBackLED), payload [brightness]
///
/// Legacy BB-8 does NOT have a speaker — sound commands return nil.
struct LegacyBBSeriesDriveProfile: DriveProfile {
    
    let profileName = "BB-Series (Legacy v1)"
    let supportsDrive = true
    let supportsHeadingReset = true
    let supportsStabilizationToggle = true
    
    /// Legacy command characteristic (22BB746F-2BA1).
    private let cmdCharUUID = SpheroUUID.legacyCommand
    
    func encodeDriveCommand(heading: UInt16, speed: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        // state 0x01 = normal forward driving
        let payload = Data([speed, headingMSB, headingLSB, 0x01])
        let packet = encoder.encodeV1(
            deviceID: SpheroV1DeviceID.sphero,
            commandID: SpheroV1SpheroCommand.roll,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStopCommand(heading: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        // state 0x00 = stop
        let payload = Data([0x00, headingMSB, headingLSB, 0x00])
        let packet = encoder.encodeV1(
            deviceID: SpheroV1DeviceID.sphero,
            commandID: SpheroV1SpheroCommand.roll,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeHeadingResetCommand(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        // Set heading to 0 (current direction becomes heading 0)
        let payload = Data([0x00, 0x00])
        let packet = encoder.encodeV1(
            deviceID: SpheroV1DeviceID.sphero,
            commandID: SpheroV1SpheroCommand.setHeading,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStabilizationCommand(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let flag: UInt8 = enabled ? 0x01 : 0x00
        let packet = encoder.encodeV1(
            deviceID: SpheroV1DeviceID.sphero,
            commandID: SpheroV1SpheroCommand.setStabilization,
            payload: Data([flag])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeBackLEDCommand(brightness: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV1(
            deviceID: SpheroV1DeviceID.sphero,
            commandID: SpheroV1SpheroCommand.setBackLED,
            payload: Data([brightness])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeSoundCommand(soundID: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        // Legacy BB-8 does NOT have a speaker — no sound support.
        return nil
    }
}

// MARK: - R-Series Drive Profile

/// Drive profile for R2-D2 and R2-Q5.
///
/// REVERSE ENGINEERING NOTES:
/// R-series droids have a dual-processor architecture (Nordic BLE + STM32),
/// but standard v2 API commands do NOT require explicit TID/SID routing.
/// The BLE chip automatically forwards commands to the STM32.
///
/// Confirmed from spherov2.py reference implementation: drive_with_heading,
/// play_audio_file, and other commands all use default flags (0x0A) with
/// no TID/SID. Only specialized low-level commands need explicit routing.
///
/// R-series has a built-in speaker — sound commands produce audible output
/// directly from the droid hardware.
struct RSeriesDriveProfile: DriveProfile {
    
    let profileName = "R-Series"
    let supportsDrive = true
    let supportsHeadingReset = true
    let supportsStabilizationToggle = true
    
    private let cmdCharUUID = SpheroUUID.v2APICommand
    
    func encodeDriveCommand(heading: UInt16, speed: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        let payload = Data([speed, headingMSB, headingLSB, 0x00])
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.driveWithHeading,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStopCommand(heading: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        let payload = Data([0x00, headingMSB, headingLSB, 0x00])
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.driveWithHeading,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeHeadingResetCommand(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.resetYaw
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStabilizationCommand(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let flag: UInt8 = enabled ? 0x01 : 0x00
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.stabilization,
            payload: Data([flag])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeBackLEDCommand(brightness: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.setAllLEDs,
            payload: Data([0x00, 0x01, brightness])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeSoundCommand(soundID: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let hi = UInt8((soundID >> 8) & 0xFF)
        let lo = UInt8(soundID & 0xFF)
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.playAudioFile,
            payload: Data([hi, lo, SpheroAudioPlaybackMode.playImmediately])
        )
        return (cmdCharUUID, packet)
    }
}

// MARK: - Mock Drive Profile

/// Simulation profile for testing without a connected droid.
struct MockDriveProfile: DriveProfile {
    
    let profileName = "Mock (Simulation)"
    let supportsDrive = true
    let supportsHeadingReset = true
    let supportsStabilizationToggle = true
    
    private let dummyUUID = CBUUID(string: "00000000-0000-0000-0000-000000000000")
    
    func encodeDriveCommand(heading: UInt16, speed: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        let payload = Data([speed, headingMSB, headingLSB, 0x00])
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.driveWithHeading,
            payload: payload
        )
        return (dummyUUID, packet)
    }
    
    func encodeStopCommand(heading: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data) {
        let headingMSB = UInt8((heading >> 8) & 0xFF)
        let headingLSB = UInt8(heading & 0xFF)
        let payload = Data([0x00, headingMSB, headingLSB, 0x00])
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.driveWithHeading,
            payload: payload
        )
        return (dummyUUID, packet)
    }
    
    func encodeHeadingResetCommand(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.resetYaw
        )
        return (dummyUUID, packet)
    }
    
    func encodeStabilizationCommand(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let flag: UInt8 = enabled ? 0x01 : 0x00
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.driving,
            commandID: SpheroV2DrivingCommand.stabilization,
            payload: Data([flag])
        )
        return (dummyUUID, packet)
    }
    
    func encodeBackLEDCommand(brightness: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        return (dummyUUID, Data())
    }
    
    func encodeSoundCommand(soundID: UInt16, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        return (dummyUUID, Data())
    }
}

// MARK: - Drive Profile Factory

/// Maps droid types to their drive profiles.
///
/// For BB-series droids, the factory checks discovered services to determine
/// whether the droid supports the v2 API (00010002) or only legacy v1 services
/// (22BB746F-2BA1). Original BB-8 units only have legacy services and need
/// the v1 packet format.
enum DriveProfileFactory {
    static func profile(for droidType: DroidType, discoveredServices: [DiscoveredService] = []) -> DriveProfile {
        switch droidType.family {
        case .bbSeries:
            if hasV2APICharacteristic(in: discoveredServices) {
                return BBSeriesDriveProfile()
            } else if !discoveredServices.isEmpty {
                // Services were discovered but v2 API is missing — legacy v1 droid
                return LegacyBBSeriesDriveProfile()
            } else {
                // No services discovered yet (pre-connection) — default to v2
                return BBSeriesDriveProfile()
            }
        case .rSeries:
            return RSeriesDriveProfile()
        case .unknown:
            return BBSeriesDriveProfile()
        }
    }
    
    static func mockProfile() -> DriveProfile {
        MockDriveProfile()
    }
    
    /// Check if the v2 API command characteristic (00010002) is present
    /// in the discovered services.
    private static func hasV2APICharacteristic(in services: [DiscoveredService]) -> Bool {
        let v2CharUUID = SpheroUUID.v2APICommand.uuidString.uppercased()
        for service in services {
            for char in service.characteristics {
                if char.uuid.uppercased() == v2CharUUID {
                    return true
                }
            }
        }
        return false
    }
}
