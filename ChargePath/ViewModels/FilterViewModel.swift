//
//  FilterViewModel.swift
//  ChargePath
//
//  Backs the Filter bottom sheet. Edits a working copy of the StationFilter
//  and hands the result back through `onApply` when the sheet is dismissed —
//  the Map screen owns the authoritative filter.
//

import Foundation
import RxSwift
import RxRelay

final class FilterViewModel {

    // MARK: Injected dependencies
    private let localizationRepository: LocalizationRepository

    // MARK: Navigation hooks
    var onApply: ((StationFilter) -> Void)?

    // MARK: Outputs (working copy)
    let draft: BehaviorRelay<StationFilter>
    let strings: BehaviorRelay<Strings>
    /// Radius options offered by the segmented control (mockup: 2/5/25/Any).
    let radiusOptions: [Int] = [2, 5, 25, 100]

    private let disposeBag = DisposeBag()

    init(initialFilter: StationFilter,
         localizationRepository: LocalizationRepository) {
        self.localizationRepository = localizationRepository
        self.draft = BehaviorRelay(value: initialFilter)
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)

        localizationRepository.strings.bind(to: strings).disposed(by: disposeBag)
    }

    // MARK: Inputs

    func toggleConnector(_ connector: Connector) {
        var f = draft.value
        if f.connectors.contains(connector) {
            f.connectors.remove(connector)
        } else {
            f.connectors.insert(connector)
        }
        // Never allow an empty set — that would hide every station.
        if f.connectors.isEmpty { f.connectors = StationFilter.default.connectors }
        draft.accept(f)
    }

    func setAvailability(_ value: StationFilter.Availability) {
        var f = draft.value; f.availability = value; draft.accept(f)
    }

    func setPower(_ value: StationFilter.Power) {
        var f = draft.value; f.power = value; draft.accept(f)
    }

    func setRadius(_ km: Int) {
        var f = draft.value; f.radiusKm = km; draft.accept(f)
    }

    func setCompatibleOnly(_ on: Bool) {
        var f = draft.value; f.compatibleOnly = on; draft.accept(f)
    }

    func setHideOffline(_ on: Bool) {
        var f = draft.value; f.hideOffline = on; draft.accept(f)
    }

    func reset() {
        var f = StationFilter.default
        f.segment = draft.value.segment      // keep the All/Bookmarked choice
        f.query = draft.value.query
        draft.accept(f)
    }

    /// Called on dismiss — pushes the working copy back to the Map screen.
    func commit() {
        onApply?(draft.value)
    }
}
