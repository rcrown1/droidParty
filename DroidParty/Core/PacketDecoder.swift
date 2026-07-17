//
//  PacketDecoder.swift
//  SWSphero
//
//  Decodes incoming BLE packets from Sphero droids.
//
//  REVERSE ENGINEERING NOTES:
//  See PacketEncoder.swift for packet format documentation.
//  The decoder handles both v1 and v2 formats, auto-detecting based on
//  the first byte of the received data.
//

import Foundation

// MARK: - Decode Result

/// Result of attempting to decode a raw BLE packet.
enum PacketDecodeResult {
    case success(PacketMetadata)
    case incomplete         // Not enough bytes yet (buffering needed)
    case checksumError      // Packet parsed but checksum didn't match
    case unknownFormat      // Doesn't match any known packet structure
}

// MARK: - Packet Decoder

/// Decodes raw bytes received from Sphero droids into structured metadata.
struct PacketDecoder {
    
    /// Accumulated buffer for handling fragmented v2 packets.
    private var v2Buffer: Data = Data()
    
    // MARK: - Auto-Detect and Decode
    
    /// Attempt to decode a raw data payload, auto-detecting the protocol version.
    ///
    /// - Parameter data: Raw bytes received from the droid.
    /// - Returns: Decode result with parsed metadata on success.
    mutating func decode(_ data: Data) -> PacketDecodeResult {
        guard !data.isEmpty else { return .incomplete }
        
        switch data[0] {
        case 0xFF:
            return decodeV1(data)
        case 0x8D:
            return decodeV2(data)
        default:
            // Could be a continuation of a v2 packet, or unknown format
            // Try appending to v2 buffer
            if !v2Buffer.isEmpty {
                v2Buffer.append(data)
                return attemptV2BufferDecode()
            }
            return .unknownFormat
        }
    }
    
    // MARK: - V1 Decoding
    
    /// Decode a Sphero v1 response packet.
    ///
    /// Response format:
    /// ┌──────┬──────┬──────┬──────┬──────────┬──────┐
    /// │ SOP1 │ SOP2 │ MRSP │ SEQ  │ DLEN     │ DATA │ CHK │
    /// │ 0xFF │ 0xFF │      │      │          │      │     │
    /// └──────┴──────┴──────┴──────┴──────────┴──────┘
    /// MRSP = Message Response code (0x00 = OK)
    /// Async format uses SOP2 = 0xFE with different subsequent fields.
    func decodeV1(_ data: Data) -> PacketDecodeResult {
        guard data.count >= 6 else { return .incomplete }
        guard data[0] == 0xFF else { return .unknownFormat }
        
        let sop2 = data[1]
        let isAsync = (sop2 == 0xFE)
        
        if isAsync {
            return decodeV1Async(data)
        }
        
        // Synchronous response
        guard data.count >= 6 else { return .incomplete }
        let mrsp = data[2]   // Message Response code
        let seq = data[3]    // Sequence number echoed back
        let dlen = data[4]   // Data length (includes checksum)
        
        let expectedTotal = 5 + Int(dlen) // SOP1 + SOP2 + MRSP + SEQ + DLEN + (DATA + CHK)
        guard data.count >= expectedTotal else { return .incomplete }
        
        let payloadLength = Int(dlen) - 1
        let payload = payloadLength > 0 ? data[5..<(5 + payloadLength)] : Data()
        let receivedChecksum = data[5 + payloadLength]
        
        // Validate checksum: NOT(sum of MRSP through DATA) & 0xFF
        let checksumBytes = data[2..<(5 + payloadLength)]
        let sum = checksumBytes.reduce(0) { (acc: UInt32, byte: UInt8) in acc &+ UInt32(byte) }
        let expectedChecksum = UInt8(~sum & 0xFF)
        let checksumValid = (receivedChecksum == expectedChecksum)
        
        let metadata = PacketMetadata(
            protocolVersion: .v1,
            commandID: nil,
            sequenceNumber: seq,
            errorCode: mrsp,
            payload: Data(payload),
            checksumValid: checksumValid,
            description: mrsp == 0x00 ? "OK" : "Error (MRSP=0x\(String(format: "%02X", mrsp)))"
        )
        
        return checksumValid ? .success(metadata) : .checksumError
    }
    
