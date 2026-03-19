import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")

        users.post(use: create)
        users.get(use: index)
        users.get(":id", use: show)
        users.get(":id", "listings", use: listings)
    }

    func create(req: Request) async throws -> Response {
        try CreateUserRequest.validate(content: req)
        let payload = try req.content.decode(CreateUserRequest.self)

        let existing = try await User.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$username == payload.username)
                group.filter(\.$email == payload.email)
            }
            .first()

        if existing != nil {
            throw Abort(.conflict, reason: "A user with this username or email already exists.")
        }

        let user = User(username: payload.username, email: payload.email)
        try await user.save(on: req.db)

        let body = try UserResponse(user: user)
        return try await body.encodeResponse(status: .created, for: req)
    }

    func index(req: Request) async throws -> [UserResponse] {
        let users = try await User.query(on: req.db)
            .sort(\.$createdAt, .ascending)
            .all()

        return try users.map(UserResponse.init)
    }

    func show(req: Request) async throws -> UserResponse {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user id.")
        }

        guard let user = try await User.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        return try UserResponse(user: user)
    }

    func listings(req: Request) async throws -> [ListingResponse] {
        guard let userID = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user id.")
        }

        guard try await User.find(userID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let listings = try await Listing.query(on: req.db)
            .filter(\.$seller.$id == userID)
            .with(\.$seller)
            .sort(\.$createdAt, .descending)
            .all()

        return try listings.map(ListingResponse.init)
    }
}