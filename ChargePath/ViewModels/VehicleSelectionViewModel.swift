//
//  VehicleSelectionViewModel.swift
//  ChargePath
//
//  Backs the Vehicle Selection screen: a list of catalogue vehicles with the
//  current pick marked, plus the "or pick a connector" manual chips.
//

import Foundation
import RxSwift
import RxRelay

/// One row in the vehicle list.
struct VehicleRow: Equatable {
    let vehicle: Vehicle
    let isSelected: Bool
}

/// One manual connector chip.
struct ConnectorChip: Equatable {
    let connector: Connector
    let isSelected: Bool
}

final class VehicleSelectionViewModel {

    // MARK: Injected dependencies
    private let vehicleRepository: VehicleRepository
    private let localizationRepository: LocalizationRepository

    // MARK: Navigation hooks
    var onDone: (() -> Void)?

    // MARK: Outputs
    let vehicleRows = BehaviorRelay<[VehicleRow]>(value: [])
    let connectorChips = BehaviorRelay<[ConnectorChip]>(value: [])
    let strings: BehaviorRelay<Strings>

    private let manualConnectors: [Connector] = [.ccs, .nacs, .j1772]
    private let disposeBag = DisposeBag()

    init(vehicleRepository: VehicleRepository,
         localizationRepository: LocalizationRepository) {
        self.vehicleRepository = vehicleRepository
        self.localizationRepository = localizationRepository
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)

        localizationRepository.strings.bind(to: strings).disposed(by: disposeBag)

        vehicleRepository.selectedVehicle
            .subscribe(onNext: { [weak self] selected in
                self?.rebuild(selected: selected)
            })
            .disposed(by: disposeBag)
    }

    // MARK: Inputs

    func select(_ vehicle: Vehicle) {
        vehicleRepository.select(vehicle)
    }

    func selectConnector(_ connector: Connector) {
        vehicleRepository.selectVehicle(forConnector: connector)
    }

    func done() { onDone?() }

    // MARK: Helpers

    private func rebuild(selected: Vehicle) {
        vehicleRows.accept(
            vehicleRepository.availableVehicles.map {
                VehicleRow(vehicle: $0, isSelected: $0.id == selected.id)
            }
        )
        connectorChips.accept(
            manualConnectors.map {
                ConnectorChip(connector: $0, isSelected: $0 == selected.connector)
            }
        )
    }
}
