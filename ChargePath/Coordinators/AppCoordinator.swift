//
//  AppCoordinator.swift
//  ChargePath
//
//  Root coordinator. Owns the window, the DependencyContainer (composition
//  root) and the UITabBarController, and starts one child coordinator per tab
//  (Map / Route Planner / Settings).
//

import UIKit
import RxSwift

final class AppCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let container = DependencyContainer()
    private let tabBarController = UITabBarController()
    private var mapCoordinator: MapCoordinator?
    private var mapNav: UINavigationController?
    private var routeNav: UINavigationController?
    private var settingsNav: UINavigationController?
    private let disposeBag = DisposeBag()

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        let strings = container.localizationRepository.currentStrings

        // Tab 1 — Map (real coordinator).
        let mapNav = makeTabNav(title: strings.tabMap, systemImage: "mappin.and.ellipse")
        let mapCoordinator = MapCoordinator(navigationController: mapNav, container: container)
        self.mapCoordinator = mapCoordinator
        addChild(mapCoordinator)

        // Tab 2 — Route Planner (real coordinator).
        let routeNav = makeTabNav(title: strings.tabRoute, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        let routeCoordinator = RoutePlannerCoordinator(navigationController: routeNav, container: container)
        routeCoordinator.showStationOnMap = { [weak self] station in
            self?.routeToStationOnMap(station)
        }
        addChild(routeCoordinator)

        // Tab 3 — Settings (real coordinator).
        let settingsNav = makeTabNav(title: strings.tabSettings, systemImage: "slider.horizontal.3")
        let settingsCoordinator = SettingsCoordinator(navigationController: settingsNav, container: container)
        settingsCoordinator.showStationOnMap = { [weak self] station in
            self?.routeToStationOnMap(station)
        }
        addChild(settingsCoordinator)

        self.mapNav = mapNav
        self.routeNav = routeNav
        self.settingsNav = settingsNav

        tabBarController.viewControllers = [mapNav, routeNav, settingsNav]
        styleTabBar()

        // Tab titles are set once above from a snapshot; re-apply them live
        // on every language switch (everything inside each tab already binds
        // reactively — the tab bar itself didn't).
        container.localizationRepository.strings
            .subscribe(onNext: { [weak self] strings in
                self?.mapNav?.tabBarItem.title = strings.tabMap
                self?.routeNav?.tabBarItem.title = strings.tabRoute
                self?.settingsNav?.tabBarItem.title = strings.tabSettings
            })
            .disposed(by: disposeBag)

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }

    /// Cross-tab: switch to Map and open the given station's detail sheet.
    private func routeToStationOnMap(_ station: Station) {
        tabBarController.selectedIndex = 0
        mapCoordinator?.presentStationDetail(for: station)
    }

    // MARK: Helpers

    private func makeTabNav(title: String, systemImage: String) -> UINavigationController {
        let nav = UINavigationController()
        nav.navigationBar.prefersLargeTitles = true
        nav.tabBarItem = UITabBarItem(title: title,
                                      image: UIImage(systemName: systemImage),
                                      selectedImage: nil)
        return nav
    }

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColor.cream
        appearance.stackedLayoutAppearance.selected.iconColor = AppColor.ink
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: AppColor.ink]
        appearance.stackedLayoutAppearance.normal.iconColor = AppColor.stone
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: AppColor.stone]
        tabBarController.tabBar.standardAppearance = appearance
        tabBarController.tabBar.scrollEdgeAppearance = appearance
        tabBarController.tabBar.tintColor = AppColor.ink
    }
}
