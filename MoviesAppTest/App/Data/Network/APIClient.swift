import Foundation

protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws -> Data
}

final class APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let interceptors: [RequestInterceptor]

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = .apiDecoder,
        interceptors: [RequestInterceptor] = []
    ) {
        self.session = session
        self.decoder = decoder
        self.interceptors = interceptors
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await request(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func request(_ endpoint: Endpoint) async throws -> Data {
        var urlRequest = try endpoint.asURLRequest()

        for interceptor in interceptors {
            urlRequest = try await interceptor.intercept(urlRequest)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}
