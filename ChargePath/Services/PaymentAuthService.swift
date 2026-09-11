//
//  PaymentAuthService.swift
//  ChargePath
//
//  The seam where a real payment processor would live. Starting a charging
//  session places a pre-authorisation *hold* on the payment method; the real
//  amount is captured when the session stops.
//
//  This build mocks it: a short delay, always succeeds. Swap in a real
//  implementation (StoreKit 2, Stripe PaymentIntent + backend, …) behind the
//  same protocol without touching the Repositories or ViewModels.
//

import Foundation
import RxSwift

protocol PaymentAuthService: AnyObject {
    /// Simulated pre-authorisation hold for a charging session.
    func authorizeHold(amount: Double) -> Single<Void>
}

final class MockPaymentAuthService: PaymentAuthService {

    private let scheduler: SchedulerType
    private let simulatedLatency: RxTimeInterval

    init(scheduler: SchedulerType = MainScheduler.instance,
         simulatedLatency: RxTimeInterval = .milliseconds(700)) {
        self.scheduler = scheduler
        self.simulatedLatency = simulatedLatency
    }

    func authorizeHold(amount: Double) -> Single<Void> {
        Single.just(()).delay(simulatedLatency, scheduler: scheduler)
    }
}
