import Foundation

struct PaginatedResponse<T: Decodable>: Decodable {
    let results: [T]
    let page: Int
    let totalPages: Int

    var nextCursor: String? {
        page < totalPages ? String(page + 1) : nil
    }
}
