import Foundation

protocol FetchMovieDetailUseCaseProtocol: Sendable {
    func execute(id: Int) async throws -> MovieDetail
}

final class FetchMovieDetailUseCase: FetchMovieDetailUseCaseProtocol {
    private let repository: MovieRepository

    init(repository: MovieRepository) {
        self.repository = repository
    }

    func execute(id: Int) async throws -> MovieDetail {
        try await repository.fetchMovieDetail(id: id)
    }
}
