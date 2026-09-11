//
//  AppDelegate.swift
//  ChargePath
//
//  UIKit application lifecycle entry point. No storyboard, no SwiftUI App
//  protocol — the process is launched straight into `main` by the
//  `@main` attribute below, and per-window UI is set up in SceneDelegate.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Process-level setup only (analytics, logging, appearance proxies).
        // Window/scene wiring lives in SceneDelegate.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Points UIKit at the "Default Configuration" declared in Info.plist,
        // which names SceneDelegate as the scene delegate class.
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
