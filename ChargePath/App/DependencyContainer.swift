//
//  DependencyContainer.swift
//  ChargePath
//
//  The single composition root. It constructs the real Services once, wires
//  them into the real Repositories once (these hold shared state — the
//  bookmark set, the wallet, the station cache — so there is exactly one of
//  each for the app), and exposes factory methods that build a fresh
//  ViewModel per screen from those shared repositories.
//
//  Nothing else in the app calls a Service or Repository initialiser. The
//  coordinators ask this container for ViewModels when they navigate.
//

import Foundation

final class DependencyContainer {

    // MARK: Services (constructed once, here)

    private let config = APIConfig.default
    private lazy var keyValueStore: KeyValueStore = UserDefaultsKeyValueStore()
    private lazy var apiClient: APIClient = AlamofireAPIClient(session: HTTPSession.shared)
    private lazy var stationService: StationService =
        ChargeHubStationService(apiClient: apiClient, config: config)
    private lazy var geocodingService: GeocodingService = AppleGeocodingService()
    private lazy var directionsService: RouteDirectionsService = MapKitDirectionsService()
    private lazy var paymentService: PaymentAuthService = MockPaymentAuthService()
    // Fixed Montréal position — no permission prompt, and the seeded stations
    // always land inside the default radius. Swap in SystemLocationService for
    // real device location.
    private lazy var locationService: LocationService = FixedLocationService()

    // MARK: Repositories (shared, stateful — one instance each)

    private(set) lazy var stationRepository: StationRepository =
        DefaultStationRepository(service: stationService)
    private(set) lazy var bookmarkRepository: BookmarkRepository =
        DefaultBookmarkRepository(store: keyValueStore)
    private(set) lazy var vehicleRepository: VehicleRepository =
        DefaultVehicleRepository(store: keyValueStore)
    private(set) lazy var localizationRepository: LocalizationRepository =
        DefaultLocalizationRepository(store: keyValueStore)
    private(set) lazy var walletRepository: WalletRepository =
        DefaultWalletRepository(store: keyValueStore)
    private(set) lazy var chargingSessionRepository: ChargingSessionRepository =
        DefaultChargingSessionRepository(payment: paymentService, walletRepository: walletRepository)
    private(set) lazy var routeRepository: RouteRepository =
        DefaultRouteRepository(
            geocoder: geocodingService,
            directions: directionsService,
            stationRepository: stationRepository
        )

    // MARK: ViewModel factories (one fresh instance per screen)

    func makeMapViewModel() -> MapViewModel {
        MapViewModel(
            stationRepository: stationRepository,
            bookmarkRepository: bookmarkRepository,
            vehicleRepository: vehicleRepository,
            localizationRepository: localizationRepository,
            locationService: locationService,
            chargingSessionRepository: chargingSessionRepository
        )
    }

    func makeStationDetailViewModel(station: Station) -> StationDetailViewModel {
        StationDetailViewModel(
            station: station,
            stationRepository: stationRepository,
            bookmarkRepository: bookmarkRepository,
            vehicleRepository: vehicleRepository,
            localizationRepository: localizationRepository,
            chargingSessionRepository: chargingSessionRepository
        )
    }

    func makeActivateChargingViewModel(station: Station) -> ActivateChargingViewModel {
        ActivateChargingViewModel(
            station: station,
            chargingSessionRepository: chargingSessionRepository,
            localizationRepository: localizationRepository
        )
    }

    func makeActiveSessionViewModel() -> ActiveSessionViewModel {
        ActiveSessionViewModel(
            chargingSessionRepository: chargingSessionRepository,
            localizationRepository: localizationRepository
        )
    }

    func makeRoutePlannerViewModel() -> RoutePlannerViewModel {
        RoutePlannerViewModel(
            routeRepository: routeRepository,
            vehicleRepository: vehicleRepository,
            localizationRepository: localizationRepository
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            vehicleRepository: vehicleRepository,
            walletRepository: walletRepository,
            bookmarkRepository: bookmarkRepository,
            stationRepository: stationRepository,
            localizationRepository: localizationRepository
        )
    }

    func makeVehicleSelectionViewModel() -> VehicleSelectionViewModel {
        VehicleSelectionViewModel(
            vehicleRepository: vehicleRepository,
            localizationRepository: localizationRepository
        )
    }

    func makeWalletViewModel() -> WalletViewModel {
        WalletViewModel(
            walletRepository: walletRepository,
            localizationRepository: localizationRepository
        )
    }

    func makeFilterViewModel(initialFilter: StationFilter) -> FilterViewModel {
        FilterViewModel(
            initialFilter: initialFilter,
            localizationRepository: localizationRepository
        )
    }
}
