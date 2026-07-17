//
//  PacketEncoder.swift
//  SWSphero
//
//  Encodes command packets for transmission to Sphero droids.
//
//  REVERSE ENGINEERING NOTES:
//
//  Sphero v1 Packet Format (legacy Sphero 2.0, SPRK):
//  ┌──────┬──────┬──────┬──────┬──────┬──────────┬──────────┐
//  │ SOP1 │ SOP2 │ DID  │ CID  │ SEQ  │ DLEN     │ DATA...  │ CHK │
//  │ 0xFF │ 0xFF │      │      │      │          │          │     │
//  └──────┴──────┴──────┴──────┴──────┴──────────┴──────────┘
//  - SOP1: Start of packet 1 (always 0xFF)
//  - SOP2: Start of packet 2 (0xFF = synchronous, 0xFE = asynchronous)
//  - DID:  Device ID (virtual device target)
//  - CID:  Command ID
//  - SEQ:  Sequence number (for response correlation)
//  - DLEN: Data length + 1 (includes checksum byte)
//  - DATA: Payload bytes
//  - CHK:  Checksum (bitwise NOT of sum of bytes from DID through end of DATA)
//
//  Sphero v2 Packet Format (BB-8 and later, "API 2.0"):
//  ┌───────┬───────┬───────┬──────┬──────┬──────┬──────────┬───────┐
//  │ START │ FLAGS │ TID?  │ SID? │ DID  │ CID  │ DATA...  │ END   │
//  │ 0x8D  │       │       │      │      │      │          │ 0xD8  │
//  └───────┴───────┴───────┴──────┴──────┴──────┴──────────┴───────┘
//  - START: 0x8D
//  - FLAGS: Bit field controlling packet behavior
//  - TID:   Target ID (optional, if FLAGS bit set)
//  - SID:   Source ID (optional, if FLAGS bit set)
//  - DID:   Device ID
//  - CID:   Command ID
//  - SEQ:   Sequence number
//  - DATA:  Payload
//  - CHK:   Checksum (sum of all bytes from FLAGS to end of DATA, bitwise NOT, & 0xFF)
//  - END:   0xD8
//
//  Escape sequences in v2:
//  - 0x8D in payload → 0xAB 0x05
//  - 0xD8 in payload → 0xAB 0x03
//  - 0xAB in payload → 0xAB 0x23
//

import Foundation

// MARK: - Packet Encoder

/// Encodes commands into raw byte packets for transmission to Sphero droids.
struct PacketEncoder {
    
    /// Current sequence number, incremented per packet.
    private var sequenceCounter: UInt8 = 0
    
    /// Get and increment the sequence counter.
    mutating func nextSequence() -> UInt8 {
        let seq = sequenceCounter
        sequenceCounter = sequenceCounter &+ 1
        return seq
    }
    
    // MARK: - V1 Encoding
    
    /// Encode a command using the Sphero v1 (legacy) packet format.
    ///
    /// - Parameters:
    ///   - deviceID: Target virtual device ID.
    ///   - commandID: Command identifier.
    ///   - payload: Command payload data (may be empty).
    ///   - resetTimeout: If true, resets the idle timeout on the droid.
    /// - Returns: Complete encoded packet ready for BLE transmission.
    mutating func encodeV1(
        deviceID: UInt8,
        commandID: UInt8,
        payload: Data = Data(),
        resetTimeout: Bool = true
    ) -> Data {
        let seq = nextSequence()
        let dlen = UInt8(payload.count + 1) // +1 for checksum
        
        var packet = Data()
        packet.append(0xFF) // SOP1
        packet.append(resetTimeout ? 0xFF : 0xFE) // SOP2: sync vs async
        packet.append(deviceID)
        packet.append(commandID)
        packet.append(seq)
        packet.append(dlen)
        packet.append(contentsOf: payload)
        
        // Checksum: NOT(sum of DID through DATA) & 0xFF
        let checksumRange = packet[2...] // Everything from DID onward
        let sum = checksumRange.reduce(0) { (acc: UInt32, byte: UInt8) in acc &+ UInt32(byte) }
        let checksum = UInt8(~sum & 0xFF)
        packet.append(checksum)
        
        return packet
    }
    
