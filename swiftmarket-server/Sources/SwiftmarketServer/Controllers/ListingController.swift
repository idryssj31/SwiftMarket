import Fluent
import Vapor

struct ListingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let listings = routes.grouped("listings")

        listings.get(use: index)
        listings.post(use: create)
        listings.get(":id", use: show)
        listings.delete(":id", use: delete)
    }

    func index(req: Request) async throws -> PagedListingResponse {
        let query = try req.query.decode(ListingListQuery.self)

        let page = max(query.page ?? 1, 1)
        let per = min(max(query.per ?? 10, 1), 20)

        if let category = query.category, !CreateListingRequest.allowedCategories.contains(category) {
            throw Abort(.unprocessableEntity, reason: "Invalid category filter.")
        }

        let totalCount = try await makeBaseQuery(on: req, using: query).count()
        let totalPages = max(1, Int(ceil(Double(totalCount) / Double(per))))
        let start = (page - 1) * per
        let end = start + per

        let listings = try await makeBaseQuery(on: req, using: query)
            .sort(\.$createdAt, .descending)
            .range(start..<end)
            .all()

        return try PagedListingResponse(
            items: listings.map(ListingResponse.init),
            page: page,
            totalPages: totalPages,
            totalCount: totalCount
        )
    }

    func create(req: Request) async throws -> Response {
    do {
        try CreateListingRequest.validate(content: req)
    } catch {
        throw Abort(.unprocessableEntity, reason: error.localizedDescription)
    }

    let payload = try req.content.decode(CreateListingRequest.self)
    try payload.validateCategory()

    guard let seller = try await User.find(payload.sellerID, on: req.db) else {
        throw Abort(.notFound, reason: "Seller not found.")
    }

    let listing = Listing(
        title: payload.title,
        description: payload.description,
        price: payload.price,
        category: payload.category,
        sellerID: try seller.requireID()
    )

    try await listing.save(on: req.db)
    try await listing.$seller.load(on: req.db)

    let body = try ListingResponse(listing: listing)
    return try await body.encodeResponse(status: .created, for: req)
    }

    func show(req: Request) async throws -> ListingResponse {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid listing id.")
        }

        guard let listing = try await Listing.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$seller)
            .first()
        else {
            throw Abort(.notFound, reason: "Listing not found.")
        }

        return try ListingResponse(listing: listing)
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid listing id.")
        }

        guard let listing = try await Listing.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Listing not found.")
        }

        try await listing.delete(on: req.db)
        return .noContent
    }

    private func makeBaseQuery(on req: Request, using query: ListingListQuery) -> QueryBuilder<Listing> {
        let builder = Listing.query(on: req.db).with(\.$seller)

        if let category = query.category, !category.isEmpty {
            builder.filter(\.$category == category)
        }

        if let q = query.q?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            builder.group(.or) { group in
                group.filter(\.$title ~~ q)
                group.filter(\.$description ~~ q)
            }
        }

        return builder
    }
}