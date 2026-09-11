//
//  RoutePlannerCoordinator.swift
//  ChargePath
//
//  Owns the Route tab: the trip planner screen plus the pushes it triggers
//  (Vehicle Selection). Selecting a computed stop hands off to the app-level
//  router so it opens on the Map tab.
//

import UIKit
import RxRelay

final class RoutePlannerCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    /// Set by AppCoordinator — jump to the Map tab and open this station.
    var showStationOnMap: ((Station) -> Void)?

    private let navigationController: UINavigationController
    private let container: DependencyContainer

    init(navigationController: UINavigationController, container: DependencyContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = container.makeRoutePlannerViewModel()
        viewModel.onEditVehicle = { [weak self] in self?.showVehicleSelection() }
        viewModel.onSelectStop = { [weak self] station in self?.showStationOnMap?(station) }
        viewModel.onStartNavigation = { [weak self, weak viewModel] plan in
            self?.showNavigation(for: plan, destinationTitle: viewModel?.destinationText.value ?? "")
        }

        let vc = RoutePlannerViewController(viewModel: viewModel)
        vc.navigationItem.title = container.localizationRepository.currentStrings.tabRoute
        navigationController.setViewControllers([vc], animated: false)
    }

    private func showNavigation(for plan: RoutePlan, destinationTitle: String) {
        NavigationEngine.ensureConsent { [weak self] in
            guard let self else { return }
            let viewModel = self.container.makeNavigationViewModel(
                plan: plan, destinationTitle: destinationTitle
            )
            let vc = NavigationViewController(viewModel: viewModel)
            viewModel.onExit = { [weak vc] in vc?.dismiss(animated: true) }
            self.navigationController.present(vc, animated: true)
        }
    }

    private func showVehicleSelection() {
        let viewModel = container.makeVehicleSelectionViewModel()
        let vc = VehicleSelectionViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }
}
