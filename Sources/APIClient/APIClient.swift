// APIClient.swift

import Foundation

// MARK: - Protocol

public protocol APIClientProtocol: Sendable {
    func send<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T

    func send(_ endpoint: Endpoint) async throws
}

// MARK: - Live Implementation

public actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .init()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    public func send<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType _: T.Type
    ) async throws(APIError) -> T {
        do {
            let data = try await performRequest(endpoint)
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    public func send(_ endpoint: Endpoint) async throws {
        _ = try await performRequest(endpoint)
    }

    private func performRequest(_ endpoint: Endpoint) async throws -> Data {
        let request: URLRequest
        do {
            request = try endpoint.urlRequest(baseURL: baseURL)
        } catch {
            throw APIError.invalidURL
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if let error = APIError.fromStatusCode(httpResponse.statusCode, data: data) {
            throw error
        }

        return data
    }
}
