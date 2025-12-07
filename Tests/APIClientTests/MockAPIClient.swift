// MockAPIClient.swift

@testable import APIClient
import Foundation

// MARK: - Mock APIClient for Testing

public actor MockAPIClient: APIClientProtocol {
    public var responses: [String: Any] = [:]
    public var errors: [String: APIError] = [:]
    public var requestHistory: [Endpoint] = []

    public init() {}

    public func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws(APIError) -> T {
        requestHistory.append(endpoint)

        if let error = errors[endpoint.path] {
            throw error
        }

        guard let response = responses[endpoint.path] as? T else {
            throw APIError.notFound
        }

        return response
    }

    // MARK: - Test Helpers

    public func stub<T>(_ endpoint: String, with response: T) {
        responses[endpoint] = response
    }

    public func stubError(_ endpoint: String, with error: APIError) {
        errors[endpoint] = error
    }

    public func reset() {
        responses.removeAll()
        errors.removeAll()
        requestHistory.removeAll()
    }

    public func didRequest(_ path: String) -> Bool {
        requestHistory.contains { $0.path == path }
    }
}
