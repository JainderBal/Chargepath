//
//  AppDelegate.swift
//  ChargePath
//
//  UIKit application lifecycle entry point. No storyboard, no SwiftUI App
//  protocol — the process is launched straight into `main` by the
//  `@main` attribute below, and per-window UI is set up in SceneDelegate.
//

import UIKit
#if canImport(GoogleNavigation)
import GoogleMaps
#endif

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Process-level setup only (analytics, logging, appearance proxies).
        // Window/scene wiring lives in SceneDelegate.
        configureNavigationSDK()
        return true
    }

    /// Hand the Google Navigation SDK its API key, if one is configured and the
    /// SDK is linked. Empty key / SDK absent → the Navigation screen shows its
    /// placeholder instead of a live map.
    private func configureNavigationSDK() {
        let key = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        #if canImport(GoogleNavigation)
        GMSServices.provideAPIKey(key)
        NavigationEngine.isConfigured = true
        #endif
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
