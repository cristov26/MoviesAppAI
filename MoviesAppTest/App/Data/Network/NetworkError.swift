import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case noConnection
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let code, _):
            return "Server error (\(code))."
        case .decodingFailed:
            return "Failed to process server response."
        case .noConnection:
            return "No internet connection."
        case .timeout:
            return "Request timed out."
        }
    }
}
