//
//  DroidProtocol.swift
//  SWSphero
//
//  Defines the protocol abstraction layer that separates BLE transport from
//  droid-family-specific protocol logic.
//
//  REVERSE ENGINEERING NOTES (confirmed from spherov2.js and spherov2.py):
//
//  Correct V2 initialization sequence:
//  1. Connect to peripheral, discover services and characteristics
//  2. Write "usetheforce...band" to 00020005 (anti-DoS) — with response
//  3. Subscribe to 00020002 (DFU control) for notifications
//  4. Subscribe to 00010002 (API v2) for notifications
//  5. Wait for first notification on 00010002 (handshake confirmation)
//  6. Send wake command: v2 packet with DID=0x13, CID=0x0D on 00010002
//
//  Key insight: 00010002 is used for BOTH sending commands AND receiving
//  responses. The 00020002 characteristic is for DFU control, not API responses.
//
//  Drive commands use v2 driveWithHeading (DID=0x16, CID=0x07).
//  Sound commands use v2 playAudioFile (DID=0x1A, CID=0x07).
//

import Foundation
import CoreBluetooth

// MARK: - Droid Protocol

/// Defines the interface for droid-family-specific BLE protocol behavior.
/// Each droid family (BB-series, R-series) provides its own implementation.
protocol DroidProtocol: Sendable {
    
    /// The droid family this protocol handles.
    var family: DroidFamily { get }
    
    /// Expected primary service UUID for this droid family.
    /// Used to filter during scanning if desired.
    var primaryServiceUUID: CBUUID? { get }
    
    /// All service UUIDs that should be discovered for full functionality.
    var serviceUUIDs: [CBUUID] { get }
    
    /// The characteristic UUID used for sending commands to the droid.
    var commandCharacteristicUUID: CBUUID? { get }
    
    /// The characteristic UUID used for receiving responses from the droid.
    var responseCharacteristicUUID: CBUUID? { get }
    
    /// The characteristic UUID for the anti-DoS handshake.
    var antiDoSCharacteristicUUID: CBUUID? { get }
    
    /// Generate the handshake sequence to wake and initialize the droid.
    ///
    /// Returns an ordered list of (characteristicUUID, data) pairs to write.
    /// The BLE manager will execute these sequentially, waiting for each write
    /// to complete before proceeding. Steps targeting missing characteristics
    /// are silently skipped.
    func handshakeSequence() -> [(characteristicUUID: CBUUID, data: Data)]
    
    /// Generate a keepalive packet to prevent the droid from sleeping.
    func keepalivePacket() -> (characteristicUUID: CBUUID, data: Data)?
    
    /// Recommended keepalive interval in seconds.
    var keepaliveInterval: TimeInterval { get }
    
    /// Attempt to parse incoming data from the droid.
    func parseResponse(_ data: Data) -> PacketDecodeResult
    
    /// Encode a raw command for transmission.
    func encodeCommand(deviceID: UInt8, commandID: UInt8, payload: Data) -> Data
}

// MARK: - Shared Sphero UUID Constants

/// BLE UUIDs shared across all Sphero Star Wars droids.
///
/// REVERSE ENGINEERING NOTES:
/// There are two generations of BLE services:
/// - Legacy (original BB-8): 22BB746F-xxxx-7554-2D6F-726568705327
/// - V2 API (R2-D2, BB-9E, updated BB-8): 0001xxxx/0002xxxx-574F-4F20-5370-6865726F2121
///
/// Both may be present on the same droid. We try both during handshake and use
/// whichever the droid exposes.
enum SpheroUUID {
    // --- Legacy (v1) service & characteristics ---
    static let legacyBLEService          = CBUUID(string: "22BB746F-2BB0-7554-2D6F-726568705327")
    static let legacyRobotControlService = CBUUID(string: "22BB746F-2BA0-7554-2D6F-726568705327")
    static let legacyAntiDoS             = CBUUID(string: "22BB746F-2BBD-7554-2D6F-726568705327")
    static let legacyCommand             = CBUUID(string: "22BB746F-2BA1-7554-2D6F-726568705327")
    static let legacyResponse            = CBUUID(string: "22BB746F-2BA6-7554-2D6F-726568705327")
    static let legacyTXPower             = CBUUID(string: "22BB746F-2BB2-7554-2D6F-726568705327")
    static let legacyWakeCPU             = CBUUID(string: "22BB746F-2BBF-7554-2D6F-726568705327")
    
