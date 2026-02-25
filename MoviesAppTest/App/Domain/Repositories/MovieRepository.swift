import Foundation

protocol MovieRepository: Sendable {
    func fetchPopularMovies(cursor: String?, limit: Int) async throws -> PaginatedResult<Movie>
    func fetchMovieDetail(id: Int) async throws -> MovieDetail
    func fetchCachedPopularMovies() async throws -> [Movie]
    func fetchCachedMovieDetail(id: Int) async throws -> MovieDetail?
}
