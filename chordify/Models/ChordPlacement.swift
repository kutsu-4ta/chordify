import Foundation

struct ChordPlacement: Codable, Identifiable, Hashable {
    var id: UUID
    var normalizedX: Double  // 0.0〜1.0（セクション行の横位置）
    var chordID: UUID
    var showDiagram: Bool
    var showName: Bool

    init(normalizedX: Double, chordID: UUID, showDiagram: Bool = true, showName: Bool = true) {
        self.id = UUID()
        self.normalizedX = max(0, min(1, normalizedX))
        self.chordID = chordID
        self.showDiagram = showDiagram
        self.showName = showName
    }

    // 既存データ（showDiagram/showName 未保存）との互換性
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        normalizedX = try c.decode(Double.self, forKey: .normalizedX)
        chordID     = try c.decode(UUID.self, forKey: .chordID)
        showDiagram = try c.decodeIfPresent(Bool.self, forKey: .showDiagram) ?? true
        showName    = try c.decodeIfPresent(Bool.self, forKey: .showName)    ?? true
    }

    enum CodingKeys: String, CodingKey {
        case id, normalizedX, chordID, showDiagram, showName
    }
}
