import Foundation
import ArgumentParser

struct ListingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "listings")

    @Option(help: "Page number")
    var page: Int = 1

    @Option(help: "Category filter")
    var category: ListingCategory?

    @Option(name: .long, help: "Search query")
    var query: String?

    func run() async throws {
        let api = APIClient()

        do {
            let filter = ListingsFilter(page: page, category: category, query: query)
            let response = try await api.getListings(
                page: filter.page,
                category: filter.category,
                query: filter.normalizedQuery
            )

            guard !response.items.isEmpty else {
                print("No listings found.")
                return
            }

            let hasFilters = category != nil || !(filter.normalizedQuery ?? "").isEmpty
            let title = hasFilters
                ? "Listings (\(response.totalCount) results)"
                : "Listings (page \(response.page)/\(response.totalPages) — \(response.totalCount) results)"

            render {
                title
                rule(100)
                "\(cell("ID", width: 38)) \(cell("Title", width: 20)) \(cell("Price", width: 10)) \(cell("Category", width: 12)) \(cell("Seller", width: 12))"
                for listing in response.items {
                    "\(cell(listing.id.uuidString, width: 38)) \(cell(listing.title, width: 20)) \(cell(formatPrice(listing.price), width: 10)) \(cell(listing.category.rawValue, width: 12)) \(cell(listing.seller.username, width: 12))"
                }
                if response.page < response.totalPages {
                    rule(100)
                    "Next page: swiftmarket listings --page \(response.page + 1)"
                }
            }
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}

struct ListingCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "listing")

    @Argument(help: "Listing id")
    var id: UUID

    func run() async throws {
        let api = APIClient()

        do {
            let listing = try await api.getListing(id: id)

            render {
                listing.title
                rule(41)
                "Price:       \(formatPrice(listing.price))"
                "Category:    \(listing.category.rawValue)"
                "Description: \(listing.description)"
                "Seller:      \(listing.seller.username) (\(listing.seller.email))"
                "Posted:      \(formatDate(listing.createdAt))"
            }
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}

struct PostCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "post")

    @Option(help: "Listing title")
    var title: String

    @Option(name: .customLong("desc"), help: "Listing description")
    var description: String

    @Option(help: "Price")
    var price: Double

    @Option(help: "Category")
    var category: ListingCategory

    @Option(name: .customLong("seller"), help: "Seller user id")
    var sellerID: UUID

    func run() async throws {
        let api = APIClient()

        do {
            let draft = CreateListingDraft(
                title: title,
                description: description,
                price: price,
                category: category,
                sellerID: sellerID
            )

            let listing = try await api.createListing(try draft.toRequest())

            render {
                "Listing created successfully."
                "ID:          \(listing.id.uuidString)"
                "Title:       \(listing.title)"
                "Price:       \(formatPrice(listing.price))"
                "Category:    \(listing.category.rawValue)"
            }
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}

struct DeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete")

    @Argument(help: "Listing id")
    var id: UUID

    func run() async throws {
        let api = APIClient()

        do {
            let listing = try await api.getListing(id: id)
            try await api.deleteListing(id: id)
            print("Listing \"\(listing.title)\" deleted.")
        } catch {
            handleAPIError(error)
            throw ExitCode.failure
        }
    }
}