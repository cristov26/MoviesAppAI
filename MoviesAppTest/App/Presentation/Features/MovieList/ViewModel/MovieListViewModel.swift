import Foundation
import Observation

@MainActor
@Observable
final class MovieListViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var movies: [Movie] = []
    private(set) var isLoadingMore = false

    var isLoading: Bool { state == .loading }

    var displayMovies: [Movie] {
        if case .loading = state { return (0..<8).map { _ in .placeholder } }
        return movies
    }

    private var nextCursor: String?
    private var hasMore = true
    private let pageSize = 20
    private let fetchPopularMovies: FetchPopularMoviesUseCaseProtocol
    private let onSelectMovie: (Int) -> Void

    init(fetchPopularMovies: FetchPopularMoviesUseCaseProtocol, onSelectMovie: @escaping (Int) -> Void) {
        self.fetchPopularMovies = fetchPopularMovies
        self.onSelectMovie = onSelectMovie
    }

    func onAppear() async {
        await loadFirstPage()
    }

    func loadMoreIfNeeded(currentItem: Movie) async {
        guard let lastItem = movies.last,
              lastItem.id == currentItem.id,
              hasMore,
              !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let result = try await fetchPopularMovies.execute(cursor: nextCursor, limit: pageSize)
            movies.append(contentsOf: result.items)
            nextCursor = result.nextCursor
            hasMore = result.hasMore
        } catch {
            // Ignore pagination errors silently.
        }
    }

    func refresh() async {
        await loadFirstPage()
    }

    func select(movie: Movie) {
        onSelectMovie(movie.id)
    }

    private func loadFirstPage() async {
        state = .loading
        nextCursor = nil
        do {
            let result = try await fetchPopularMovies.execute(cursor: nil, limit: pageSize)
            movies = result.items
            nextCursor = result.nextCursor
            hasMore = result.hasMore
            state = .loaded
        } catch let error as DomainError {
            state = .error(error.localizedDescription)
        } catch {
            state = .error(DomainError.unknown(error.localizedDescription).localizedDescription)
        }
    }
}
