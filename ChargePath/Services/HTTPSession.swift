//
//  HTTPSession.swift
//  ChargePath
//
//  The one legitimate singleton in the app: a single shared, pre-configured
//  Alamofire `Session`. There is genuinely one connection pool / URLCache for
//  the process and no meaningful per-caller alternative, which is exactly the
//  case the brief carves out for Singletons.
//
//  Everything above this (APIClient, Services, Repositories, ViewModels) is
//  still an injected instance — they receive this `Session`, they don't reach
//  for the singleton themselves.
//

import Foundation
import Alamofire

enum HTTPSession {
    /// Shared session. Configure timeouts / caching here once.
    static let shared: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = APIConfig.default.requestTimeout
        configuration.waitsForConnectivity = true
        configuration.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024
        )
        return Session(configuration: configuration)
    }()
}
