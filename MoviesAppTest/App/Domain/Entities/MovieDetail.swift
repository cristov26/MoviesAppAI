import Foundation

struct MovieDetail: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let runtimeMinutes: Int?
    let genres: [Genre]
    let voteAverage: Double
}

extension MovieDetail {
    static let placeholder = MovieDetail(
        id: 0,
        title: "Placeholder Title",
        overview: "Placeholder overview for shimmer loading state.",
        posterPath: nil,
        backdropPath: nil,
        releaseDate: nil,
        runtimeMinutes: nil,
        genres: [],
        voteAverage: 0
    )
}
