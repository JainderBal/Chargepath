//
//  LocalizationRepository.swift
//  ChargePath
//
//  Holds the current language and vends the matching `Strings` table. Every
//  ViewModel subscribes to `strings` so an EN/FR switch in Settings updates
//  the whole app live (no relaunch), exactly like the mockup.
//

import Foundation
import RxSwift
import RxRelay

protocol LocalizationRepository: AnyObject {
    var language: Observable<AppLanguage> { get }
    var currentLanguage: AppLanguage { get }
    /// Convenience stream of the resolved copy table.
    var strings: Observable<Strings> { get }
    var currentStrings: Strings { get }
    func setLanguage(_ language: AppLanguage)
}

final class DefaultLocalizationRepository: LocalizationRepository {

    private enum Key { static let language = "localization.language" }

    private let store: KeyValueStore
    private let relay: BehaviorRelay<AppLanguage>

    var language: Observable<AppLanguage> { relay.asObservable() }
    var currentLanguage: AppLanguage { relay.value }
    var strings: Observable<Strings> { relay.map(\.strings) }
    var currentStrings: Strings { relay.value.strings }

    init(store: KeyValueStore) {
        self.store = store
        let saved = store.codable(AppLanguage.self, forKey: Key.language) ?? .en
        self.relay = BehaviorRelay(value: saved)
    }

    func setLanguage(_ language: AppLanguage) {
        guard language != relay.value else { return }
        relay.accept(language)
        store.setCodable(language, forKey: Key.language)
    }
}
