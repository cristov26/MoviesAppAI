import Foundation

protocol TokenProviderProtocol: Sendable {
    func accessToken() async throws -> String
}

final class StaticTokenProvider: TokenProviderProtocol {
    private let token: String

    init(token: String) {
        self.token = token
    }

    func accessToken() async throws -> String {
        token
    }
}