    /// Decode a v1 asynchronous notification (SOP2 = 0xFE).
    private func decodeV1Async(_ data: Data) -> PacketDecodeResult {
        guard data.count >= 7 else { return .incomplete }
        
        let idMSB = data[2]
        let idLSB = data[3]
        let dlenMSB = data[4]
        let dlenLSB = data[5]
        let asyncID = (UInt16(idMSB) << 8) | UInt16(idLSB)
        let dlen = (Int(dlenMSB) << 8) | Int(dlenLSB)
        
        let expectedTotal = 6 + dlen
        guard data.count >= expectedTotal else { return .incomplete }
        
        let payloadLength = dlen - 1
        let payload = payloadLength > 0 ? data[6..<(6 + payloadLength)] : Data()
        
        let description: String
        switch asyncID {
        case 0x0003: description = "Sensor Data"
        case 0x0007: description = "Collision Detected"
        case 0x000B: description = "Self Level Complete"
        default:     description = "Async (ID=0x\(String(format: "%04X", asyncID)))"
        }
        
        let metadata = PacketMetadata(
            protocolVersion: .v1,
            flags: data[2],
            payload: Data(payload),
            description: description,
            asyncID: asyncID
        )
        
        return .success(metadata)
    }
    
    // MARK: - V2 Decoding
    
    /// Decode a Sphero v2 (API 2.0) response packet.
    mutating func decodeV2(_ data: Data) -> PacketDecodeResult {
        // If we have a buffered partial packet, append
        if !v2Buffer.isEmpty {
            v2Buffer.append(data)
            return attemptV2BufferDecode()
        }
        
        // Check if this data contains a complete packet (starts with 0x8D, ends with 0xD8)
        guard data.first == 0x8D else { return .unknownFormat }
        
        if let endIndex = data.lastIndex(of: 0xD8), endIndex > 0 {
            return parseV2Packet(data[data.startIndex...endIndex])
        }
        
        // Incomplete — buffer it
        v2Buffer = data
        return .incomplete
    }
    
    /// Try to decode from the accumulated v2 buffer.
    private mutating func attemptV2BufferDecode() -> PacketDecodeResult {
        guard v2Buffer.first == 0x8D else {
            v2Buffer.removeAll()
            return .unknownFormat
        }
        
        if let endIndex = v2Buffer.lastIndex(of: 0xD8), endIndex > 0 {
            let result = parseV2Packet(v2Buffer[v2Buffer.startIndex...endIndex])
            v2Buffer.removeAll()
            return result
        }
        
        // Still incomplete
        if v2Buffer.count > 1024 {
            // Safety: discard if buffer grows too large (likely corrupted)
            v2Buffer.removeAll()
            return .unknownFormat
        }
        return .incomplete
    }
    
