//
//  Created by Jose Galindo Martinez on 30/10/21.
//

import UIKit
import Combine

final class ApiClient {

    typealias Parameters = [String: String]
    
    private var baseURL: URL?
    private var decoder : JSONDecoder!
    
    static let shared : ApiClient = ApiClient()
    private init() {
        baseURL = URL(string: "https://jsonplaceholder.typicode.com/")
        decoder = JSONDecoder()
    }
    
    // MARK: - Generic GET
    func get<T: Codable>(endpoint: Endpoint,
                         parameters: Parameters = [:]) -> AnyPublisher<Result<T, APIError>, Never> {
        guard let url = baseURL else {
            return Just(Result.failure(APIError.invalidRequest)).eraseToAnyPublisher()
        }
        let queryURL = url.appendingPathComponent(endpoint.path())
        var components = URLComponents(url: queryURL, resolvingAgainstBaseURL: true)!
        if !parameters.isEmpty {
            components.queryItems = parameters.compactMap {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return URLSession.shared.dataTaskPublisher(for: request)
            .map({ $0.data})
//            .print()
            .decode(type: T.self, decoder: decoder)
            .map({ Result.success($0) })
            .catch({ error -> AnyPublisher<Result<T, APIError>, Never> in
                return Just(Result.failure(APIError.jsonDecodingError(error: error))).eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }
    
    
    func get<T: Codable>(endpoint: Endpoint,
                         parameters: Parameters = [:],
                         completionHandler: @escaping (Result<T, APIError>)->Void) {
        guard let url = baseURL else {
            completionHandler(.failure(.invalidRequest))
            return
        }
        let queryURL = url.appendingPathComponent(endpoint.path())
        var components = URLComponents(url: queryURL, resolvingAgainstBaseURL: true)!
        if !parameters.isEmpty {
            components.queryItems = parameters.compactMap {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                completionHandler(.failure(.invalidRequest))
                return
            }
            do {
                let object = try self.decoder.decode(T.self, from: data)
                completionHandler(.success(object))
            } catch let merror {
                completionHandler(.failure(.jsonDecodingError(error: merror)))
            }
        }
        dataTask.resume()
    }
}

public enum Endpoint {
    case posts
    case comments
    case commentDetail(commentId: Int)
    
    func path() -> String {
        switch self {
        case .posts:
            return "/posts"
        case .comments:
            return "/comments"
        case let .commentDetail(commentId):
            return "/comments/\(commentId)"
        }
    }
}

public enum APIError: Error {
    case noResponse
    case invalidRequest
    case jsonDecodingError(error: Error)
    case networkError(error: Error)
}

