# APIClient

Lightweight, type-safe HTTP networking for Swift using async/await.

## Features

- Actor-based thread safety
- Typed throws (Swift 6)
- Retry with exponential backoff
- Mock client for testing

## Installation

```swift
.package(url: "https://github.com/smith477/api-client.git", from: "1.0.0")
```

## Usage

```swift
// Define endpoint
enum UserEndpoint: Endpoint {
    case list
    case detail(id: Int)
    
    var path: String {
        switch self {
        case .list: return "/users"
        case .detail(let id): return "/users/\(id)"
        }
    }
}

// Make request
let client = APIClient(baseURL: URL(string: "https://api.example.com")!)
let users: [User] = try await client.send(UserEndpoint.list)
```

## Error Handling

```swift
do {
    let user: User = try await client.send(UserEndpoint.detail(id: 123))
} catch let error as APIError {
    switch error {
    case .notFound: print("Not found")
    case .unauthorized: print("Unauthorized")
    case .serverError(let code): print("Server error: \(code)")
    default: print(error.localizedDescription)
    }
}
```

## Testing

```swift
let mock = MockAPIClient()
await mock.stub("/users/1", with: User(id: 1, name: "John"))

let user: User = try await mock.send(UserEndpoint.detail(id: 1))
```

## License

MIT License. See [LICENSE](LICENSE) for details.
