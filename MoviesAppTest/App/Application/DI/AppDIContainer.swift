import Foundation
import SwiftData

@MainActor
final class AppDIContainer {
    private let modelContainer: ModelContainer
    private lazy var store = SwiftDataStore(container: modelContainer)
    private lazy var tokenProvider: TokenProviderProtocol = StaticTokenProvider(token: AppConfiguration.apiToken)
    private lazy var apiClient: APIClientProtocol = APIClient(
        interceptors: [AuthInterceptor(tokenProvider: tokenProvider)]
    )

    init() {
        self.modelContainer = try! ModelContainer(for: MovieModel.self, GenreModel.self)
    }

    func makeMovieRepository() -> MovieRepository {
        DefaultMovieRepository(apiClient: apiClient, store: store)
    }

    func makeFetchPopularMoviesUseCase() -> FetchPopularMoviesUseCaseProtocol {
        FetchPopularMoviesUseCase(repository: makeMovieRepository())
    }

    func makeFetchMovieDetailUseCase() -> FetchMovieDetailUseCaseProtocol {
        FetchMovieDetailUseCase(repository: makeMovieRepository())
    }

    func makeFeatureFlagProvider() -> FeatureFlagProviderProtocol {
        CompositeFeatureFlagProvider(
            remote: nil,
            local: LocalFeatureFlagProvider()
        )
    }
}
