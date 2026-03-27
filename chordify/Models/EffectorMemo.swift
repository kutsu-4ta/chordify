import Foundation
import SwiftData

@Model final class EffectorMemo {
    @Attribute(.unique) var id: UUID
    var text: String
    var knobSettings: String
    var section: LyricsSection?

    init(text: String = "", knobSettings: String = "", section: LyricsSection? = nil) {
        id = UUID()
        self.text = text
        self.knobSettings = knobSettings
        self.section = section
    }
}
