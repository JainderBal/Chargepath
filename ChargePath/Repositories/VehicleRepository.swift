//
//  VehicleRepository.swift
//  ChargePath
//
//  The catalogue of selectable vehicles + which one the user picked. The
//  selection is observed by the Route Planner (range auto-fill), Station
//  Detail (connector "fits your car" highlight) and Settings.
//

import Foundation
import RxSwift
import RxRelay

protocol VehicleRepository: AnyObject {
    var availableVehicles: [Vehicle] { get }
    var selectedVehicle: Observable<Vehicle> { get }
    var currentVehicle: Vehicle { get }
    func select(_ vehicle: Vehicle)
    /// Pick the first catalogue vehicle that uses `connector` (mockup's
    /// "or pick a connector" manual path).
    func selectVehicle(forConnector connector: Connector)
}

final class DefaultVehicleRepository: VehicleRepository {

    private enum Key { static let selectedID = "vehicle.selectedID" }

    private let store: KeyValueStore
    private let relay: BehaviorRelay<Vehicle>

    let availableVehicles: [Vehicle]

    var selectedVehicle: Observable<Vehicle> { relay.asObservable() }
    var currentVehicle: Vehicle { relay.value }

    init(store: KeyValueStore, catalogue: [Vehicle] = StationSeed.vehicles) {
        precondition(!catalogue.isEmpty, "Vehicle catalogue must not be empty")
        self.store = store
        self.availableVehicles = catalogue

        let savedID = store.codable(String.self, forKey: Key.selectedID)
        let initial = catalogue.first { $0.id == savedID } ?? catalogue[0]
        self.relay = BehaviorRelay(value: initial)
    }

    func select(_ vehicle: Vehicle) {
        guard availableVehicles.contains(where: { $0.id == vehicle.id }) else { return }
        relay.accept(vehicle)
        store.setCodable(vehicle.id, forKey: Key.selectedID)
    }

    func selectVehicle(forConnector connector: Connector) {
        guard let match = availableVehicles.first(where: { $0.connector == connector }) else { return }
        select(match)
    }
}
