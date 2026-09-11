//
//  KeyValueStore.swift
//  ChargePath
//
//  Thin typed wrapper over persistent key/value storage. Repositories depend
//  on the `KeyValueStore` protocol (not on UserDefaults directly) so they can
//  be unit-tested with an in-memory double.
//

import Foundation

protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)
}

extension KeyValueStore {
    /// Decode a Codable value previously stored with `setCodable`.
    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func setCodable<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else { set(nil, forKey: key); return }
        set(try? JSONEncoder().encode(value), forKey: key)
    }
}

/// Production implementation. Not a singleton — one instance is created in the
/// composition root and injected wherever persistence is needed.
final class UserDefaultsKeyValueStore: KeyValueStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func set(_ data: Data?, forKey key: String) { defaults.set(data, forKey: key) }
    func bool(forKey key: String) -> Bool { defaults.bool(forKey: key) }
    func set(_ value: Bool, forKey key: String) { defaults.set(value, forKey: key) }
}
