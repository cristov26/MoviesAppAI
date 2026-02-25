import SwiftUI

struct MovieDetailView: View {
    @State var viewModel: MovieDetailViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading, .error:
                placeholder
                    .shimmering(active: viewModel.isLoading)
            case .loaded:
                detailContent
            }
        }
        .navigationTitle(viewModel.displayDetail.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(Color.gray.opacity(0.4))
                .frame(height: 200)
                .cornerRadius(12)
            Text(viewModel.displayDetail.overview)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CachedAsyncImage(url: backdropURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 220)
                .clipped()

                Text(viewModel.displayDetail.title)
                    .font(.title)
                    .bold()

                Text(viewModel.displayDetail.overview)
                    .font(.body)

                HStack {
                    Text(String(localized: "movie_detail.rating", comment: "Rating label"))
                    Spacer()
                    Text(String(format: "%.1f", viewModel.displayDetail.voteAverage))
                }
                .font(.headline)
            }
            .padding()
        }
    }

    private var backdropURL: URL? {
        guard let path = viewModel.displayDetail.backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }
}

#Preview("Loading") {
    let vm = MovieDetailViewModel(
        movieId: 1,
        fetchMovieDetail: PreviewFetchMovieDetailUseCaseMock.neverLoading
    )
    MovieDetailView(viewModel: vm)
}

#Preview("Loaded") {
    let vm = MovieDetailViewModel(
        movieId: 1,
        fetchMovieDetail: PreviewFetchMovieDetailUseCaseMock.success(MovieDetail.previewSample)
    )
    MovieDetailView(viewModel: vm)
}
