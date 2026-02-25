import Foundation

struct Movie: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let releaseDate: Date?
    let voteAverage: Double
}

extension Movie {
    static let placeholder = Movie(
        id: 0,
        title: "Placeholder Title",
        overview: "Placeholder overview for shimmer loading state.",
        posterPath: nil,
        releaseDate: nil,
        voteAverage: 0
    )
}
