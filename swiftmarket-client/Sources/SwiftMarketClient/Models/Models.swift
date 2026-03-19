import Foundation
import ArgumentParser

enum ListingCategory: String, Codable, CaseIterable, ExpressibleByArgument {
    case electronics
    case clothing
    case furniture
    case other
}

struct UserResponse: Codable {
    var id: UUID
    var username: String
    var email: String
    var createdAt: Date?
}

struct CreateUserRequest: Codable {
    var username: String
    var email: String
}

struct ListingResponse: Codable {
    var id: UUID
    var title: String
    var description: String
    var price: Double
    var category: ListingCategory
    var seller: UserResponse
    var createdAt: Date?
}

struct CreateListingRequest: Codable {
    var title: String
    var description: String
    var price: Double
    var category: ListingCategory
    var sellerID: UUID
}

struct PagedListingResponse: Codable {
    var items: [ListingResponse]
    var page: Int
    var totalPages: Int
    var totalCount: Int
}

struct ServerError: Codable {
    var reason: String?
    var error: Bool?
}