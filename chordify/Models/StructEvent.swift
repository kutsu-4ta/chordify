import Foundation
import SwiftData

/// テレプロンプタータイムライン上の構造イベント（Aメロ、サビ、エフェクターメモ等）
@Model final class StructEvent {
    @Attribute(.unique) var id: UUID
    /// 正規化位置（0.0 = 先頭、1.0 = 末尾）
    var position: Double
    /// ラベルテキスト
    var label: String
    /// 親曲（削除時に自動解除）
    var song: Song?

    init(position: Double, label: String) {
        self.id = UUID()
        self.position = max(0, min(1, position))
        self.label = label
    }
}
