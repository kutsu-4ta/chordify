import Foundation
import SwiftData

@Model final class LyricsSection {
    @Attribute(.unique) var id: UUID
    var order: Int
    var lyrics: String
    var chordPlacements: [ChordPlacement]
    var song: Song?

    @Relationship(deleteRule: .cascade, inverse: \EffectorMemo.section)
    var effectorMemo: EffectorMemo?

    init(order: Int, lyrics: String = "", song: Song? = nil) {
        self.id = UUID()
        self.order = order
        self.lyrics = lyrics
        self.chordPlacements = []
        self.song = song
    }
}
