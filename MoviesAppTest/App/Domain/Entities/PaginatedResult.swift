import Foundation

struct PaginatedResult<T: Sendable>: Sendable {
    let items: [T]
    let nextCursor: String?
    let hasMore: Bool
}
