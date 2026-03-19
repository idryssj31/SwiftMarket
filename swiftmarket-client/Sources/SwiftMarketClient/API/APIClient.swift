import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol APIEndpoint {
    associatedtype Response: Decodable

    var path: String { get }
    var method: String { get }
    var queryItems: [URLQueryItem] { get }
    func bodyData(using encoder: JSONEncoder) throws -> Data?
}

extension APIEndpoint {
    var queryItems: [URLQueryItem] { [] }

    func bodyData(using encoder: JSONEncoder) throws -> Data? {
        nil
    }
}

struct EmptyResponse: Decodable {}

struct APIClient {
    let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: String = "http://localhost:8080", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func createUser(_ body: CreateUserRequest) async throws -> UserResponse {
        try await send(CreateUserEndpoint(body: body))
    }

    func getUsers() async throws -> [UserResponse] {
        try await send(GetUsersEndpoint())
    }

    func getUser(id: UUID) async throws -> UserResponse {
        try await send(GetUserEndpoint(id: id))
    }

    func getUserListings(userID: UUID) async throws -> [ListingResponse] {
        try await send(GetUserListingsEndpoint(userID: userID))
    }

    func createListing(_ body: CreateListingRequest) async throws -> ListingResponse {
        try await send(CreateListingEndpoint(body: body))
    }

    func getListings(page: Int, category: ListingCategory?, query: String?) async throws -> PagedListingResponse {
        try await send(GetListingsEndpoint(page: page, category: category, query: query))
    }

    func getListing(id: UUID) async throws -> ListingResponse {
        try await send(GetListingEndpoint(id: id))
    }

    func deleteListing(id: UUID) async throws {
        _ = try await send(DeleteListingEndpoint(id: id)) as EmptyResponse
    }

    private func send<E: APIEndpoint>(_ endpoint: E) async throws -> E.Response {
        guard var components = URLComponents(string: baseURL + endpoint.path) else {
            throw APIError.serverError("Invalid base URL.")
        }

        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw APIError.serverError("Could not build URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let data = try endpoint.bodyData(using: encoder) {
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.connectionFailed
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid server response.")
        }

        if (200...299).contains(http.statusCode) {
            if E.Response.self == EmptyResponse.self {
                return EmptyResponse() as! E.Response
            }

            do {
                return try decoder.decode(E.Response.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        }

        let reason = (try? decoder.decode(ServerError.self, from: data).reason)
            ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)

        switch http.statusCode {
        case 404:
            throw APIError.notFound(reason)
        case 409:
            throw APIError.conflict(reason)
        case 422:
            throw APIError.validationFailed(reason)
        default:
            throw APIError.serverError(reason)
        }
    }
}

// MARK: - Endpoints

private struct CreateUserEndpoint: APIEndpoint {
    typealias Response = UserResponse
    let body: CreateUserRequest

    var path: String { "/users" }
    var method: String { "POST" }

    func bodyData(using encoder: JSONEncoder) throws -> Data? {
        try encoder.encode(body)
    }
}

private struct GetUsersEndpoint: APIEndpoint {
    typealias Response = [UserResponse]

    var path: String { "/users" }
    var method: String { "GET" }
}

private struct GetUserEndpoint: APIEndpoint {
    typealias Response = UserResponse
    let id: UUID

    var path: String { "/users/\(id.uuidString)" }
    var method: String { "GET" }
}

private struct GetUserListingsEndpoint: APIEndpoint {
    typealias Response = [ListingResponse]
    let userID: UUID

    var path: String { "/users/\(userID.uuidString)/listings" }
    var method: String { "GET" }
}

private struct CreateListingEndpoint: APIEndpoint {
    typealias Response = ListingResponse
    let body: CreateListingRequest

    var path: String { "/listings" }
    var method: String { "POST" }

    func bodyData(using encoder: JSONEncoder) throws -> Data? {
        try encoder.encode(body)
    }
}

private struct GetListingsEndpoint: APIEndpoint {
    typealias Response = PagedListingResponse

    let page: Int
    let category: ListingCategory?
    let query: String?

    var path: String { "/listings" }
    var method: String { "GET" }

    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "page", value: String(page))]

        if let category {
            items.append(URLQueryItem(name: "category", value: category.rawValue))
        }

        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }

        return items
    }
}

private struct GetListingEndpoint: APIEndpoint {
    typealias Response = ListingResponse
    let id: UUID

    var path: String { "/listings/\(id.uuidString)" }
    var method: String { "GET" }
}

private struct DeleteListingEndpoint: APIEndpoint {
    typealias Response = EmptyResponse
    let id: UUID

    var path: String { "/listings/\(id.uuidString)" }
    var method: String { "DELETE" }
}