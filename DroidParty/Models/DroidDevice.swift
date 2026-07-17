//
//  DroidDevice.swift
//  SWSphero
//
//  Represents a discovered or connected Sphero droid peripheral.
//

import Foundation
import CoreBluetooth

// MARK: - Discovered Service

/// A BLE service discovered on a connected droid.
struct DiscoveredService: Identifiable, Sendable {
    let id: String  // UUID string
    let uuid: String
    let name: String?
    let characteristics: [DiscoveredCharacteristic]
    
    /// Human-readable label for known Sphero services.
    var displayName: String {
        if let name = name { return name }
        return SpheroServiceIdentifier.name(for: uuid) ?? uuid
    }
}

// MARK: - Discovered Characteristic

/// A BLE characteristic discovered within a service.
struct DiscoveredCharacteristic: Identifiable, Sendable {
    let id: String  // UUID string
    let uuid: String
    let name: String?
    let properties: CharacteristicProperties
    let isNotifying: Bool
    
    var displayName: String {
        if let name = name { return name }
        return SpheroCharacteristicIdentifier.name(for: uuid) ?? uuid
    }
}

// MARK: - Characteristic Properties

/// Decoded CBCharacteristicProperties for display without importing CoreBluetooth in views.
struct CharacteristicProperties: OptionSet, Sendable {
    let rawValue: UInt
    
    static let read                = CharacteristicProperties(rawValue: 1 << 0)
    static let write               = CharacteristicProperties(rawValue: 1 << 1)
    static let writeWithoutResponse = CharacteristicProperties(rawValue: 1 << 2)
    static let notify              = CharacteristicProperties(rawValue: 1 << 3)
    static let indicate            = CharacteristicProperties(rawValue: 1 << 4)
    
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    init(cbProperties: CBCharacteristicProperties) {
        var value: UInt = 0
        if cbProperties.contains(.read)                 { value |= CharacteristicProperties.read.rawValue }
        if cbProperties.contains(.write)                { value |= CharacteristicProperties.write.rawValue }
        if cbProperties.contains(.writeWithoutResponse) { value |= CharacteristicProperties.writeWithoutResponse.rawValue }
        if cbProperties.contains(.notify)               { value |= CharacteristicProperties.notify.rawValue }
        if cbProperties.contains(.indicate)             { value |= CharacteristicProperties.indicate.rawValue }
        self.rawValue = value
    }
    
    var labels: [String] {
        var result: [String] = []
        if contains(.read)                 { result.append("Read") }
        if contains(.write)               { result.append("Write") }
        if contains(.writeWithoutResponse) { result.append("WriteNoResp") }
        if contains(.notify)              { result.append("Notify") }
        if contains(.indicate)            { result.append("Indicate") }
        return result
    }
}

// MARK: - Droid Device

/// A discovered or connected Sphero droid.
/// This is the primary model passed between the BLE layer and ViewModels.
struct DroidDevice: Identifiable, Sendable {
    let id: UUID                           // CBPeripheral identifier
    let peripheralName: String?            // Advertised local name
    let droidType: DroidType               // Classified droid model
    var rssi: Int                           // Last known RSSI
    var connectionState: ConnectionState    // Current connection lifecycle state
    var discoveredServices: [DiscoveredService]  // Services found after connection
    var lastSeen: Date                      // Last advertisement or interaction timestamp
    
    /// Manufacturer data captured from the advertisement, if any.
    var manufacturerData: Data?
    
    /// Advertised service UUIDs captured from the scan.
    var advertisedServiceUUIDs: [String]?
    
    init(
        id: UUID,
        peripheralName: String?,
        droidType: DroidType,
        rssi: Int = -100,
        connectionState: ConnectionState = .disconnected,
        discoveredServices: [DiscoveredService] = [],
        lastSeen: Date = Date(),
        manufacturerData: Data? = nil,
        advertisedServiceUUIDs: [String]? = nil
    ) {
        self.id = id
        self.peripheralName = peripheralName
        self.droidType = droidType
        self.rssi = rssi
        self.connectionState = connectionState
        self.discoveredServices = discoveredServices
        self.lastSeen = lastSeen
        self.manufacturerData = manufacturerData
        self.advertisedServiceUUIDs = advertisedServiceUUIDs
    }
    
