import SwiftUI

struct MovieListView: View {
    @State var viewModel: MovieListViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading, .loaded:
                content
                    .shimmering(active: viewModel.isLoading)
            case .error(let message):
                ErrorView(message: message) {
                    Task { await viewModel.onAppear() }
                }
                    .accessibilityIdentifier(AccessibilityID.Common.errorView)
            }
        }
        .navigationTitle(String(localized: "movie_list.title", comment: "Movie list title"))
        .task { await viewModel.onAppear() }
    }

    private var content: some View {
        List {
            ForEach(Array(viewModel.displayMovies.enumerated()), id: \.element.id) { index, movie in
                MovieRow(movie: movie)
                    .onTapGesture { viewModel.select(movie: movie) }
                    .accessibilityIdentifier("\(AccessibilityID.MovieList.movieCell)_\(index)")
                    .task { await viewModel.loadMoreIfNeeded(currentItem: movie) }
                    .hideListSeparators()
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .refreshable { await viewModel.refresh() }
    }
}

#Preview("Loading") {
    let vm = MovieListViewModel(
        fetchPopularMovies: PreviewFetchPopularMoviesUseCaseMock.failure(),
        onSelectMovie: { _ in }
    )
    MovieListView(viewModel: vm)
}

#Preview("Loaded") {
    let vm = MovieListViewModel(
        fetchPopularMovies: PreviewFetchPopularMoviesUseCaseMock.success(PaginatedResult(items: Movie.previewSamples, nextCursor: nil, hasMore: false)),
        onSelectMovie: { _ in }
    )
    MovieListView(viewModel: vm)
}
