// APIClientTests.swift

@testable import APIClient
import Foundation
import Testing

// MARK: - Test Endpoint

struct TestEndpoint: Endpoint {
    var path: String
    var method: HTTPMethod = .GET
    var headers: [String: String]?
    var queryItems: [URLQueryItem]?
    var body: Data?
}

struct TestResponse: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

// MARK: - APIClient Tests

@Suite(.serialized)
struct APIClientTests {
    let baseURL = URL(string: "https://api.example.com")!

    @Test
    func successfulGETRequest() async throws {
        let session = URLSession(configuration: .stubbed)
        let client = APIClient(baseURL: baseURL, session: session)

        let expected = TestResponse(id: 1, name: "Test")
        URLProtocolStub.stubSuccess(expected)

        let endpoint = TestEndpoint(path: "/users/1")
        let result: TestResponse = try await client.send(endpoint, responseType: TestResponse.self)

        #expect(result == expected)
    }

    @Test
    func handlesNotFoundError() async throws {
        let session = URLSession(configuration: .stubbed)
        let client = APIClient(baseURL: baseURL, session: session)

        URLProtocolStub.stubError(statusCode: 404)

        let endpoint = TestEndpoint(path: "/users/999")

        await #expect(throws: APIError.notFound) {
            _ = try await client.send(endpoint, responseType: TestResponse.self)
        }
    }

    @Test
    func handlesUnauthorizedError() async throws {
        let session = URLSession(configuration: .stubbed)
        let client = APIClient(baseURL: baseURL, session: session)

        URLProtocolStub.stubError(statusCode: 401)

        let endpoint = TestEndpoint(path: "/protected")

        await #expect(throws: APIError.unauthorized) {
            _ = try await client.send(endpoint, responseType: TestResponse.self)
        }
    }

    @Test
    func handlesServerError() async throws {
        let session = URLSession(configuration: .stubbed)
        let client = APIClient(baseURL: baseURL, session: session)

        URLProtocolStub.stubError(statusCode: 500)

        let endpoint = TestEndpoint(path: "/broken")

        await #expect(throws: APIError.serverError(500)) {
            _ = try await client.send(endpoint, responseType: TestResponse.self)
        }
    }

    @Test
    func handlesDecodingError() async throws {
        let session = URLSession(configuration: .stubbed)
        let client = APIClient(baseURL: baseURL, session: session)

        URLProtocolStub.requestHandler = { request in
            let data = "invalid json".data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let endpoint = TestEndpoint(path: "/users/1")

        await #expect {
            _ = try await client.send(endpoint, responseType: TestResponse.self)
        } throws: { error in
            guard case .decodingFailed = error as? APIError else {
                return false
            }
            return true
        }
    }
}

// MARK: - MockAPIClient Tests

@Suite
struct MockAPIClientTests {
    @Test
    func stubsResponses() async throws {
        let mock = MockAPIClient()
        let expected = TestResponse(id: 42, name: "Mocked")

        await mock.stub("/users/42", with: expected)

        let endpoint = TestEndpoint(path: "/users/42")
        let result: TestResponse = try await mock.send(endpoint, responseType: TestResponse.self)

        #expect(result == expected)
    }

    @Test
    func stubsErrors() async throws {
        let mock = MockAPIClient()

        await mock.stubError("/fail", with: .unauthorized)

        let endpoint = TestEndpoint(path: "/fail")

        await #expect(throws: APIError.unauthorized) {
            _ = try await mock.send(endpoint, responseType: TestResponse.self)
        }
    }

    @Test
    func tracksRequestHistory() async throws {
        let mock = MockAPIClient()
        let response = TestResponse(id: 1, name: "Test")

        await mock.stub("/users/1", with: response)

        let endpoint = TestEndpoint(path: "/users/1")
        _ = try await mock.send(endpoint, responseType: TestResponse.self)

        let didRequest = await mock.didRequest("/users/1")
        #expect(didRequest)
    }
}

// MARK: - Endpoint Tests

@Suite
struct EndpointTests {
    let baseURL = URL(string: "https://api.example.com")!

    @Test
    func buildsURLWithPath() throws {
        let endpoint = TestEndpoint(path: "/users")
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://api.example.com/users")
    }

    @Test
    func buildsURLWithQueryItems() throws {
        let endpoint = TestEndpoint(
            path: "/search",
            queryItems: [
                URLQueryItem(name: "q", value: "swift"),
                URLQueryItem(name: "page", value: "1"),
            ]
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString.contains("q=swift") == true)
        #expect(request.url?.absoluteString.contains("page=1") == true)
    }

    @Test
    func setsHTTPMethod() throws {
        let endpoint = TestEndpoint(path: "/users", method: .POST)
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.httpMethod == "POST")
    }

    @Test
    func setsContentTypeForBody() throws {
        let body = try JSONEncoder().encode(TestResponse(id: 1, name: "New"))
        let endpoint = TestEndpoint(path: "/users", method: .POST, body: body)
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}