    // --- V2 API service & characteristics ---
    static let v2APIService              = CBUUID(string: "00010001-574F-4F20-5370-6865726F2121")
    static let v2APICommand              = CBUUID(string: "00010002-574F-4F20-5370-6865726F2121")
    
    // --- V2 Connect/DFU service & characteristics ---
    static let v2ConnectService          = CBUUID(string: "00020001-574F-4F20-5370-6865726F2121")
    static let v2DFUControl              = CBUUID(string: "00020002-574F-4F20-5370-6865726F2121")
    static let v2Subscription            = CBUUID(string: "00020003-574F-4F20-5370-6865726F2121")
    static let v2DFUInfo                 = CBUUID(string: "00020004-574F-4F20-5370-6865726F2121")
    static let v2ForceBandAntiDoS        = CBUUID(string: "00020005-574F-4F20-5370-6865726F2121")
}

// MARK: - BB-Series Protocol

/// Protocol implementation for BB-8 and BB-9E.
///
/// Confirmed initialization sequence (from spherov2.js core.ts start()):
/// 1. Write "usetheforce...band" to 00020005 (with response)
/// 2. Subscribe to 00020002 (DFU control) for notifications
/// 3. Subscribe to 00010002 (API v2) for notifications
/// 4. Wait for first notification on 00010002
/// 5. Send wake command (DID=0x13, CID=0x0D) on 00010002
///
/// Steps 2-5 are handled by BLEManager.performHandshake().
/// The handshakeSequence() only returns the write operations (step 1).
final class BBSeriesProtocol: DroidProtocol, @unchecked Sendable {
    
    let family: DroidFamily = .bbSeries
    
    // MARK: - Service UUIDs
    
    lazy var primaryServiceUUID: CBUUID? = SpheroUUID.v2ConnectService
    
    lazy var serviceUUIDs: [CBUUID] = [
        SpheroUUID.v2APIService,
        SpheroUUID.v2ConnectService,
        SpheroUUID.legacyBLEService,
        SpheroUUID.legacyRobotControlService,
    ]
    
    // MARK: - Characteristic UUIDs
    //
    // Both commands AND responses use 00010002 (API v2 characteristic).
    // Confirmed by spherov2.js: apiV2Characteristic = '00010002-...'
    // Confirmed by spherov2.py: _response_uuid = _send_uuid = '00010002-...'
    
    lazy var antiDoSCharacteristicUUID: CBUUID? = SpheroUUID.v2ForceBandAntiDoS
    lazy var commandCharacteristicUUID: CBUUID? = SpheroUUID.v2APICommand
    lazy var responseCharacteristicUUID: CBUUID? = SpheroUUID.v2APICommand
    
    // MARK: - Handshake
    
    func handshakeSequence() -> [(characteristicUUID: CBUUID, data: Data)] {
        // Only the anti-DoS write. Notification subscriptions and wake command
        // are handled separately by BLEManager.performHandshake().
        var steps: [(characteristicUUID: CBUUID, data: Data)] = []
        
        // V2 anti-DoS ("usetheforce...band") — required for all Star Wars droids
        steps.append((SpheroUUID.v2ForceBandAntiDoS, PacketEncoder.forceBandAntiDoSPayload()))
        
        // Legacy anti-DoS ("011i3") — fallback for original BB-8 firmware
        steps.append((SpheroUUID.legacyAntiDoS, PacketEncoder.antiDoSPayload()))
        
        // Legacy TX Power (skipped if not present on v2-only droids)
        steps.append((SpheroUUID.legacyTXPower, Data([0x07])))
        
        // Legacy Wake CPU (skipped if not present on v2-only droids)
        steps.append((SpheroUUID.legacyWakeCPU, Data([0x01])))
        
        return steps
    }
    
