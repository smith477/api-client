// URLProtocolStub.swift
//
@testable import APIClient
import Foundation

// MARK: - URLProtocol Stub for Integration Tests

public final class URLProtocolStub: URLProtocol {
    public nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override public class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: APIError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override public func stopLoading() {}
}

// MARK: - Test URLSession Configuration

public extension URLSessionConfiguration {
    static var stubbed: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return config
    }
}

// MARK: - Response Builders

public extension URLProtocolStub {
    static func stubSuccess<T: Encodable>(
        _ response: T,
        statusCode: Int = 200,
        encoder: JSONEncoder = .init()
    ) {
        requestHandler = { request in
            let data = try encoder.encode(response)
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (httpResponse, data)
        }
    }

    static func stubError(statusCode: Int, data: Data = Data()) {
        requestHandler = { request in
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (httpResponse, data)
        }
    }

    static func stubNetworkError(_ error: Error) {
        requestHandler = { _ in
            throw error
        }
    }

    static func reset() {
        requestHandler = nil
    }
}