    // MARK: - V1 Sensor Streaming
    
    /// Encode a V1 setDataStreaming command (DID=0x02, CID=0x11).
    ///
    /// Configures which sensor values to stream and at what rate.
    /// Base sample rate is 400 Hz; actual rate = 400 / divisor.
    ///
    /// - Parameters:
    ///   - divisor: Sample rate divisor. 40 = 10 Hz.
    ///   - frameCount: Frames between each streamed packet. 1 = every frame.
    ///   - mask: 32-bit sensor selection bitmask (see V1SensorMask).
    ///   - packetCount: Number of packets to send. 0 = stream forever.
    /// - Returns: Complete encoded V1 packet.
    mutating func encodeV1SetDataStreaming(
        divisor: UInt16 = 40,
        frameCount: UInt16 = 1,
        mask: UInt32,
        packetCount: UInt8 = 0
    ) -> Data {
        var payload = Data()
        payload.append(UInt8(divisor >> 8))
        payload.append(UInt8(divisor & 0xFF))
        payload.append(UInt8(frameCount >> 8))
        payload.append(UInt8(frameCount & 0xFF))
        payload.append(UInt8((mask >> 24) & 0xFF))
        payload.append(UInt8((mask >> 16) & 0xFF))
        payload.append(UInt8((mask >> 8) & 0xFF))
        payload.append(UInt8(mask & 0xFF))
        payload.append(packetCount)
        
        return encodeV1(
            deviceID: SpheroV1DeviceID.sphero,
            commandID: SpheroV1SpheroCommand.setDataStreaming,
            payload: payload
        )
    }
    
    // MARK: - V2 Encoding
    
    /// Encode a command using the Sphero v2 (API 2.0) packet format.
    ///
    /// - Parameters:
    ///   - flags: Packet flags byte.
    ///   - targetID: Optional target ID (included if flags indicate).
    ///   - sourceID: Optional source ID (included if flags indicate).
    ///   - deviceID: Target virtual device ID.
    ///   - commandID: Command identifier.
    ///   - payload: Command payload data (may be empty).
    /// - Returns: Complete encoded packet with escape sequences applied.
    mutating func encodeV2(
        flags: UInt8 = 0x0A,
        targetID: UInt8? = nil,
        sourceID: UInt8? = nil,
        deviceID: UInt8,
        commandID: UInt8,
        payload: Data = Data()
    ) -> Data {
        let seq = nextSequence()
        
        // Build the inner packet (before escaping)
        var inner = Data()
        inner.append(flags)
        if let tid = targetID { inner.append(tid) }
        if let sid = sourceID { inner.append(sid) }
        inner.append(deviceID)
        inner.append(commandID)
        inner.append(seq)
        inner.append(contentsOf: payload)
        
        // Checksum over inner bytes
        let sum = inner.reduce(0) { (acc: UInt32, byte: UInt8) in acc &+ UInt32(byte) }
        let checksum = UInt8(~sum & 0xFF)
        inner.append(checksum)
        
        // Apply escape sequences
        var escaped = Data()
        escaped.append(0x8D) // START (not escaped)
        for byte in inner {
            switch byte {
            case 0x8D: escaped.append(contentsOf: [0xAB, 0x05])
            case 0xD8: escaped.append(contentsOf: [0xAB, 0x03])
            case 0xAB: escaped.append(contentsOf: [0xAB, 0x23])
            default:   escaped.append(byte)
            }
        }
        escaped.append(0xD8) // END (not escaped)
        
        return escaped
    }
    
    // MARK: - Common Commands
    
    /// Encode the legacy Anti-DoS unlock string ("011i3").
    ///
    /// REVERSE ENGINEERING NOTES:
    /// Used by original BB-8 firmware on characteristic 22BB746F-2BBD-...
    static func antiDoSPayload() -> Data {
        Data("011i3".utf8)
    }
    
    /// Encode the v2 Force Band Anti-DoS unlock string ("usetheforce...band").
    ///
    /// REVERSE ENGINEERING NOTES:
    /// Used by R2-D2, BB-9E, and updated BB-8 firmware on
    /// characteristic 00020005-574F-4F20-5370-6865726F2121
    static func forceBandAntiDoSPayload() -> Data {
        Data("usetheforce...band".utf8)
    }
    
