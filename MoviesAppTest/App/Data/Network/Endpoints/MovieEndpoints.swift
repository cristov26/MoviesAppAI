import Foundation

enum MovieEndpoints {
    static func popular(page: Int) -> Endpoint {
        Endpoint(
            path: "movie/popular",
            method: .get,
            headers: nil,
            queryItems: [URLQueryItem(name: "page", value: "\(page)")],
            body: nil,
            baseURL: AppConfiguration.baseURL
        )
    }

    static func detail(id: Int) -> Endpoint {
        Endpoint(
            path: "movie/\(id)",
            method: .get,
            headers: nil,
            queryItems: nil,
            body: nil,
            baseURL: AppConfiguration.baseURL
        )
    }
}
