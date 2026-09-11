//
//  SettingsCoordinator.swift
//  ChargePath
//
//  Owns the Settings tab and its navigation: Vehicle Selection + Wallet
//  pushes. Every screen is built from the container.
//

import UIKit

final class SettingsCoordinator: Coordinator {

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
        let viewModel = container.makeSettingsViewModel()
        viewModel.onOpenVehicle = { [weak self] in self?.showVehicleSelection() }
        viewModel.onOpenWallet = { [weak self] in self?.showWallet() }
        viewModel.onSelectBookmarkedStation = { [weak self] station in
            self?.showStationOnMap?(station)
        }

        let vc = SettingsViewController(viewModel: viewModel)
        vc.navigationItem.title = container.localizationRepository.currentStrings.tabSettings
        navigationController.setViewControllers([vc], animated: false)
    }

    private func showVehicleSelection() {
        let vc = VehicleSelectionViewController(viewModel: container.makeVehicleSelectionViewModel())
        navigationController.pushViewController(vc, animated: true)
    }

    private func showWallet() {
        let vc = WalletViewController(viewModel: container.makeWalletViewModel())
        navigationController.pushViewController(vc, animated: true)
    }
}