    /// Encode a wake command for the v1 protocol.
    /// Device ID 0x00 (Core), Command ID 0x01 (Ping) is commonly used as wake.
    mutating func encodePing() -> Data {
        encodeV1(deviceID: 0x00, commandID: 0x01)
    }
    
    /// Encode a set TX power command (used during initialization).
    /// Device ID 0x00 (Core), Command ID 0x03.
    mutating func encodeSetTXPower(level: UInt8 = 0x07) -> Data {
        encodeV1(deviceID: 0x00, commandID: 0x03, payload: Data([level]))
    }
    
    // MARK: - IEEE 754 Float Encoding
    
    /// Encode a Float32 as 4 bytes in big-endian IEEE 754 format.
    ///
    /// Used for head position angle commands on R-series droids.
    /// ARM is little-endian natively; Sphero protocol expects big-endian.
    static func encodeFloat32(_ value: Float) -> Data {
        var v = value.bitPattern.bigEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }
}

// MARK: - V1 Device IDs

/// Known device IDs for the v1 protocol.
///
/// REVERSE ENGINEERING NOTES:
/// These are "virtual device" targets within the Sphero firmware.
/// Commands are routed to different subsystems based on DID.
enum SpheroV1DeviceID {
    static let core: UInt8     = 0x00  // Core system (ping, version, sleep, etc.)
    static let sphero: UInt8   = 0x02  // Sphero-specific (drive, LEDs, sensors, etc.)
}

// MARK: - V1 Core Commands

enum SpheroV1CoreCommand {
    static let ping: UInt8           = 0x01
    static let getVersioning: UInt8  = 0x02
    static let setTXPower: UInt8     = 0x03
    static let getPowerState: UInt8  = 0x20
    static let goToSleep: UInt8      = 0x22
    static let setInactivityTimeout: UInt8 = 0x25
}

// MARK: - V1 Sphero Commands

enum SpheroV1SpheroCommand {
    static let setHeading: UInt8     = 0x01
    static let setStabilization: UInt8 = 0x02
    static let setRotationRate: UInt8 = 0x03
    static let setRGBLED: UInt8      = 0x20
    static let setBackLED: UInt8     = 0x21
    static let roll: UInt8           = 0x30
    static let setRawMotors: UInt8   = 0x33
    static let configureCollisionDetection: UInt8 = 0x12
    static let setDataStreaming: UInt8 = 0x11
}

// MARK: - V2 Processor Target IDs

/// Processor node IDs for packet routing on multi-processor droids.
///
/// REVERSE ENGINEERING NOTES:
/// R2-D2 and R2-Q5 have a dual-processor architecture:
/// - Nordic BLE chip (node 0x01): handles BLE, power, audio amplifier
/// - STM32 main processor (node 0x02): handles motors, LEDs, sensors
///
/// Single-processor droids (BB-8) can use packets without TID/SID.
/// Multi-processor droids (R2-D2, R2-Q5, BB-9E) need TID/SID routing
/// for commands that target the STM32 processor.
///
/// When TID/SID are included, the flags byte must have bits 4 and 5 set:
/// flags |= 0x10 (has_target_id) | 0x20 (has_source_id) → flags = 0x3A
enum SpheroV2Processor {
    static let bleChip: UInt8       = 0x11  // Nordic BLE / source "us"
    static let stm32: UInt8         = 0x12  // STM32 main controller
}

// MARK: - V2 Device IDs

/// Known device IDs for the v2 (API 2.0) protocol.
///
/// REVERSE ENGINEERING NOTES:
/// The v2 protocol uses a similar device routing concept but with different IDs.
/// These are derived from community reverse-engineering of BB-8 firmware.
enum SpheroV2DeviceID {
    static let apiProcessor: UInt8   = 0x10
    static let systemInfo: UInt8     = 0x11
    static let powerInfo: UInt8      = 0x13
    static let driving: UInt8        = 0x16
    static let animation: UInt8      = 0x17
    static let sensor: UInt8         = 0x18
    static let userIO: UInt8         = 0x1A  // LEDs, audio, etc.
}

// MARK: - V2 Commands

enum SpheroV2SystemCommand {
    static let getMainAppVersion: UInt8 = 0x00
    static let getBootloaderVersion: UInt8 = 0x01
}

