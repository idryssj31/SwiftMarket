import Foundation
import ArgumentParser

enum CLIError: Error {
    case message(String)
}

extension UUID: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(uuidString: argument)
    }
}

@propertyWrapper
struct Trimmed {
    private var value: String = ""

    var wrappedValue: String {
        get { value }
        set { value = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    init(wrappedValue: String) {
        self.value = wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@propertyWrapper
struct Clamped<T: Comparable> {
    private var value: T
    private let range: ClosedRange<T>

    var wrappedValue: T {
        get { value }
        set { value = min(max(range.lowerBound, newValue), range.upperBound) }
    }

    init(wrappedValue: T, _ range: ClosedRange<T>) {
        self.range = range
        self.value = min(max(range.lowerBound, wrappedValue), range.upperBound)
    }
}

@propertyWrapper
struct Validated<T> {
    private var value: T
    private let validation: (T) -> Bool
    private(set) var isValid: Bool

    var wrappedValue: T {
        get { value }
        set {
            isValid = validation(newValue)
            if isValid {
                value = newValue
            }
        }
    }

    var projectedValue: Bool {
        isValid
    }

    init(wrappedValue: T, validation: @escaping (T) -> Bool) {
        self.validation = validation
        self.value = wrappedValue
        self.isValid = validation(wrappedValue)
    }
}

@resultBuilder
enum LineBuilder {
    static func buildBlock(_ components: [String]...) -> [String] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ expression: String) -> [String] {
        [expression]
    }

    static func buildExpression(_ expression: [String]) -> [String] {
        expression
    }

    static func buildOptional(_ component: [String]?) -> [String] {
        component ?? []
    }

    static func buildEither(first component: [String]) -> [String] {
        component
    }

    static func buildEither(second component: [String]) -> [String] {
        component
    }

    static func buildArray(_ components: [[String]]) -> [String] {
        components.flatMap { $0 }
    }
}

func render(@LineBuilder _ content: () -> [String]) {
    print(content().joined(separator: "\n"))
}

func printError(_ message: String) {
    fputs("Error: \(message)\n", stderr)
}

func handleAPIError(_ error: Error) {
    if let apiError = error as? APIError {
        printError(apiError.message)
        return
    }

    if let cliError = error as? CLIError {
        switch cliError {
        case .message(let message):
            printError(message)
        }
        return
    }

    printError(error.localizedDescription)
}

func rule(_ width: Int = 65) -> String {
    String(repeating: "─", count: width)
}

func formatDate(_ date: Date?) -> String {
    guard let date else { return "N/A" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

func formatPrice(_ price: Double) -> String {
    String(format: "%.2f€", price)
}

func cell(_ value: String, width: Int) -> String {
    if value.count >= width {
        return String(value.prefix(max(0, width - 1))) + "…"
    }
    return value.padding(toLength: width, withPad: " ", startingAt: 0)
}

struct CreateUserDraft {
    @Trimmed var username: String = ""
    @Validated(validation: { $0.contains("@") }) var email: String = ""

    init(username: String, email: String) {
        self.username = username
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func toRequest() throws -> CreateUserRequest {
        guard !username.isEmpty else {
            throw CLIError.message("Username must not be empty.")
        }

        guard $email else {
            throw CLIError.message("Email must be valid.")
        }

        return CreateUserRequest(username: username, email: email)
    }
}

struct CreateListingDraft {
    @Trimmed var title: String = ""
    @Trimmed var description: String = ""
    @Validated(validation: { $0 > 0 }) var price: Double = 0

    let category: ListingCategory
    let sellerID: UUID

    init(title: String, description: String, price: Double, category: ListingCategory, sellerID: UUID) {
        self.title = title
        self.description = description
        self.price = price
        self.category = category
        self.sellerID = sellerID
    }

    func toRequest() throws -> CreateListingRequest {
        guard !title.isEmpty else {
            throw CLIError.message("Title must not be empty.")
        }

        guard !description.isEmpty else {
            throw CLIError.message("Description must not be empty.")
        }

        guard $price else {
            throw CLIError.message("Price must be greater than 0.")
        }

        return CreateListingRequest(
            title: title,
            description: description,
            price: price,
            category: category,
            sellerID: sellerID
        )
    }
}

struct ListingsFilter {
    @Clamped(1...999) var page: Int = 1
    let category: ListingCategory?
    @Trimmed var query: String = ""

    init(page: Int, category: ListingCategory?, query: String?) {
        self.page = page
        self.category = category
        self.query = query ?? ""
    }

    var normalizedQuery: String? {
        query.isEmpty ? nil : query
    }
}