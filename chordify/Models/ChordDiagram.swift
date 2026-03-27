import Foundation
import SwiftData

@Model final class ChordDiagram {
    @Attribute(.unique) var id: UUID
    var name: String
    var fingering: ChordFingering
    var isGlobal: Bool
    var folder: String // "" = フォルダなし
    var createdAt: Date
    var ownerSong: Song?

    init(
        name: String,
        fingering: ChordFingering = .empty,
        isGlobal: Bool = true,
        folder: String = "",
        ownerSong: Song? = nil
    ) {
        id = UUID()
        self.name = name
        self.fingering = fingering
        self.isGlobal = isGlobal
        self.folder = folder
        createdAt = Date()
        self.ownerSong = ownerSong
    }
}
