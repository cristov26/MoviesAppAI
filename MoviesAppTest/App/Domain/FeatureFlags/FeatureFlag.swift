import Foundation

enum FeatureFlag: String, CaseIterable, Sendable {
    case experimentalSearch = "experimental_search"
    case cachedMovieDetail = "cached_movie_detail"

    var defaultValue: Bool {
        switch self {
        case .experimentalSearch:
            return false
        case .cachedMovieDetail:
            return true
        }
    }
}
