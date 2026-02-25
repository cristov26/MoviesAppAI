import Foundation

enum AccessibilityID {
    enum MovieList {
        static let searchField = "movieList.searchField"
        static let movieCell = "movieList.movieCell"
        static let refreshButton = "movieList.refreshButton"
    }

    enum MovieDetail {
        static let titleLabel = "movieDetail.titleLabel"
        static let overviewLabel = "movieDetail.overviewLabel"
        static let posterImage = "movieDetail.posterImage"
    }

    enum Common {
        static let errorView = "common.errorView"
        static let retryButton = "common.retryButton"
    }
}
