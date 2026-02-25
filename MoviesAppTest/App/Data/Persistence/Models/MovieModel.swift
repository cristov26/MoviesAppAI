import Foundation
import SwiftData

@Model
final class MovieModel {
    @Attribute(.unique) var id: Int
    var title: String
    var overview: String
    var posterPath: String?
    var releaseDate: Date?
    var voteAverage: Double
    var lastUpdated: Date

    init(
        id: Int,
        title: String,
        overview: String,
        posterPath: String?,
        releaseDate: Date?,
        voteAverage: Double,
        lastUpdated: Date = .now
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.voteAverage = voteAverage
        self.lastUpdated = lastUpdated
    }
}
