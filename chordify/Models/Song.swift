import Foundation
import SwiftData

enum ChordDisplayMode: String, Codable, CaseIterable {
    case custom      = "custom"
    case diagramOnly = "diagramOnly"
    case nameOnly    = "nameOnly"
    case hidden      = "hidden"

    var label: String {
        switch self {
        case .custom:      return "カスタム"
        case .diagramOnly: return "ダイアグラムのみ"
        case .nameOnly:    return "コード名のみ"
        case .hidden:      return "非表示"
        }
    }
}

@Model final class Song {
    @Attribute(.unique) var id: UUID
    var title: String
    var bpm: Int
    /// スクロール速度（pt/秒）
    var scrollSpeed: Double
    var isClickEnabled: Bool
    var createdAt: Date

    /// パフォーマンス画面のコード表示モード
    var chordDisplayMode: ChordDisplayMode
    /// カポタスト（0 = なし、1〜12 = フレット番号）
    var capo: Int
    /// メモ
    var memo: String

    // 旧フィールド（後方互換のため残存、UI からは非表示）
    var beatsPerSection: Int
    var scrollSpeedOverride: Double?

    @Relationship(deleteRule: .cascade, inverse: \LyricsSection.song)
    var sections: [LyricsSection] = []

    @Relationship(deleteRule: .cascade, inverse: \ChordDiagram.ownerSong)
    var localChords: [ChordDiagram] = []

    init(
        title: String,
        bpm: Int = 120,
        scrollSpeed: Double = 50.0,
        isClickEnabled: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.bpm = bpm
        self.scrollSpeed = scrollSpeed
        self.isClickEnabled = isClickEnabled
        self.createdAt = Date()
        self.chordDisplayMode = .custom
        self.capo = 0
        self.memo = ""
        self.beatsPerSection = 8
        self.scrollSpeedOverride = nil
    }

    /// Sections sorted by their `order` property
    var sortedSections: [LyricsSection] {
        sections.sorted { $0.order < $1.order }
    }
}
