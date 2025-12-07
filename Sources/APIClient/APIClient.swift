// APIClient.swift

import Foundation
import OSLog

public protocol APIClientProtocol: Sendable {
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws(APIError) -> T
}

public actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let retryPolicy: RetryPolicy
    private let logger: Logger

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .init(),
        retryPolicy: RetryPolicy = .default
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.retryPolicy = retryPolicy
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "APIClient", category: "Network")
    }

    public func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws(APIError) -> T {
        let request: URLRequest
        do {
            request = try endpoint.urlRequest(baseURL: baseURL)
        } catch {
            throw .invalidURL
        }

        var lastError: APIError = .invalidResponse

        for attempt in 0...retryPolicy.maxRetries {
            if attempt > 0 {
                let delay = retryPolicy.delay(for: attempt)
                logger.info("Retry attempt \(attempt) after \(delay)s for \(endpoint.path)")
                try? await Task.sleep(for: .seconds(delay))
            }

            do {
                let data = try await performRequest(request, endpoint: endpoint)
                return try decodeResponse(data)
            } catch {
                lastError = error

                if !retryPolicy.shouldRetry(error) {
                    throw error
                }

                logger.warning("Request failed: \(error.localizedDescription), will retry")
            }
        }

        throw lastError
    }

    private func performRequest(_ request: URLRequest, endpoint: Endpoint) async throws(APIError) -> Data {
        logger.debug("→ \(endpoint.method.rawValue) \(endpoint.path)")
        let startTime = CFAbsoluteTimeGetCurrent()

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("✗ Network error: \(error.localizedDescription)")
            throw .networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logger.debug("← \(httpResponse.statusCode) \(endpoint.path) (\(String(format: "%.2f", duration))s)")

        if let error = APIError.fromStatusCode(httpResponse.statusCode, data: data) {
            logger.error("✗ HTTP \(httpResponse.statusCode) for \(endpoint.path)")
            throw error
        }

        return data
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws(APIError) -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("✗ Decoding failed: \(error.localizedDescription)")
            throw .decodingFailed(error.localizedDescription)
        }
    }
}
