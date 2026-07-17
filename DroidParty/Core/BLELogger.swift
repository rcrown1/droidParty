//
//  BLELogger.swift
//  SWSphero
//
//  Structured logging subsystem for BLE events, packets, and diagnostics.
//  Designed for real-time UI display and future export support.
//

import Foundation
import Combine
import os.log

// MARK: - Log Entry

/// A single log entry capturing a BLE event or packet.
struct BLELogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let packet: BLEPacket?
    let metadata: [String: String]
    
    init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        packet: BLEPacket? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.packet = packet
        self.metadata = metadata
    }
    
    /// Formatted timestamp for display.
    var formattedTimestamp: String {
        Self.timestampFormatter.string(from: timestamp)
    }
    
    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    /// Single-line summary for log views.
    var summary: String {
        var parts: [String] = [formattedTimestamp, "[\(level.symbol)]", "[\(category.rawValue)]"]
        if let pkt = packet {
            parts.append(pkt.direction.arrow)
            parts.append("(\(pkt.byteCount)B)")
        }
        parts.append(message)
        return parts.joined(separator: " ")
    }
    
    /// Multi-line detail string including hex dump.
    var detailDescription: String {
        var lines = [summary]
        if let pkt = packet {
            lines.append("  Characteristic: \(pkt.characteristicUUID)")
            if let svc = pkt.serviceUUID {
                lines.append("  Service: \(svc)")
            }
            lines.append("  Hex: \(pkt.hexString)")
            if let meta = pkt.parsedMetadata {
                if let desc = meta.description {
                    lines.append("  Parsed: \(desc)")
                }
                if let cmd = meta.commandID {
                    lines.append("  Command: 0x\(String(format: "%02X", cmd))")
                }
                if let seq = meta.sequenceNumber {
                    lines.append("  Seq: \(seq)")
                }
            }
        }
        for (key, value) in metadata {
            lines.append("  \(key): \(value)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Log Level

enum LogLevel: Int, Comparable, Sendable {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    
    var symbol: String {
        switch self {
        case .trace:   return "T"
        case .debug:   return "D"
        case .info:    return "I"
        case .warning: return "W"
        case .error:   return "E"
        }
    }
    
    var displayName: String {
        switch self {
        case .trace:   return "Trace"
        case .debug:   return "Debug"
        case .info:    return "Info"
        case .warning: return "Warning"
        case .error:   return "Error"
        }
    }
    
    var color: String {
        switch self {
        case .trace:   return "gray"
        case .debug:   return "blue"
        case .info:    return "green"
        case .warning: return "orange"
        case .error:   return "red"
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Category

enum LogCategory: String, CaseIterable, Sendable {
    case scan        = "SCAN"
    case connect     = "CONN"
    case service     = "SVC"
    case packet      = "PKT"
    case protocol_   = "PROTO"
    case keepalive   = "KEEP"
    case handshake   = "HAND"
    case error       = "ERR"
    case system      = "SYS"
    case drive       = "DRIVE"
    case calibration = "CAL"
    case safety      = "SAFE"
    case capability  = "CAP"
    case sensor      = "SENS"
}

// MARK: - BLE Logger

/// Thread-safe logging subsystem that stores entries for UI display and system log output.
@MainActor
final class BLELogger: ObservableObject {
    static let shared = BLELogger()
    
    /// All log entries, newest last.
    @Published private(set) var entries: [BLELogEntry] = []
    
    /// Maximum number of entries to retain in memory.
    var maxEntries: Int = 5000
    
    /// Minimum level to capture (entries below this level are discarded).
    var minimumLevel: LogLevel = .trace
    
    /// OS unified logger for system-level output.
    private let osLog = Logger(subsystem: "com.swsphero.ble", category: "BLE")
    
    private init() {}
    
    // MARK: - Logging Methods
    
    func log(
        _ level: LogLevel,
        category: LogCategory,
        message: String,
        packet: BLEPacket? = nil,
        metadata: [String: String] = [:]
    ) {
        guard level >= minimumLevel else { return }
        
        let entry = BLELogEntry(
            level: level,
            category: category,
            message: message,
            packet: packet,
            metadata: metadata
        )
        
        entries.append(entry)
        
        // Trim old entries
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        
        // Also emit to OS unified log
        let osMessage = entry.summary
        switch level {
        case .trace, .debug:
            osLog.debug("\(osMessage, privacy: .public)")
        case .info:
            osLog.info("\(osMessage, privacy: .public)")
        case .warning:
            osLog.warning("\(osMessage, privacy: .public)")
        case .error:
            osLog.error("\(osMessage, privacy: .public)")
        }
    }
    
    // MARK: - Convenience Methods
    
    func trace(_ category: LogCategory, _ message: String, metadata: [String: String] = [:]) {
        log(.trace, category: category, message: message, metadata: metadata)
    }
    
    func debug(_ category: LogCategory, _ message: String, metadata: [String: String] = [:]) {
        log(.debug, category: category, message: message, metadata: metadata)
    }
    
    func info(_ category: LogCategory, _ message: String, metadata: [String: String] = [:]) {
        log(.info, category: category, message: message, metadata: metadata)
    }
    
    func warning(_ category: LogCategory, _ message: String, metadata: [String: String] = [:]) {
        log(.warning, category: category, message: message, metadata: metadata)
    }
    
    func error(_ category: LogCategory, _ message: String, metadata: [String: String] = [:]) {
        log(.error, category: category, message: message, metadata: metadata)
    }
    
    func logPacket(_ packet: BLEPacket, message: String = "") {
        let msg = message.isEmpty
            ? "\(packet.direction.rawValue) \(packet.byteCount)B on \(packet.characteristicUUID)"
            : message
        log(.debug, category: .packet, message: msg, packet: packet)
    }
    
    // MARK: - Management
    
    func clear() {
        entries.removeAll()
    }
    
    /// Export all entries as a plain text string suitable for sharing.
    func exportAsText() -> String {
        entries.map { $0.detailDescription }.joined(separator: "\n\n")
    }
    
    /// Filtered entries by level and/or category.
    func filteredEntries(
        minLevel: LogLevel = .trace,
        categories: Set<LogCategory>? = nil
    ) -> [BLELogEntry] {
        entries.filter { entry in
            entry.level >= minLevel &&
            (categories == nil || categories!.contains(entry.category))
        }
    }
}
