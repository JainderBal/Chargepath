//
//  Coordinator.swift
//  ChargePath
//
//  Minimal coordinator contract. Coordinators own navigation: they build each
//  screen (asking the DependencyContainer for its ViewModel), push/present it,
//  and hold any child coordinators. ViewControllers never construct their own
//  ViewModels or decide what comes next.
//

import UIKit

protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    func start()
}

extension Coordinator {
    /// Retain a child and start it.
    func addChild(_ child: Coordinator) {
        childCoordinators.append(child)
        child.start()
    }

    /// Release a finished child.
    func removeChild(_ child: Coordinator?) {
        guard let child else { return }
        childCoordinators.removeAll { $0 === child }
    }
}