    /// Parse a complete v2 packet (from START to END inclusive).
    private func parseV2Packet(_ raw: Data) -> PacketDecodeResult {
        guard raw.count >= 7, raw.first == 0x8D, raw.last == 0xD8 else {
            return .unknownFormat
        }
        
        // Strip START and END markers, then unescape
        let escaped = raw.dropFirst().dropLast()
        let unescaped = unescapeV2(Data(escaped))
        
        guard unescaped.count >= 5 else { return .incomplete }
        
        // Parse unescaped inner packet
        var offset = 0
        let flags = unescaped[offset]; offset += 1
        
        // Flags determine presence of optional target/source IDs
        let hasTargetID = (flags & 0x10) != 0
        let hasSourceID = (flags & 0x20) != 0
        
        var targetID: UInt8?
        var sourceID: UInt8?
        
        if hasTargetID {
            guard offset < unescaped.count else { return .incomplete }
            targetID = unescaped[offset]; offset += 1
        }
        if hasSourceID {
            guard offset < unescaped.count else { return .incomplete }
            sourceID = unescaped[offset]; offset += 1
        }
        
        guard offset + 2 < unescaped.count else { return .incomplete }
        let deviceID = unescaped[offset]; offset += 1
        let commandID = unescaped[offset]; offset += 1
        let seq = unescaped[offset]; offset += 1
        
        // Everything from offset to second-to-last byte is payload
        // Last byte is checksum
        let checksumIndex = unescaped.count - 1
        let payload = offset < checksumIndex ? Data(unescaped[offset..<checksumIndex]) : Data()
        let receivedChecksum = unescaped[checksumIndex]
        
        // Validate checksum: NOT(sum of all bytes except checksum) & 0xFF
        let checksumBytes = unescaped[0..<checksumIndex]
        let sum = checksumBytes.reduce(0) { (acc: UInt32, byte: UInt8) in acc &+ UInt32(byte) }
        let expectedChecksum = UInt8(~sum & 0xFF)
        let checksumValid = (receivedChecksum == expectedChecksum)
        
        var descParts: [String] = []
        descParts.append("DID=0x\(String(format: "%02X", deviceID))")
        descParts.append("CID=0x\(String(format: "%02X", commandID))")
        if let tid = targetID { descParts.append("TID=0x\(String(format: "%02X", tid))") }
        if let sid = sourceID { descParts.append("SID=0x\(String(format: "%02X", sid))") }
        
        let metadata = PacketMetadata(
            protocolVersion: .v2,
            deviceID: deviceID,
            commandID: commandID,
            sequenceNumber: seq,
            flags: flags,
            payload: payload,
            checksumValid: checksumValid,
            description: descParts.joined(separator: ", ")
        )
        
        return checksumValid ? .success(metadata) : .checksumError
    }
    
    // MARK: - V2 Escape Handling
    
    /// Remove escape sequences from v2 packet data.
    ///
    /// Escape rules:
    /// - 0xAB 0x05 → 0x8D
    /// - 0xAB 0x03 → 0xD8
    /// - 0xAB 0x23 → 0xAB
    private func unescapeV2(_ data: Data) -> Data {
        var result = Data()
        result.reserveCapacity(data.count)
        
        var i = 0
        while i < data.count {
            if data[i] == 0xAB, i + 1 < data.count {
                switch data[i + 1] {
                case 0x05: result.append(0x8D); i += 2
                case 0x03: result.append(0xD8); i += 2
                case 0x23: result.append(0xAB); i += 2
                default:   result.append(data[i]); i += 1
                }
            } else {
                result.append(data[i])
                i += 1
            }
        }
        
        return result
    }
}

// MARK: - V1 Response Codes

/// Known message response codes for v1 protocol.
///
/// REVERSE ENGINEERING NOTES:
/// These are documented in the original Sphero SDK and confirmed by community projects.
enum SpheroV1ResponseCode {
    static let ok: UInt8             = 0x00
    static let generalError: UInt8   = 0x01
    static let checksumFail: UInt8   = 0x02
    static let fragmentedCmd: UInt8  = 0x03
    static let unknownCommand: UInt8 = 0x04
    static let unsupported: UInt8    = 0x05
    static let badMessageFormat: UInt8 = 0x06
    static let parameterMissing: UInt8 = 0x07
    static let parameterValue: UInt8 = 0x08
    static let busy: UInt8           = 0x09
    static let badUID: UInt8         = 0x31
    static let badPassword: UInt8    = 0x32
    static let voltsTooLow: UInt8    = 0x33
    static let illegalPage: UInt8    = 0x34
    static let flashFail: UInt8      = 0x35
    static let mainAppCorrupt: UInt8 = 0x36
    static let timeout: UInt8        = 0x37
    
    static func description(for code: UInt8) -> String {
        switch code {
        case ok:              return "OK"
        case generalError:    return "General Error"
        case checksumFail:    return "Checksum Failure"
        case unknownCommand:  return "Unknown Command"
        case unsupported:     return "Unsupported"
        case busy:            return "Busy"
        case voltsTooLow:     return "Voltage Too Low"
        case timeout:         return "Timeout"
        default:              return "Error 0x\(String(format: "%02X", code))"
        }
    }
}
