//
//  APIClient.swift
//  ChargePath
//
//  Generic JSON-over-HTTP client. Wraps Alamofire and hands back RxSwift
//  `Single`s so the services above compose reactively.
//

import Foundation
import Alamofire
import RxSwift

enum APIError: Error, Equatable {
    case transport(String)      // no connectivity, timeout, DNS…
    case http(status: Int)      // non-2xx
    case decoding(String)       // body didn't match the DTO
    case missingCredentials     // no API key configured
}

protocol APIClient: AnyObject {
    /// Fire `route` and decode the JSON body into `T`.
    func request<T: Decodable>(_ route: URLRequestConvertible, as type: T.Type) -> Single<T>
}

final class AlamofireAPIClient: APIClient {

    private let session: Session
    private let decoder: JSONDecoder

    /// `session` is injected (defaults to the shared singleton) so tests can
    /// pass a stubbed one.
    init(session: Session = HTTPSession.shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func request<T: Decodable>(_ route: URLRequestConvertible, as type: T.Type) -> Single<T> {
        Single.create { [session, decoder] observer in
            let request = session
                .request(route)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            observer(.success(try decoder.decode(T.self, from: data)))
                        } catch {
                            observer(.failure(APIError.decoding(String(describing: error))))
                        }
                    case .failure(let afError):
                        if let status = response.response?.statusCode, !(200..<300).contains(status) {
                            observer(.failure(APIError.http(status: status)))
                        } else {
                            observer(.failure(APIError.transport(afError.localizedDescription)))
                        }
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }
}
