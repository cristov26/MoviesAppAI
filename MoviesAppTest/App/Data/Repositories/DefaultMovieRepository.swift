import Foundation
import SwiftData

final class DefaultMovieRepository: MovieRepository {
    private let apiClient: APIClientProtocol
    private let store: SwiftDataStore

    init(apiClient: APIClientProtocol, store: SwiftDataStore) {
        self.apiClient = apiClient
        self.store = store
    }

    func fetchPopularMovies(cursor: String?, limit: Int) async throws -> PaginatedResult<Movie> {
        let page = Int(cursor ?? "1") ?? 1
        do {
            let response: PaginatedResponse<MovieDTO> = try await apiClient.request(MovieEndpoints.popular(page: page))
            let movies = response.results.map(MovieDTOMapper.toDomain)
            await cacheMovies(movies)
            return PaginatedResult(items: movies, nextCursor: response.nextCursor, hasMore: response.nextCursor != nil)
        } catch let error as NetworkError {
            if case .noConnection = error {
                let cached = try await fetchCachedPopularMovies()
                return PaginatedResult(items: cached, nextCursor: nil, hasMore: false)
            }
            throw error.toDomainError()
        } catch {
            throw DomainError.unknown(error.localizedDescription)
        }
    }

    func fetchMovieDetail(id: Int) async throws -> MovieDetail {
        do {
            let dto: MovieDetailDTO = try await apiClient.request(MovieEndpoints.detail(id: id))
            let detail = MovieDetailDTOMapper.toDomain(dto)
            return detail
        } catch let error as NetworkError {
            if case .noConnection = error, let cached = try await fetchCachedMovieDetail(id: id) {
                return cached
            }
            throw error.toDomainError()
        } catch {
            throw DomainError.unknown(error.localizedDescription)
        }
    }

    func fetchCachedPopularMovies() async throws -> [Movie] {
        let descriptor = FetchDescriptor<MovieModel>(sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)])
        return try await MainActor.run {
            let cached = try store.fetch(descriptor)
            return cached.map(MovieModelMapper.toDomain)
        }
    }

    func fetchCachedMovieDetail(id: Int) async throws -> MovieDetail? {
        let descriptor = FetchDescriptor<MovieModel>(predicate: #Predicate { $0.id == id })
        return try await MainActor.run {
            let cached = try store.fetch(descriptor)
            return cached.first.map { movie in
                MovieDetail(
                    id: movie.id,
                    title: movie.title,
                    overview: movie.overview,
                    posterPath: movie.posterPath,
                    backdropPath: nil,
                    releaseDate: movie.releaseDate,
                    runtimeMinutes: nil,
                    genres: [],
                    voteAverage: movie.voteAverage
                )
            }
        }
    }

    private func cacheMovies(_ movies: [Movie]) async {
        await MainActor.run {
            movies.forEach { store.insert(MovieModelMapper.toModel($0)) }
            try? store.save()
        }
    }
}
