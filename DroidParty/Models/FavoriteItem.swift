//
//  FavoriteItem.swift
//  SWSphero
//
//  Model for a user-favorited sound, animation, or sequence
//  that can be triggered from the Operate screen.
//

import Foundation

// MARK: - Favorite Item Kind

enum FavoriteItemKind: String, Codable, Sendable {
    case sound
    case animation
    case sequence
}

// MARK: - Favorite Item

struct FavoriteItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let kind: FavoriteItemKind
    let name: String
    let category: String
    /// Sound ID (UInt16) or Animation ID (stored as UInt16).
    let numericID: UInt16
    /// For sequences only — matches CapabilitySequence.id.
    let sequenceID: String?
    /// Which droid types this item works with.
    let compatibleDroidTypes: Set<DroidType>
    
    // MARK: - Display Helpers
    
    var iconName: String {
        switch kind {
        case .sound:     return "speaker.wave.2.fill"
        case .animation: return "sparkles"
        case .sequence:  return "list.bullet.rectangle"
        }
    }
    
    // MARK: - Convenience Inits
    
    init(sound: SoundDescriptor, category: String, compatibleDroidTypes: Set<DroidType>) {
        self.id = UUID()
        self.kind = .sound
        self.name = sound.name
        self.category = category
        self.numericID = sound.id
        self.sequenceID = nil
        self.compatibleDroidTypes = compatibleDroidTypes
    }
    
    init(animation: AnimationDescriptor, compatibleDroidTypes: Set<DroidType>) {
        self.id = UUID()
        self.kind = .animation
        self.name = animation.name
        self.category = animation.category
        self.numericID = UInt16(animation.id)
        self.sequenceID = nil
        self.compatibleDroidTypes = compatibleDroidTypes
    }
    
    init(sequence: CapabilitySequence, compatibleDroidTypes: Set<DroidType>) {
        self.id = UUID()
        self.kind = .sequence
        self.name = sequence.name
        self.category = "Sequence"
        self.numericID = 0
        self.sequenceID = sequence.id
        self.compatibleDroidTypes = compatibleDroidTypes
    }
}
