//
//  MapCoordinator.swift
//  ChargePath
//
//  Owns the Map tab's navigation: the map screen, the Station Detail bottom
//  sheet (UISheetPresentationController .medium()/.large()), and the
//  Activate Charging flow presented over it. Every screen is built here from
//  the DependencyContainer — the ViewControllers construct nothing.
//

import UIKit
import RxRelay

final class MapCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let container: DependencyContainer
    private weak var mapViewController: MapViewController?
    private weak var detailViewController: StationDetailViewController?
    private weak var detailViewModel: StationDetailViewModel?

    init(navigationController: UINavigationController, container: DependencyContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    /// Entry point for other tabs: open a station's detail sheet on the map.
    func presentStationDetail(for station: Station) {
        // Dismiss anything already up (e.g. a stale sheet) before re-presenting.
        navigationController.presentedViewController?.dismiss(animated: false)
        showStationDetail(for: station)
    }

    func start() {
        let viewModel = container.makeMapViewModel()
        viewModel.onSelectStation = { [weak self] station in
            self?.showStationDetail(for: station)
        }
        viewModel.onOpenFilters = { [weak self] currentFilter in
            self?.showFilters(current: currentFilter, apply: { updated in
                viewModel.applyFilter(updated)
            })
        }
        viewModel.onOpenActiveSession = { [weak self] in
            self?.showActiveSession()
        }
        let vc = MapViewController(viewModel: viewModel)
        vc.navigationItem.title = viewModel.strings.value.tabMap
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([vc], animated: false)
        mapViewController = vc
    }

    // MARK: Station Detail

    private func showStationDetail(for station: Station) {
        let approxSheetHeight = UIScreen.main.bounds.height * AppMetrics.stationSheetMediumFraction

        // Sheet already open (map stays tappable at .medium) → just re-point it
        // at the newly tapped pin instead of trying to present over it.
        if let existing = detailViewController,
           navigationController.presentedViewController === existing {
            detailViewModel?.present(station)
            mapViewController?.focus(on: station, sheetHeight: approxSheetHeight)
            return
        }

        let viewModel = container.makeStationDetailViewModel(station: station)
        viewModel.onStartCharging = { [weak self] station in
            self?.showActivateCharging(for: station)
        }
        viewModel.onStartNavigation = { [weak self] station in
            self?.showNavigation(to: station)
        }
        let detail = StationDetailViewController(viewModel: viewModel)
        detailViewController = detail
        detailViewModel = viewModel

        if let sheet = detail.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = AppMetrics.radiusSheet
            sheet.largestUndimmedDetentIdentifier = .medium   // map stays tappable
        }

        // Mirror the mockup's "map area shrinks + pans to the pin" behaviour.
        mapViewController?.focus(on: station, sheetHeight: approxSheetHeight)
        detail.presentationController?.delegate = SheetDismissObserver.shared
        SheetDismissObserver.shared.onDismiss = { [weak self] in
            self?.detailViewController = nil
            self?.mapViewController?.endFocus()
        }

        navigationController.present(detail, animated: true)
    }

    // MARK: In-app navigation

    private func showNavigation(to station: Station) {
        NavigationEngine.ensureConsent { [weak self] in
            guard let self else { return }
            let viewModel = self.container.makeNavigationViewModel(destination: station)
            let vc = NavigationViewController(viewModel: viewModel)
            viewModel.onExit = { [weak vc] in vc?.dismiss(animated: true) }
            let presenter = self.navigationController.presentedViewController ?? self.navigationController
            presenter.present(vc, animated: true)
        }
    }

    // MARK: Activate Charging → live session

    private func showActivateCharging(for station: Station) {
        let viewModel = container.makeActivateChargingViewModel(station: station)
        let activate = ActivateChargingViewController(viewModel: viewModel)
        activate.modalPresentationStyle = .fullScreen

        viewModel.onCancel = { [weak activate] in activate?.dismiss(animated: true) }
        viewModel.onNeedsFunds = { [weak self, weak activate] in
            activate?.dismiss(animated: true) { self?.showWalletForTopUp() }
        }
        viewModel.onSessionStarted = { [weak self, weak activate] _ in
            // Activate → dismiss it → dismiss the detail sheet → show the live screen.
            activate?.dismiss(animated: true) {
                self?.navigationController.presentedViewController?.dismiss(animated: true) {
                    self?.detailViewController = nil
                    self?.mapViewController?.endFocus()
                    self?.showActiveSession()
                }
            }
        }
        navigationController.presentedViewController?.present(activate, animated: true)
    }

    private func showActiveSession() {
        // Already up? (tapped the map banner while it's presented) do nothing.
        if navigationController.presentedViewController is ActiveSessionViewController { return }
        navigationController.presentedViewController?.dismiss(animated: false)

        let viewModel = container.makeActiveSessionViewModel()
        let vc = ActiveSessionViewController(viewModel: viewModel)
        viewModel.onFinished = { [weak vc] in vc?.dismiss(animated: true) }
        navigationController.present(vc, animated: true)
    }

    private func showWalletForTopUp() {
        let wallet = WalletViewController(viewModel: container.makeWalletViewModel())
        let nav = UINavigationController(rootViewController: wallet)
        wallet.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .done, primaryAction: UIAction { [weak nav] _ in nav?.dismiss(animated: true) })
        navigationController.present(nav, animated: true)
    }

    // MARK: Filters

    private func showFilters(current: StationFilter, apply: @escaping (StationFilter) -> Void) {
        let viewModel = container.makeFilterViewModel(initialFilter: current)
        viewModel.onApply = apply
        let filters = FilterViewController(viewModel: viewModel)
        if let sheet = filters.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = AppMetrics.radiusSheet
        }
        navigationController.present(filters, animated: true)
    }
}

/// Bridges UISheetPresentationController dismissal back to the coordinator so
/// the map can restore its full height. One shared observer is enough — only
/// one detail sheet is ever on screen.
final class SheetDismissObserver: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = SheetDismissObserver()
    var onDismiss: (() -> Void)?

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss?()
    }
}
