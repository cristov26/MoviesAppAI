import Foundation

enum DomainError: LocalizedError, Equatable {
    case notFound
    case unauthorized
    case serverError
    case noConnectivity
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return String(localized: "error.not_found", comment: "Requested resource not found")
        case .unauthorized:
            return String(localized: "error.unauthorized", comment: "Session expired")
        case .serverError:
            return String(localized: "error.server", comment: "Server error")
        case .noConnectivity:
            return String(localized: "error.no_connectivity", comment: "No internet connection")
        case .unknown(let detail):
            return detail
        }
    }
}
