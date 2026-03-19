import Foundation

enum APIError: Error {
    case notFound(String)
    case conflict(String)
    case validationFailed(String)
    case serverError(String)
    case connectionFailed
    case decodingError(Error)

    var message: String {
        switch self {
        case .notFound(let message):
            return message
        case .conflict(let message):
            return message
        case .validationFailed(let message):
            return "Validation failed.\n\(message)"
        case .serverError(let message):
            return message
        case .connectionFailed:
            return """
            Could not connect to server at http://localhost:8080.
            Make sure the server is running: swift run in swiftmarket-server/
            """
        case .decodingError(let error):
            return "Failed to decode server response: \(error.localizedDescription)"
        }
    }
}