//
//  BookmarkRepository.swift
//  ChargePath
//
//  The set of bookmarked ("starred") station ids, persisted between launches.
//  Seeded to match the mockup ({ s2, s4 }) on first run.
//

import Foundation
import RxSwift
import RxRelay

protocol BookmarkRepository: AnyObject {
    var bookmarkedStationIDs: Observable<Set<String>> { get }
    func isBookmarked(_ stationID: String) -> Bool
    func toggle(_ stationID: String)
}

final class DefaultBookmarkRepository: BookmarkRepository {

    private enum Key {
        static let ids = "bookmark.stationIDs"
        static let seeded = "bookmark.didSeed"
    }

    private let store: KeyValueStore
    private let relay: BehaviorRelay<Set<String>>

    var bookmarkedStationIDs: Observable<Set<String>> { relay.asObservable() }

    init(store: KeyValueStore, seedIDs: Set<String> = StationSeed.defaultBookmarkedIDs) {
        self.store = store

        if store.bool(forKey: Key.seeded) {
            let saved = store.codable([String].self, forKey: Key.ids) ?? []
            relay = BehaviorRelay(value: Set(saved))
        } else {
            // First launch: plant the mockup's default bookmarks.
            relay = BehaviorRelay(value: seedIDs)
            store.set(true, forKey: Key.seeded)
            store.setCodable(Array(seedIDs), forKey: Key.ids)
        }
    }

    func isBookmarked(_ stationID: String) -> Bool {
        relay.value.contains(stationID)
    }

    func toggle(_ stationID: String) {
        var ids = relay.value
        if ids.contains(stationID) {
            ids.remove(stationID)
        } else {
            ids.insert(stationID)
        }
        relay.accept(ids)
        store.setCodable(Array(ids), forKey: Key.ids)
    }
}
