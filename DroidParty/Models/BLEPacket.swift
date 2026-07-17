//
//  BLEPacket.swift
//  SWSphero
//
//  Represents a raw BLE packet for logging and inspection.
//
//  REVERSE ENGINEERING NOTES:
//  Sphero BLE packets generally follow a structure with:
//  - Start-of-packet marker byte(s)
//  - Flags / device ID / command ID fields
//  - Sequence number for request/response correlation
//  - Data length
//  - Payload
//  - Checksum
//
//  The exact format differs between Sphero v1 (legacy) and v2 (API 2.0) protocols.
//  BB-8 and BB-9E may use a newer v2 variant; R2-D2 and R2-Q5 may differ further.
//  This model captures raw bytes and layers parsed metadata on top.
//

import Foundation

// MARK: - Packet Direction

enum PacketDirection: String, Sendable {
    case tx = "TX"  // Host → Droid
    case rx = "RX"  // Droid → Host
    case notification = "NOTIFY"
    
    var arrow: String {
        switch self {
        case .tx:           return "→"
        case .rx:           return "←"
        case .notification: return "⇐"
        }
    }
}

// MARK: - BLE Packet

/// A captured BLE packet with metadata for logging and analysis.
struct BLEPacket: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let direction: PacketDirection
    let characteristicUUID: String
    let serviceUUID: String?
    let rawData: Data
    let parsedMetadata: PacketMetadata?
    
    init(
        direction: PacketDirection,
        characteristicUUID: String,
        serviceUUID: String? = nil,
        rawData: Data,
        parsedMetadata: PacketMetadata? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.direction = direction
        self.characteristicUUID = characteristicUUID
        self.serviceUUID = serviceUUID
        self.rawData = rawData
        self.parsedMetadata = parsedMetadata
    }
    
    /// Hex string representation of the raw data for display.
    var hexString: String {
        rawData.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    /// Compact hex string without spaces.
    var compactHex: String {
        rawData.map { String(format: "%02X", $0) }.joined()
    }
    
    /// Byte count.
    var byteCount: Int {
        rawData.count
    }
}

// MARK: - Packet Metadata

/// Parsed fields extracted from a raw Sphero packet.
/// Not all fields will be present for every packet — depends on protocol version and parse success.
struct PacketMetadata: Sendable {
    let protocolVersion: SpheroProtocolVersion?
    let deviceID: UInt8?
    let commandID: UInt8?
    let sequenceNumber: UInt8?
    let flags: UInt8?
    let errorCode: UInt8?
    let payload: Data?
    let checksumValid: Bool?
    let description: String?
    /// V1 async notification ID (e.g., 0x0003 = sensor data, 0x0007 = collision).
    let asyncID: UInt16?
    
    init(
        protocolVersion: SpheroProtocolVersion? = nil,
        deviceID: UInt8? = nil,
        commandID: UInt8? = nil,
        sequenceNumber: UInt8? = nil,
        flags: UInt8? = nil,
        errorCode: UInt8? = nil,
        payload: Data? = nil,
        checksumValid: Bool? = nil,
        description: String? = nil,
        asyncID: UInt16? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.deviceID = deviceID
        self.commandID = commandID
        self.sequenceNumber = sequenceNumber
        self.flags = flags
        self.errorCode = errorCode
        self.payload = payload
        self.checksumValid = checksumValid
        self.description = description
        self.asyncID = asyncID
    }
}

// MARK: - Protocol Version

/// Known Sphero BLE protocol versions.
///
/// REVERSE ENGINEERING NOTES:
/// - v1 was used by original Sphero 2.0 and early SPRK editions.
///   Packets start with 0xFF 0xFF (SOP1, SOP2).
/// - v2 ("API 2.0") was introduced with BB-8 and later devices.
///   Packets start with 0x8D and end with 0xD8.
/// - Some devices may support both, or transitional variants.
enum SpheroProtocolVersion: String, Sendable {
    case v1 = "v1"     // Legacy: SOP1=0xFF, SOP2=0xFF/0xFE
    case v2 = "v2"     // API 2.0: Start=0x8D, End=0xD8
    case unknown
}
