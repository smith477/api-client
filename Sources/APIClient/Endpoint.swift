// Endpoint

import Foundation

public protocol Endpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
}

// MARK: - Defaults

public extension Endpoint {
    var method: HTTPMethod { .GET }
    var headers: [String: String]? { nil }
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
}

// MARK: - URLRequest Builder

public extension Endpoint {
    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        var allHeaders = headers ?? [:]
        if body != nil {
            allHeaders["Content-Type"] = "application/json"
        }
        allHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return request
    }
}
