import Foundation

struct AuthInterceptor: RequestInterceptor {
    let tokenProvider: TokenProviderProtocol

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        let token = try await tokenProvider.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
