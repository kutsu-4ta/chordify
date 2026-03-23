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

    var next: ChordDisplayMode {
        switch self {
        case .custom:      return .diagramOnly
        case .diagramOnly: return .nameOnly
        case .nameOnly:    return .hidden
        case .hidden:      return .custom
        }
    }

    var systemImage: String {
        switch self {
        case .custom:      return "music.note"
        case .diagramOnly: return "rectangle.grid.2x2"
        case .nameOnly:    return "textformat"
        case .hidden:      return "eye.slash"
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

    /// テレプロンプタースクロール速度（pt/秒）
    var prompterSpeed: Double = 80.0

    /// 任意のステータスラベル（例: 練習中、本番OK）
    var statusLabel: String = ""

    /// タイムラインマーカー（正規化位置 0.0〜1.0）
    var teleprompterMarkers: [Double] = []

    // 旧フィールド（後方互換のため残存、UI からは非表示）
    var beatsPerSection: Int
    var scrollSpeedOverride: Double?

    @Relationship(deleteRule: .cascade, inverse: \LyricsSection.song)
    var sections: [LyricsSection] = []

    @Relationship(deleteRule: .cascade, inverse: \ChordDiagram.ownerSong)
    var localChords: [ChordDiagram] = []

    @Relationship(deleteRule: .cascade, inverse: \StructEvent.song)
    var structEvents: [StructEvent] = []

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
