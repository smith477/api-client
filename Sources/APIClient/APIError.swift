// APIError.swift

import Foundation

public enum APIError: Error, Sendable, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingFailed(String)
    case networkError(String)
    case unauthorized
    case notFound
    case serverError(Int)

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.notFound, .notFound):
            return true
        case let (.httpError(lCode, _), .httpError(rCode, _)):
            return lCode == rCode
        case let (.decodingFailed(lMsg), .decodingFailed(rMsg)):
            return lMsg == rMsg
        case let (.networkError(lMsg), .networkError(rMsg)):
            return lMsg == rMsg
        case let (.serverError(lCode), .serverError(rCode)):
            return lCode == rCode
        default:
            return false
        }
    }
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case let .httpError(statusCode, _):
            return "HTTP error: \(statusCode)"
        case let .decodingFailed(message):
            return "Failed to decode response: \(message)"
        case let .networkError(message):
            return "Network error: \(message)"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case .notFound:
            return "Resource not found"
        case let .serverError(code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - Status Code Mapping

extension APIError {
    static func fromStatusCode(_ code: Int, data: Data? = nil) -> APIError? {
        switch code {
        case 200 ..< 300:
            return nil
        case 401:
            return .unauthorized
        case 404:
            return .notFound
        case 500 ..< 600:
            return .serverError(code)
        default:
            return .httpError(statusCode: code, data: data)
        }
    }
}
