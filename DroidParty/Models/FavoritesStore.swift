//
//  FavoritesStore.swift
//  SWSphero
//
//  Singleton store for user-favorited sounds, animations, and sequences.
//  Persists to UserDefaults as JSON. Max 4 favorites per droid type.
//

import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    
    static let shared = FavoritesStore()
    
    static let maxFavorites = 4
    
    /// Per-droid-type favorites. Published so views update when any list changes.
    @Published private(set) var favoritesByDroid: [DroidType: [FavoriteItem]] = [:]
    
    private init() {
        loadAll()
    }
    
    // MARK: - Access
    
    /// Returns favorites for a specific droid type.
    func favorites(for droidType: DroidType) -> [FavoriteItem] {
        favoritesByDroid[droidType] ?? []
    }
    
    // MARK: - Queries
    
    /// Check if a specific item is already favorited for the given droid type.
    func contains(kind: FavoriteItemKind, numericID: UInt16, sequenceID: String? = nil, for droidType: DroidType) -> Bool {
        favorites(for: droidType).contains { item in
            if item.kind != kind { return false }
            if kind == .sequence { return item.sequenceID == sequenceID }
            return item.numericID == numericID
        }
    }
    
    /// Whether the given droid type's favorites list is full.
    func isFull(for droidType: DroidType) -> Bool {
        favorites(for: droidType).count >= Self.maxFavorites
    }
    
    // MARK: - Mutations
    
    /// Add a favorite for a droid type. Returns false if full or duplicate.
    @discardableResult
    func add(_ item: FavoriteItem, for droidType: DroidType) -> Bool {
        guard !isFull(for: droidType) else { return false }
        guard !contains(kind: item.kind, numericID: item.numericID, sequenceID: item.sequenceID, for: droidType) else { return false }
        var list = favoritesByDroid[droidType] ?? []
        list.append(item)
        favoritesByDroid[droidType] = list
        save(for: droidType)
        return true
    }
    
    /// Remove a favorite by matching kind + ID for a droid type.
    func remove(kind: FavoriteItemKind, numericID: UInt16, sequenceID: String? = nil, for droidType: DroidType) {
        var list = favoritesByDroid[droidType] ?? []
        list.removeAll { item in
            if item.kind != kind { return false }
            if kind == .sequence { return item.sequenceID == sequenceID }
            return item.numericID == numericID
        }
        favoritesByDroid[droidType] = list
        save(for: droidType)
    }
    
    // MARK: - Persistence
    
    private static func storageKey(for droidType: DroidType) -> String {
        "favorites_\(droidType.rawValue)"
    }
    
    private func save(for droidType: DroidType) {
        let list = favoritesByDroid[droidType] ?? []
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey(for: droidType))
    }
    
    private func loadAll() {
        for droidType in DroidType.allCases {
            let key = Self.storageKey(for: droidType)
            guard let data = UserDefaults.standard.data(forKey: key),
                  let items = try? JSONDecoder().decode([FavoriteItem].self, from: data) else { continue }
            favoritesByDroid[droidType] = items
        }
    }
}
