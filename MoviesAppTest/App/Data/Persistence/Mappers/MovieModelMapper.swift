import Foundation

enum MovieModelMapper {
    static func toDomain(_ model: MovieModel) -> Movie {
        Movie(
            id: model.id,
            title: model.title,
            overview: model.overview,
            posterPath: model.posterPath,
            releaseDate: model.releaseDate,
            voteAverage: model.voteAverage
        )
    }

    static func toModel(_ entity: Movie) -> MovieModel {
        MovieModel(
            id: entity.id,
            title: entity.title,
            overview: entity.overview,
            posterPath: entity.posterPath,
            releaseDate: entity.releaseDate,
            voteAverage: entity.voteAverage
        )
    }
}
