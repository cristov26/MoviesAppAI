import Foundation

#if DEBUG

enum PreviewMockError: Error {
    case forced
}

struct PreviewFetchPopularMoviesUseCaseMock: FetchPopularMoviesUseCaseProtocol {
    enum Mode {
        case success(PaginatedResult<Movie>)
        case failure(Error)
        case never
    }

    let mode: Mode
    let delayNanoseconds: UInt64?

    init(mode: Mode, delayNanoseconds: UInt64? = nil) {
        self.mode = mode
        self.delayNanoseconds = delayNanoseconds
    }

    static let neverLoading = PreviewFetchPopularMoviesUseCaseMock(mode: .never)

    static func success(_ result: PaginatedResult<Movie>, delayNanoseconds: UInt64? = nil) -> PreviewFetchPopularMoviesUseCaseMock {
        PreviewFetchPopularMoviesUseCaseMock(mode: .success(result), delayNanoseconds: delayNanoseconds)
    }

    static func failure(_ error: Error = PreviewMockError.forced) -> PreviewFetchPopularMoviesUseCaseMock {
        PreviewFetchPopularMoviesUseCaseMock(mode: .failure(error))
    }

    func execute(cursor: String?, limit: Int) async throws -> PaginatedResult<Movie> {
        if let delayNanoseconds {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }

        switch mode {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        case .never:
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            }
            throw CancellationError()
        }
    }
}

struct PreviewFetchMovieDetailUseCaseMock: FetchMovieDetailUseCaseProtocol {
    enum Mode {
        case success(MovieDetail)
        case failure(Error)
        case never
    }

    let mode: Mode
    let delayNanoseconds: UInt64?

    init(mode: Mode, delayNanoseconds: UInt64? = nil) {
        self.mode = mode
        self.delayNanoseconds = delayNanoseconds
    }

    static let neverLoading = PreviewFetchMovieDetailUseCaseMock(mode: .never)

    static func success(_ result: MovieDetail, delayNanoseconds: UInt64? = nil) -> PreviewFetchMovieDetailUseCaseMock {
        PreviewFetchMovieDetailUseCaseMock(mode: .success(result), delayNanoseconds: delayNanoseconds)
    }

    static func failure(_ error: Error = PreviewMockError.forced) -> PreviewFetchMovieDetailUseCaseMock {
        PreviewFetchMovieDetailUseCaseMock(mode: .failure(error))
    }

    func execute(id: Int) async throws -> MovieDetail {
        if let delayNanoseconds {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }

        switch mode {
        case .success(let detail):
            return detail
        case .failure(let error):
            throw error
        case .never:
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            }
            throw CancellationError()
        }
    }
}

extension Movie {
    static let previewSamples: [Movie] = [
        Movie(
            id: 603,
            title: "The Matrix",
            overview: "A computer hacker learns about the true nature of reality and his role in the war against its controllers.",
            posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
            releaseDate: Date(timeIntervalSince1970: 922060800),
            voteAverage: 8.2
        ),
        Movie(
            id: 155,
            title: "The Dark Knight",
            overview: "Batman raises the stakes in his war on crime as the Joker emerges in Gotham City.",
            posterPath: "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
            releaseDate: Date(timeIntervalSince1970: 1216080000),
            voteAverage: 8.5
        ),
        Movie(
            id: 278,
            title: "The Shawshank Redemption",
            overview: "Two imprisoned men bond over years, finding solace and eventual redemption through acts of common decency.",
            posterPath: "/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg",
            releaseDate: Date(timeIntervalSince1970: 780019200),
            voteAverage: 8.7
        )
    ]
}

extension MovieDetail {
    static let previewSample = MovieDetail(
        id: 603,
        title: "The Matrix",
        overview: "A computer hacker learns about the true nature of reality and his role in the war against its controllers.",
        posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        backdropPath: "/7u3pxc0K1wx32IleAkLv78MKgrw.jpg",
        releaseDate: Date(timeIntervalSince1970: 922060800),
        runtimeMinutes: 136,
        genres: [Genre(id: 878, name: "Science Fiction"), Genre(id: 28, name: "Action")],
        voteAverage: 8.2
    )
}

#endif
