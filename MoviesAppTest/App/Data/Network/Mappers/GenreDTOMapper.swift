import Foundation

enum GenreDTOMapper {
    static func toDomain(_ dto: GenreDTO) -> Genre {
        Genre(id: dto.id, name: dto.name)
    }
}
