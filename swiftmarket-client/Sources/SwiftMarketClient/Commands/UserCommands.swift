import Foundation
import ArgumentParser

struct CreateUserCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create-user")

    @Option(help: "Username")
    var username: String

    @Option(help: "Email")
    var email: String

    func run() async throws {
        let api = APIClient()

        do {
            let draft = CreateUserDraft(username: username, email: email)
            let user = try await api.createUser(try draft.toRequest())

            render {
                "User created successfully."
                "ID:       \(user.id.uuidString)"
                "Username: \(user.username)"
                "Email:    \(user.email)"
            }
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}

struct UsersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "users")

    func run() async throws {
        let api = APIClient()

        do {
            let users = try await api.getUsers()

            render {
                "Users (\(users.count))"
                rule(82)
                "\(cell("ID", width: 38)) \(cell("Username", width: 12)) \(cell("Email", width: 26))"
                for user in users {
                    "\(cell(user.id.uuidString, width: 38)) \(cell(user.username, width: 12)) \(cell(user.email, width: 26))"
                }
            }
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}

struct UserCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "user")

    @Argument(help: "User id")
    var id: UUID

    func run() async throws {
        let api = APIClient()

        do {
            let user = try await api.getUser(id: id)

            render {
                user.username
                "Email:        \(user.email)"
                "Member since: \(formatDate(user.createdAt))"
            }
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}

struct UserListingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "user-listings")

    @Argument(help: "User id")
    var userID: UUID

    func run() async throws {
        let api = APIClient()

        do {
            let user = try await api.getUser(id: userID)
            let listings = try await api.getUserListings(userID: userID)

            render {
                "Listings by \(user.username) (\(listings.count))"
                rule(82)
                "\(cell("ID", width: 38)) \(cell("Title", width: 20)) \(cell("Price", width: 10)) \(cell("Category", width: 12))"
                for listing in listings {
                    "\(cell(listing.id.uuidString, width: 38)) \(cell(listing.title, width: 20)) \(cell(formatPrice(listing.price), width: 10)) \(cell(listing.category.rawValue, width: 12))"
                }
            }
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}