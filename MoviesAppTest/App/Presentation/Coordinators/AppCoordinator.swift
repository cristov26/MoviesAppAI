import SwiftUI
import Observation

@MainActor
@Observable
final class AppCoordinator {
    enum Route: Hashable, Identifiable {
        case movieList
        case movieDetail(Int)

        var id: Self { self }
    }

    var path = NavigationPath()
    var sheet: Route?

    private let diContainer: AppDIContainer

    init(diContainer: AppDIContainer) {
        self.diContainer = diContainer
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        path.removeLast()
    }

    @ViewBuilder
    func view(for route: Route) -> some View {
        switch route {
        case .movieList:
            makeMovieListView()
        case .movieDetail(let id):
            makeMovieDetailView(movieId: id)
        }
    }

    private func makeMovieListView() -> some View {
        let vm = MovieListViewModel(
            fetchPopularMovies: diContainer.makeFetchPopularMoviesUseCase(),
            onSelectMovie: { [weak self] id in self?.push(.movieDetail(id)) }
        )
        return MovieListView(viewModel: vm)
    }

    private func makeMovieDetailView(movieId: Int) -> some View {
        let vm = MovieDetailViewModel(
            movieId: movieId,
            fetchMovieDetail: diContainer.makeFetchMovieDetailUseCase()
        )
        return MovieDetailView(viewModel: vm)
    }
}