    // MARK: - Keepalive
    
    func keepalivePacket() -> (characteristicUUID: CBUUID, data: Data)? {
        // V2 ping on the API command characteristic
        var encoder = PacketEncoder()
        let ping = encoder.encodeV2(
            deviceID: SpheroV1DeviceID.core,
            commandID: SpheroV1CoreCommand.ping
        )
        return (SpheroUUID.v2APICommand, ping)
    }
    
    let keepaliveInterval: TimeInterval = 10.0
    
    // MARK: - Packet Handling
    
    func parseResponse(_ data: Data) -> PacketDecodeResult {
        var decoder = PacketDecoder()
        return decoder.decode(data)
    }
    
    func encodeCommand(deviceID: UInt8, commandID: UInt8, payload: Data) -> Data {
        var encoder = PacketEncoder()
        return encoder.encodeV2(deviceID: deviceID, commandID: commandID, payload: payload)
    }
}

// MARK: - R-Series Protocol

/// Protocol implementation for R2-D2 and R2-Q5.
///
/// Same v2 initialization sequence as BB-series (confirmed by spherov2.js).
/// R-series has additional capabilities: dome rotation, stance control, waddle, speaker.
final class RSeriesProtocol: DroidProtocol, @unchecked Sendable {
    
    let family: DroidFamily = .rSeries
    
    // MARK: - Service UUIDs
    
    lazy var primaryServiceUUID: CBUUID? = SpheroUUID.v2ConnectService
    
    lazy var serviceUUIDs: [CBUUID] = [
        SpheroUUID.v2APIService,
        SpheroUUID.v2ConnectService,
        SpheroUUID.legacyBLEService,
        SpheroUUID.legacyRobotControlService,
    ]
    
    // MARK: - Characteristic UUIDs
    
    lazy var antiDoSCharacteristicUUID: CBUUID? = SpheroUUID.v2ForceBandAntiDoS
    lazy var commandCharacteristicUUID: CBUUID? = SpheroUUID.v2APICommand
    lazy var responseCharacteristicUUID: CBUUID? = SpheroUUID.v2APICommand
    
    // MARK: - Handshake
    
    func handshakeSequence() -> [(characteristicUUID: CBUUID, data: Data)] {
        var steps: [(characteristicUUID: CBUUID, data: Data)] = []
        
        // V2 anti-DoS ("usetheforce...band") — required
        steps.append((SpheroUUID.v2ForceBandAntiDoS, PacketEncoder.forceBandAntiDoSPayload()))
        
        // Legacy anti-DoS fallback
        steps.append((SpheroUUID.legacyAntiDoS, PacketEncoder.antiDoSPayload()))
        
        // Legacy TX power
        steps.append((SpheroUUID.legacyTXPower, Data([0x07])))
        
        // Legacy wake CPU
        steps.append((SpheroUUID.legacyWakeCPU, Data([0x01])))
        
        return steps
    }
    
    // MARK: - Keepalive
    
    func keepalivePacket() -> (characteristicUUID: CBUUID, data: Data)? {
        var encoder = PacketEncoder()
        let ping = encoder.encodeV2(
            deviceID: SpheroV1DeviceID.core,
            commandID: SpheroV1CoreCommand.ping
        )
        return (SpheroUUID.v2APICommand, ping)
    }
    
    let keepaliveInterval: TimeInterval = 10.0
    
    // MARK: - Packet Handling
    
    func parseResponse(_ data: Data) -> PacketDecodeResult {
        var decoder = PacketDecoder()
        return decoder.decode(data)
    }
    
    func encodeCommand(deviceID: UInt8, commandID: UInt8, payload: Data) -> Data {
        var encoder = PacketEncoder()
        return encoder.encodeV2(deviceID: deviceID, commandID: commandID, payload: payload)
    }
}
