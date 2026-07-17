//
//  CapabilityProfile.swift
//  SWSphero
//
//  Per-droid-family capability command encoding profiles.
//
//  Follows the DriveProfile strategy pattern: each droid family has its
//  own implementation that knows how to encode animation, sound, LED,
//  head position, and leg action commands for that hardware.
//
//  REVERSE ENGINEERING NOTES:
//  - Animatronic commands use DID=0x17 (Animation device)
//  - IO commands (LEDs, audio) use DID=0x1A (UserIO device)
//  - All v2 commands are sent to characteristic 00010002
//  - R2-D2/R2-Q5 have 8 LED indices, dome rotation, and leg actions
//  - BB-9E has 5 LED indices, animations, and sounds
//  - BB-8 (legacy v1) has only a back LED via v1 protocol
//

import Foundation
import CoreBluetooth

// MARK: - Capability Profile Protocol

/// Defines how capability commands are encoded for a specific droid family.
protocol CapabilityProfile: Sendable {
    
    /// Human-readable name for logging.
    var profileName: String { get }
    
    /// Describes what this droid supports.
    var capabilitySet: CapabilitySet { get }
    
    // MARK: - Animation Commands
    
    /// Encode a play animation command. Returns nil if unsupported.
    func encodePlayAnimation(id: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Encode a stop animation command.
    func encodeStopAnimation(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Encode an enable/disable idle animations command.
    func encodeEnableIdleAnimations(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    // MARK: - Sound Commands
    
    /// Encode a play sound command.
    func encodePlaySound(id: UInt16, mode: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Encode a stop all audio command.
    func encodeStopSound(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Encode a set volume command.
    func encodeSetVolume(volume: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    // MARK: - LED Commands
    
    /// Encode an LED command using an 8-bit mask and corresponding values.
    func encodeSetLEDs(mask: UInt8, values: [UInt8], encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    // MARK: - Head Position (R-series)
    
    /// Encode a set head/dome position command. Angle in degrees.
    func encodeSetHeadPosition(angle: Float, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
    
    // MARK: - Leg Actions (R-series)
    
    /// Encode a perform leg action command.
    func encodePerformLegAction(_ action: R2LegAction, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)?
}

// MARK: - R-Series Capability Profile

/// Capability profile for R2-D2 and R2-Q5.
///
/// Full support: 56 animations, 230+ sounds, 8 LED channels,
/// dome rotation (-160° to 180°), and leg actions (bipod/tripod/waddle).
struct RSeriesCapabilityProfile: CapabilityProfile {
    
    let profileName = "R-Series Capabilities"
    
    let capabilitySet = CapabilitySet(
        hasAnimations: true,
        hasSound: true,
        hasRGBLEDs: true,
        hasSingleLED: true,
        hasHeadPosition: true,
        hasLegActions: true
    )
    
    private let cmdCharUUID = SpheroUUID.v2APICommand
    
    // MARK: - Animations
    
    /// Play animation payload is a 16-bit big-endian animation ID: [hi, lo].
    /// Reference: spherov2.py sends `to_bytes(animation, 2)`;
    /// spherov2.js sends `[0x00, animation]`.
    func encodePlayAnimation(id: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.playAnimation,
            payload: Data([0x00, id])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStopAnimation(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.stopAnimation
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeEnableIdleAnimations(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.enableIdleAnimations,
            payload: Data([enabled ? 0x01 : 0x00])
        )
        return (cmdCharUUID, packet)
    }
    
    // MARK: - Sounds
    
    func encodePlaySound(id: UInt16, mode: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let hi = UInt8((id >> 8) & 0xFF)
        let lo = UInt8(id & 0xFF)
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.playAudioFile,
            payload: Data([hi, lo, mode])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStopSound(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.stopAudio
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeSetVolume(volume: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.setAudioVolume,
            payload: Data([volume])
        )
        return (cmdCharUUID, packet)
    }
    
    // MARK: - LEDs
    
    /// R2-D2/R2-Q5 LED mask bits (16-bit mask, high byte always 0x00):
    /// Front RGB = 0x07 (bits 0-2), Logic Displays = 0x08 (bit 3),
    /// Back RGB = 0x70 (bits 4-6), Holo Projector = 0x80 (bit 7)
    ///
    /// Reference: spherov2.js uses CID=0x0E (allLEDs / 16-bit mask),
    /// payload: [0x00, mask, values...] where 0x00 is the mask high byte.
    func encodeSetLEDs(mask: UInt8, values: [UInt8], encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        var payload = Data([0x00, mask])
        payload.append(contentsOf: values)
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.setAllLEDs,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    // MARK: - Head Position
    
    func encodeSetHeadPosition(angle: Float, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let angleBytes = PacketEncoder.encodeFloat32(angle)
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.setHeadPosition,
            payload: angleBytes
        )
        return (cmdCharUUID, packet)
    }
    
    // MARK: - Leg Actions
    
    func encodePerformLegAction(_ action: R2LegAction, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.performLegAction,
            payload: Data([action.rawValue])
        )
        return (cmdCharUUID, packet)
    }
}

// MARK: - BB-9E Capability Profile

/// Capability profile for BB-9E.
///
/// Supports: 49 animations, sounds (BB9E range), 5 LED channels.
/// No head position or leg actions (rolling ball design).
struct BB9ECapabilityProfile: CapabilityProfile {
    
    let profileName = "BB-9E Capabilities"
    
    let capabilitySet = CapabilitySet(
        hasAnimations: true,
        hasSound: true,
        hasRGBLEDs: true,
        hasSingleLED: true,
        hasHeadPosition: false,
        hasLegActions: false
    )
    
    private let cmdCharUUID = SpheroUUID.v2APICommand
    
    // MARK: - Animations
    
    /// Play animation payload is a 16-bit big-endian animation ID: [hi, lo].
    func encodePlayAnimation(id: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.playAnimation,
            payload: Data([0x00, id])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStopAnimation(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.stopAnimation
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeEnableIdleAnimations(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.animation,
            commandID: SpheroV2AnimatronicCommand.enableIdleAnimations,
            payload: Data([enabled ? 0x01 : 0x00])
        )
        return (cmdCharUUID, packet)
    }
    
    // MARK: - Sounds
    
    func encodePlaySound(id: UInt16, mode: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let hi = UInt8((id >> 8) & 0xFF)
        let lo = UInt8(id & 0xFF)
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.playAudioFile,
            payload: Data([hi, lo, mode])
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeStopSound(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.stopAudio
        )
        return (cmdCharUUID, packet)
    }
    
    func encodeSetVolume(volume: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.setAudioVolume,
            payload: Data([volume])
        )
        return (cmdCharUUID, packet)
    }
    
    // MARK: - LEDs
    
    /// BB-9E LED mask bits (16-bit mask, high byte always 0x00):
    /// Body RGB = 0x07 (bits 0-2), Aiming = 0x08 (bit 3), Head = 0x10 (bit 4)
    func encodeSetLEDs(mask: UInt8, values: [UInt8], encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        var payload = Data([0x00, mask])
        payload.append(contentsOf: values)
        let packet = encoder.encodeV2(
            deviceID: SpheroV2DeviceID.userIO,
            commandID: SpheroV2UserIOCommand.setAllLEDs,
            payload: payload
        )
        return (cmdCharUUID, packet)
    }
    
    // MARK: - Unsupported
    
    func encodeSetHeadPosition(angle: Float, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodePerformLegAction(_ action: R2LegAction, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
}

// MARK: - BB-8 Legacy Capability Profile

/// Capability profile for original BB-8 droids with only legacy v1 services.
///
/// LEDs: body RGB via v1 setRGBLED (DID=0x02, CID=0x20, payload [r,g,b]),
///        back aiming LED via v1 setBackLED (DID=0x02, CID=0x21, payload [brightness]).
/// No onboard animations, no speaker, no head/leg control.
struct BB8LegacyCapabilityProfile: CapabilityProfile {
    
    let profileName = "BB-8 Legacy Capabilities"
    
    let capabilitySet = CapabilitySet(
        hasAnimations: false,
        hasSound: false,
        hasRGBLEDs: true,
        hasSingleLED: true,
        hasHeadPosition: false,
        hasLegActions: false
    )
    
    private let cmdCharUUID = SpheroUUID.legacyCommand
    
    // MARK: - All v2 features unsupported
    
    func encodePlayAnimation(id: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodeStopAnimation(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodeEnableIdleAnimations(enabled: Bool, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodePlaySound(id: UInt16, mode: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodeStopSound(encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodeSetVolume(volume: UInt8, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodeSetHeadPosition(angle: Float, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    func encodePerformLegAction(_ action: R2LegAction, encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? { nil }
    
    // MARK: - LEDs
    
    /// Legacy BB-8 supports two LED targets via v1 protocol:
    /// - Body RGB: mask 0x07 → setRGBLED (CID=0x20), payload [r, g, b]
    /// - Back LED: mask 0x00 → setBackLED (CID=0x21), payload [brightness]
    func encodeSetLEDs(mask: UInt8, values: [UInt8], encoder: inout PacketEncoder) -> (characteristicUUID: CBUUID, data: Data)? {
        if mask == 0x07 && values.count >= 3 {
            // Body RGB via v1 setRGBLED command
            let packet = encoder.encodeV1(
                deviceID: SpheroV1DeviceID.sphero,
                commandID: SpheroV1SpheroCommand.setRGBLED,
                payload: Data([values[0], values[1], values[2]])
            )
            return (cmdCharUUID, packet)
        } else {
            // Back aiming LED via v1 setBackLED command
            let brightness = values.first ?? 0
            let packet = encoder.encodeV1(
                deviceID: SpheroV1DeviceID.sphero,
                commandID: SpheroV1SpheroCommand.setBackLED,
                payload: Data([brightness])
            )
            return (cmdCharUUID, packet)
        }
    }
}

// MARK: - Capability Profile Factory

/// Selects the appropriate capability profile for a droid based on its type
/// and discovered BLE services.
enum CapabilityProfileFactory {
    
    static func profile(for droidType: DroidType, discoveredServices: [DiscoveredService] = []) -> CapabilityProfile {
        switch droidType {
        case .r2d2, .r2q5:
            return RSeriesCapabilityProfile()
        case .bb9e:
            return BB9ECapabilityProfile()
        case .bb8:
            if hasV2APICharacteristic(in: discoveredServices) {
                // V2 BB-8 has limited v2 capabilities but no onboard animations/sounds
                return BB8LegacyCapabilityProfile()
            }
            return BB8LegacyCapabilityProfile()
        case .unknownSphero:
            return BB8LegacyCapabilityProfile()
        }
    }
    
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