    /// Best display name: advertised name, droid type name, or truncated UUID.
    var displayName: String {
        if let name = peripheralName, !name.isEmpty {
            return name
        }
        if droidType != .unknownSphero {
            return droidType.displayName
        }
        return "Sphero (\(id.uuidString.prefix(8)))"
    }
    
    /// Signal strength description.
    var signalDescription: String {
        switch rssi {
        case -50...0:     return "Excellent"
        case -65...(-51): return "Good"
        case -80...(-66): return "Fair"
        default:          return "Weak"
        }
    }
}

// MARK: - Known Sphero BLE Service Identifiers

/// Maps known Sphero service UUIDs to human-readable names.
///
/// REVERSE ENGINEERING NOTES:
/// These UUIDs are derived from public reverse-engineering efforts (cylon-sphero-ble,
/// community documentation). They may vary across firmware versions.
enum SpheroServiceIdentifier {
    
    /// Known Sphero BLE service UUIDs mapped to descriptive names.
    static let knownServices: [String: String] = [
        // Sphero BLE Service (legacy, used for anti-DoS handshake)
        "22BB746F-2BB0-7554-2D6F-726568705327": "Sphero BLE Service",
        // Robot Control Service (commands and responses)
        "22BB746F-2BA0-7554-2D6F-726568705327": "Robot Control Service",
        // Sphero v2 API Service (newer firmware, BB-8 onwards)
        "00010001-574F-4F20-5370-6865726F2121": "Sphero API v2 Service",
        // Sphero v2 Connect Service (anti-DoS, handshake)
        "00020001-574F-4F20-5370-6865726F2121": "Sphero v2 Connect Service",
        // Device Information Service (standard BLE)
        "0000180A-0000-1000-8000-00805F9B34FB": "Device Information",
    ]
    
    static func name(for uuid: String) -> String? {
        // Try exact match first, then case-insensitive
        if let name = knownServices[uuid] { return name }
        let upper = uuid.uppercased()
        return knownServices.first(where: { $0.key.uppercased() == upper })?.value
    }
}

// MARK: - Known Sphero BLE Characteristic Identifiers

/// Maps known Sphero characteristic UUIDs to human-readable names.
enum SpheroCharacteristicIdentifier {
    
    static let knownCharacteristics: [String: String] = [
        // Anti-DoS characteristic — write the unlock string here to wake the droid
        "22BB746F-2BBD-7554-2D6F-726568705327": "Anti-DoS",
        // TX Power characteristic
        "22BB746F-2BB2-7554-2D6F-726568705327": "TX Power",
        // Wake CPU characteristic — write to wake from deep sleep
        "22BB746F-2BBF-7554-2D6F-726568705327": "Wake CPU",
        // Command characteristic — send commands here
        "22BB746F-2BA1-7554-2D6F-726568705327": "Commands (TX)",
        // Response characteristic — subscribe for notifications
        "22BB746F-2BA6-7554-2D6F-726568705327": "Response (RX)",
        // Sphero v2 API Characteristics (newer firmware)
        // Note: 00010002 is used for BOTH commands and responses (confirmed by spherov2.py)
        "00010002-574F-4F20-5370-6865726F2121": "API v2 Commands/Response",
        "00010003-574F-4F20-5370-6865726F2121": "API v2 (Alt Response)",
        // Sphero v2 Connect Service Characteristics
        "00020002-574F-4F20-5370-6865726F2121": "DFU Control",
        "00020005-574F-4F20-5370-6865726F2121": "Force Band Anti-DoS",
    ]
    
    static func name(for uuid: String) -> String? {
        if let name = knownCharacteristics[uuid] { return name }
        let upper = uuid.uppercased()
        return knownCharacteristics.first(where: { $0.key.uppercased() == upper })?.value
    }
}
