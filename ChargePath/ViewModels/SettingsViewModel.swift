//
//  SettingsViewModel.swift
//  ChargePath
//
//  Backs the Settings tab: vehicle profile row, EN/FR toggle, wallet summary,
//  app info, and the bookmarked-stations list.
//

import Foundation
import RxSwift
import RxRelay

final class SettingsViewModel {

    // MARK: Injected dependencies
    private let vehicleRepository: VehicleRepository
    private let walletRepository: WalletRepository
    private let bookmarkRepository: BookmarkRepository
    private let stationRepository: StationRepository
    private let localizationRepository: LocalizationRepository

    // MARK: Navigation hooks
    var onOpenVehicle: (() -> Void)?
    var onOpenWallet: (() -> Void)?
    var onSelectBookmarkedStation: ((Station) -> Void)?

    // MARK: Outputs
    let vehicleName = BehaviorRelay<String>(value: "")
    let language: BehaviorRelay<AppLanguage>
    let walletBalanceText = BehaviorRelay<String>(value: "")
    let bookmarkedStations = BehaviorRelay<[Station]>(value: [])
    let strings: BehaviorRelay<Strings>

    let appVersionText: String = {
        let dict = Bundle.main.infoDictionary
        let version = dict?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "\(version) · Test Mode"
    }()

    private let disposeBag = DisposeBag()

    init(vehicleRepository: VehicleRepository,
         walletRepository: WalletRepository,
         bookmarkRepository: BookmarkRepository,
         stationRepository: StationRepository,
         localizationRepository: LocalizationRepository) {
        self.vehicleRepository = vehicleRepository
        self.walletRepository = walletRepository
        self.bookmarkRepository = bookmarkRepository
        self.stationRepository = stationRepository
        self.localizationRepository = localizationRepository
        self.language = BehaviorRelay(value: localizationRepository.currentLanguage)
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)

        bind()
    }

    // MARK: Inputs

    func setLanguage(_ language: AppLanguage) {
        localizationRepository.setLanguage(language)
    }

    func openVehicle() { onOpenVehicle?() }
    func openWallet() { onOpenWallet?() }

    func selectBookmarkedStation(_ station: Station) {
        onSelectBookmarkedStation?(station)
    }

    // MARK: Binding

    private func bind() {
        localizationRepository.strings.bind(to: strings).disposed(by: disposeBag)
        localizationRepository.language.bind(to: language).disposed(by: disposeBag)

        vehicleRepository.selectedVehicle
            .map(\.name)
            .bind(to: vehicleName)
            .disposed(by: disposeBag)

        walletRepository.wallet
            .map { "$\(String(format: "%.2f", $0.balance))" }
            .bind(to: walletBalanceText)
            .disposed(by: disposeBag)

        // Bookmarked ids -> resolved Station objects for the list.
        Observable.combineLatest(
            bookmarkRepository.bookmarkedStationIDs,
            stationRepository.stations
        )
        .map { ids, stations in
            stations.filter { ids.contains($0.id) }
        }
        .bind(to: bookmarkedStations)
        .disposed(by: disposeBag)
    }
}
