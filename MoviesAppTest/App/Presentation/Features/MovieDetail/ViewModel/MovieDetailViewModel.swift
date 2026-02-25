import Foundation
import Observation

@MainActor
@Observable
final class MovieDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(MovieDetail)
        case error(String)
    }

    private(set) var state: State = .loading
    private let movieId: Int
    private let fetchMovieDetail: FetchMovieDetailUseCaseProtocol

    init(movieId: Int, fetchMovieDetail: FetchMovieDetailUseCaseProtocol) {
        self.movieId = movieId
        self.fetchMovieDetail = fetchMovieDetail
    }

    func onAppear() async {
        state = .loading
        do {
            let detail = try await fetchMovieDetail.execute(id: movieId)
            state = .loaded(detail)
        } catch let error as DomainError {
            state = .error(error.localizedDescription)
        } catch {
            state = .error(DomainError.unknown(error.localizedDescription).localizedDescription)
        }
    }

    var displayDetail: MovieDetail {
        switch state {
        case .loaded(let detail):
            return detail
        default:
            return .placeholder
        }
    }

    var isLoading: Bool { state == .loading }
}