enum SpheroV2PowerCommand {
    static let enterDeepSleep: UInt8  = 0x00
    static let sleep: UInt8           = 0x01
    static let getBatteryVoltage: UInt8 = 0x03
    static let wake: UInt8            = 0x0D
}

enum SpheroV2DrivingCommand {
    static let rawMotors: UInt8       = 0x01
    static let resetYaw: UInt8        = 0x06
    static let driveWithHeading: UInt8 = 0x07
    static let stabilization: UInt8   = 0x0C
}

enum SpheroV2UserIOCommand {
    static let setAllLEDs: UInt8      = 0x0E
    static let playAudioFile: UInt8   = 0x07
    static let setAudioVolume: UInt8  = 0x08
    static let getAudioVolume: UInt8  = 0x09
    static let stopAudio: UInt8       = 0x0A
    static let startIdleLEDAnimation: UInt8 = 0x19  // CID=25
    static let setAllLEDs8BitMask: UInt8    = 0x1C  // CID=28
}

// MARK: - V2 Animatronic Commands

/// Animatronic commands (DID=0x17) for R-series and BB-9E droids.
///
/// REVERSE ENGINEERING NOTES (from spherov2.py animatronic.py):
/// These commands control onboard animations, dome/head rotation,
/// and leg actions on droids with animatronic hardware.
enum SpheroV2AnimatronicCommand {
    static let playAnimation: UInt8        = 0x05  // CID=5
    static let performLegAction: UInt8     = 0x0D  // CID=13
    static let setHeadPosition: UInt8      = 0x0F  // CID=15
    static let getHeadPosition: UInt8      = 0x14  // CID=20
    static let setLegPosition: UInt8       = 0x15  // CID=21
    static let getLegPosition: UInt8       = 0x16  // CID=22
    static let stopAnimation: UInt8        = 0x2B  // CID=43
    static let enableIdleAnimations: UInt8 = 0x2C  // CID=44
    static let enableTrophyMode: UInt8     = 0x2D  // CID=45
}

/// Audio playback modes for the playAudioFile command.
enum SpheroAudioPlaybackMode {
    static let playImmediately: UInt8      = 0x00
    static let playOnlyIfNotPlaying: UInt8 = 0x01
    static let playAfterCurrent: UInt8     = 0x02
}

/// Known audio file IDs for different droid types.
/// These are 16-bit IDs sent as [hi, lo] in the playAudioFile payload.
///
/// REVERSE ENGINEERING NOTES:
/// R2-D2 and R2-Q5 audio IDs are from the spherov2.py reference implementation
/// (spherov2/toy/r2d2.py Audio enum). These are on-device audio file indices
/// stored in the droid's flash memory.
///
/// BB-9E audio IDs are from spherov2/toy/bb9e.py Audio enum.
/// Original BB-8 (legacy v1) does NOT have a speaker.
enum SpheroAudioID {
    // R2-D2 / R2-Q5 sounds (from spherov2.py R2D2.Audio enum)
    static let r2d2Happy: UInt16       = 0x0007  // Short positive chirp
    static let r2d2Sad: UInt16         = 0x000E  // Sad descending tone
    static let r2d2Excited: UInt16     = 0x0003  // Excited warble
    static let r2d2Scan: UInt16        = 0x0009  // Scanning beep
    static let r2d2Chatty: UInt16      = 0x001A  // Chatty sequence
    
    // BB-9E sounds (from spherov2.py BB9E.Audio enum)
    // BB-9E has a speaker and uses v2 playAudioFile
    static let bb9eHappy: UInt16       = 0x0003
    static let bb9eSad: UInt16         = 0x000E
    static let bb9eExcited: UInt16     = 0x0007
    static let bb9eSurprised: UInt16   = 0x0001
    
    // Aliases for BB-series (used by BB-9E; legacy BB-8 has no speaker)
    static let bb8Happy: UInt16        = 0x0003
    static let bb8Sad: UInt16          = 0x000E
    static let bb8Excited: UInt16      = 0x0007
    static let bb8Surprised: UInt16    = 0x0001
    
    // Generic/shared
    static let genericBeep: UInt16     = 0x0001
}
