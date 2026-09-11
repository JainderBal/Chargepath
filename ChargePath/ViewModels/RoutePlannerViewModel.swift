//
//  RoutePlannerViewModel.swift
//  ChargePath
//
//  Backs the Route tab: a two-stage flow (trip input → results). Range and
//  connector are pre-filled from the selected vehicle but travel on the
//  TripQuery so the user could override them.
//

import Foundation
import RxSwift
import RxRelay

final class RoutePlannerViewModel {

    enum Stage: Equatable { case input, results }

    // MARK: Injected dependencies
    private let routeRepository: RouteRepository
    private let vehicleRepository: VehicleRepository
    private let localizationRepository: LocalizationRepository

    // MARK: Navigation hooks
    var onEditVehicle: (() -> Void)?
    var onSelectStop: ((Station) -> Void)?

    // MARK: Outputs
    let stage = BehaviorRelay<Stage>(value: .input)
    // Geocodable defaults so the real MKDirections path resolves out of the box.
    let originText = BehaviorRelay<String>(value: "Villeray, Montréal, QC")
    let destinationText = BehaviorRelay<String>(value: "Bromont, QC")
    let isPlanning = BehaviorRelay<Bool>(value: false)
    let plan = BehaviorRelay<RoutePlan?>(value: nil)
    let vehicleLine = BehaviorRelay<String>(value: "")
    let routeMeta = BehaviorRelay<String>(value: "")
    let strings: BehaviorRelay<Strings>

    private let disposeBag = DisposeBag()

    init(routeRepository: RouteRepository,
         vehicleRepository: VehicleRepository,
         localizationRepository: LocalizationRepository) {
        self.routeRepository = routeRepository
        self.vehicleRepository = vehicleRepository
        self.localizationRepository = localizationRepository
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)

        localizationRepository.strings
            .bind(to: strings)
            .disposed(by: disposeBag)

        vehicleRepository.selectedVehicle
            .map { "\($0.name) · \($0.rangeKm) km" }
            .bind(to: vehicleLine)
            .disposed(by: disposeBag)
    }

    // MARK: Inputs

    func setOrigin(_ text: String) { originText.accept(text) }
    func setDestination(_ text: String) { destinationText.accept(text) }
    func editVehicle() { onEditVehicle?() }

    func planTrip() {
        guard !isPlanning.value else { return }
        isPlanning.accept(true)

        let vehicle = vehicleRepository.currentVehicle
        let query = TripQuery(
            originText: originText.value,
            destinationText: destinationText.value,
            vehicleRangeKm: vehicle.rangeKm,
            vehicleConnector: vehicle.connector
        )

        routeRepository.planTrip(query)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] plan in
                guard let self else { return }
                self.isPlanning.accept(false)
                self.plan.accept(plan)
                self.routeMeta.accept("\(Int(plan.totalDistanceKm)) km · \(vehicle.name)")
                self.stage.accept(.results)
            }, onFailure: { [weak self] _ in
                self?.isPlanning.accept(false)
            })
            .disposed(by: disposeBag)
    }

    func backToInput() {
        stage.accept(.input)
    }

    func selectStop(_ stop: ChargingStop) {
        onSelectStop?(stop.station)
    }
}
