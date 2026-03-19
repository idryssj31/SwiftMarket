import Vapor

struct CreateListingRequest: Content, Validatable {
    var title: String
    var description: String
    var price: Double
    var category: String
    var sellerID: UUID

    static let allowedCategories = ["electronics", "clothing", "furniture", "other"]

    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: !.empty)
        validations.add("description", as: String.self, is: !.empty)
        validations.add("price", as: Double.self, is: .range(0.01...Double.greatestFiniteMagnitude))
    }

    func validateCategory() throws {
        guard Self.allowedCategories.contains(category) else {
            throw Abort(
                .unprocessableEntity,
                reason: "Validation failed.\ncategory must be one of: electronics, clothing, furniture, other"
            )
        }
    }
}

struct ListingResponse: Content {
    var id: UUID
    var title: String
    var description: String
    var price: Double
    var category: String
    var seller: UserResponse
    var createdAt: Date?

    init(listing: Listing) throws {
        guard let id = listing.id else {
            throw Abort(.internalServerError, reason: "Listing id is missing.")
        }

        guard let seller = listing.$seller.value else {
            throw Abort(.internalServerError, reason: "Seller relation was not loaded.")
        }

        self.id = id
        self.title = listing.title
        self.description = listing.description
        self.price = listing.price
        self.category = listing.category
        self.seller = try UserResponse(user: seller)
        self.createdAt = listing.createdAt
    }
}

struct PagedListingResponse: Content {
    var items: [ListingResponse]
    var page: Int
    var totalPages: Int
    var totalCount: Int
}

struct ListingListQuery: Content {
    var page: Int?
    var per: Int?
    var category: String?
    var q: String?
}