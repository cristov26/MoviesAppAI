import Foundation

enum MovieDetailDTOMapper {
    static func toDomain(_ dto: MovieDetailDTO) -> MovieDetail {
        MovieDetail(
            id: dto.id,
            title: dto.title,
            overview: dto.overview,
            posterPath: dto.posterPath,
            backdropPath: dto.backdropPath,
            releaseDate: dto.releaseDate.flatMap { DateFormatter.apiDate.date(from: $0) },
            runtimeMinutes: dto.runtime,
            genres: dto.genres.map { Genre(id: $0.id, name: $0.name) },
            voteAverage: dto.voteAverage
        )
    }
}
