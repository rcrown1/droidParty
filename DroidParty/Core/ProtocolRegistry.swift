//
//  ProtocolRegistry.swift
//  SWSphero
//
//  Central registry that maps droid types/families to their protocol implementations.
//  Also provides a flexible packet parser registry for protocol exploration.
//

import Foundation

// MARK: - Protocol Registry

/// Maps droid types and families to protocol implementations.
/// Singleton — protocol implementations are stateless reference types.
final class ProtocolRegistry: @unchecked Sendable {
    
    static let shared = ProtocolRegistry()
    
    private let bbProtocol = BBSeriesProtocol()
    private let rSeriesProtocol = RSeriesProtocol()
    
    /// Registered custom packet parsers for protocol exploration.
    private var customParsers: [String: PacketParserEntry] = [:]
    
    private init() {}
    
    // MARK: - Protocol Lookup
    
    /// Get the protocol implementation for a specific droid type.
    func protocolFor(droidType: DroidType) -> DroidProtocol {
        protocolFor(family: droidType.family)
    }
    
    /// Get the protocol implementation for a droid family.
    func protocolFor(family: DroidFamily) -> DroidProtocol {
        switch family {
        case .bbSeries: return bbProtocol
        case .rSeries:  return rSeriesProtocol
        case .unknown:   return bbProtocol // Fallback to BB-series as default
        }
    }
    
    // MARK: - Custom Packet Parser Registry
    
    /// Register a custom parser for protocol exploration.
    ///
    /// This allows dynamically adding parsers as protocol understanding improves,
    /// without modifying the core protocol implementations.
    ///
    /// - Parameters:
    ///   - name: Unique name for this parser.
    ///   - description: Human-readable description.
    ///   - parser: Closure that attempts to parse raw data into metadata.
    func registerParser(
        name: String,
        description: String,
        parser: @escaping @Sendable (Data) -> PacketMetadata?
    ) {
        customParsers[name] = PacketParserEntry(
            name: name,
            description: description,
            parser: parser
        )
    }
    
    /// Remove a custom parser.
    func unregisterParser(name: String) {
        customParsers.removeValue(forKey: name)
    }
    
    /// List all registered custom parsers.
    var registeredParsers: [PacketParserEntry] {
        Array(customParsers.values)
    }
    
    /// Attempt to parse data using all registered custom parsers.
    /// Returns the first successful parse result, or nil.
    func parseWithCustomParsers(_ data: Data) -> (parserName: String, metadata: PacketMetadata)? {
        for (name, entry) in customParsers {
            if let metadata = entry.parser(data) {
                return (name, metadata)
            }
        }
        return nil
    }
}

// MARK: - Packet Parser Entry

/// A registered custom packet parser.
struct PacketParserEntry: Sendable {
    let name: String
    let description: String
    let parser: @Sendable (Data) -> PacketMetadata?
}

// MARK: - Capability Probe

/// Framework for probing a connected droid to discover its actual capabilities.
///
/// This is used during the post-handshake phase to understand what a droid supports,
/// rather than relying solely on the droid type classification.
struct CapabilityProbe {
    
    /// A single probe operation: send a command and interpret the response.
    struct ProbeStep: Sendable {
        let name: String
        let description: String
        let command: Data
        let characteristicUUID: String
        let interpreter: @Sendable (Data?) -> ProbeResult
    }
    
    /// Result of a capability probe.
    enum ProbeResult: Sendable {
        case supported(details: String)
        case notSupported
        case unknown(reason: String)
    }
    
    /// Generate a standard set of probe steps for a given droid family.
    ///
    /// REVERSE ENGINEERING NOTES:
    /// Probing involves sending known commands and observing responses.
    /// - A response with MRSP=0x00 indicates the command is supported.
    /// - A response with MRSP=0x04 (unknown command) means it's not.
    /// - No response within timeout means the characteristic might not exist.
    static func standardProbes(for family: DroidFamily) -> [ProbeStep] {
        var encoder = PacketEncoder()
        var probes: [ProbeStep] = []
        
        let cmdCharUUID = "22BB746F-2BA1-7554-2D6F-726568705327"
        
        // Probe 1: Ping (should always work)
        probes.append(ProbeStep(
            name: "Ping",
            description: "Basic connectivity test",
            command: encoder.encodeV1(deviceID: 0x00, commandID: 0x01),
            characteristicUUID: cmdCharUUID,
            interpreter: { data in
                guard let data = data, !data.isEmpty else { return .unknown(reason: "No response") }
                return .supported(details: "Device responded to ping")
            }
        ))
        
        // Probe 2: Get version info
        probes.append(ProbeStep(
            name: "Version Info",
            description: "Query firmware version",
            command: encoder.encodeV1(deviceID: 0x00, commandID: 0x02),
            characteristicUUID: cmdCharUUID,
            interpreter: { data in
                guard let data = data, data.count >= 6 else { return .unknown(reason: "No/short response") }
                return .supported(details: "Firmware data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
        ))
        
        return probes
    }
}
