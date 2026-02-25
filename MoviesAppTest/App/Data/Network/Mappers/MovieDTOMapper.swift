import Foundation

enum MovieDTOMapper {
    static func toDomain(_ dto: MovieDTO) -> Movie {
        Movie(
            id: dto.id,
            title: dto.title,
            overview: dto.overview,
            posterPath: dto.posterPath,
            releaseDate: dto.releaseDate.flatMap { DateFormatter.apiDate.date(from: $0) },
            voteAverage: dto.voteAverage
        )
    }
}
