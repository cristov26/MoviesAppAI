import Foundation

extension NetworkError {
    func toDomainError() -> DomainError {
        switch self {
        case .noConnection, .timeout:
            return .noConnectivity
        case .httpError(let statusCode, _):
            switch statusCode {
            case 401, 403:
                return .unauthorized
            case 404:
                return .notFound
            default:
                return .serverError
            }
        case .invalidResponse, .decodingFailed:
            return .serverError
        }
    }
}
