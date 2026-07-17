//
//  ConnectionState.swift
//  SWSphero
//
//  BLE connection lifecycle states.
//

import Foundation

/// Represents the full lifecycle of a BLE connection to a Sphero droid.
enum ConnectionState: Equatable, Sendable {
    case disconnected
    case scanning
    case connecting
    case discovering         // Connected, discovering services/characteristics
    case handshaking         // Services discovered, performing wake/init handshake
    case ready               // Fully connected and initialized — ready for commands
    case disconnecting
    case error(String)
    
    var isConnected: Bool {
        switch self {
        case .discovering, .handshaking, .ready:
            return true
        default:
            return false
        }
    }
    
    var isTerminal: Bool {
        switch self {
        case .disconnected, .error:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .disconnected:   return "Disconnected"
        case .scanning:       return "Scanning"
        case .connecting:     return "Connecting"
        case .discovering:    return "Discovering Services"
        case .handshaking:    return "Initializing"
        case .ready:          return "Ready"
        case .disconnecting:  return "Disconnecting"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var iconName: String {
        switch self {
        case .disconnected:  return "circle"
        case .scanning:      return "antenna.radiowaves.left.and.right"
        case .connecting:    return "arrow.triangle.2.circlepath"
        case .discovering:   return "magnifyingglass"
        case .handshaking:   return "hand.wave"
        case .ready:         return "checkmark.circle.fill"
        case .disconnecting: return "xmark.circle"
        case .error:         return "exclamationmark.triangle.fill"
        }
    }
}
