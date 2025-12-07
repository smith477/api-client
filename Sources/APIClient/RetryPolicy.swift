//  RetryPolicy.swift

import Foundation

public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let retryableErrors: Set<RetryableError>
    
    public enum RetryableError: Hashable, Sendable {
        case networkError
        case serverError
        case timeout
    }
    
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        retryableErrors: Set<RetryableError> = [.networkError, .serverError, .timeout]
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.retryableErrors = retryableErrors
    }
    
    public static let `default` = RetryPolicy()
    public static let none = RetryPolicy(maxRetries: 0)
    
    public func delay(for attempt: Int) -> TimeInterval {
        baseDelay * pow(2.0, Double(attempt - 1))
    }
    
    public func shouldRetry(_ error: APIError) -> Bool {
        switch error {
        case .networkError:
            return retryableErrors.contains(.networkError)
        case .serverError:
            return retryableErrors.contains(.serverError)
        default:
            return false
        }
    }
}
