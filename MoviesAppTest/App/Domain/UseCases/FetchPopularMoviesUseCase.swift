import Foundation

protocol FetchPopularMoviesUseCaseProtocol: Sendable {
    func execute(cursor: String?, limit: Int) async throws -> PaginatedResult<Movie>
}

final class FetchPopularMoviesUseCase: FetchPopularMoviesUseCaseProtocol {
    private let repository: MovieRepository

    init(repository: MovieRepository) {
        self.repository = repository
    }

    func execute(cursor: String?, limit: Int) async throws -> PaginatedResult<Movie> {
        try await repository.fetchPopularMovies(cursor: cursor, limit: limit)
    }
}
