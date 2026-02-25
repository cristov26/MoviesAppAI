import SwiftUI

struct MovieRow: View {
    let movie: Movie

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier(AccessibilityID.MovieDetail.posterImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .accessibilityIdentifier(AccessibilityID.MovieDetail.titleLabel)
                Text(movie.overview)
                    .font(.subheadline)
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.MovieDetail.overviewLabel)
            }
        }
        .padding(.vertical, 8)
    }

    private var posterURL: URL? {
        guard let path = movie.posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

#Preview("Movie Row") {
    let movie = Movie(
        id: 1,
        title: "Mock Movie",
        overview: "This is a sample overview used for previews.",
        posterPath: nil,
        releaseDate: nil,
        voteAverage: 8.4
    )
    MovieRow(movie: movie)
}
