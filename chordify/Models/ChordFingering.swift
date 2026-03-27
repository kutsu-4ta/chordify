import Foundation

struct StringFingering: Codable, Equatable {
    var fret: Int // -1 = muted, 0 = open, 1+ = absolute fret number
    var finger: Int?

    init(fret: Int = 0, finger: Int? = nil) {
        self.fret = fret
        self.finger = finger
    }

    var isMuted: Bool {
        fret == -1
    }

    var isOpen: Bool {
        fret == 0
    }

    var isPressed: Bool {
        fret >= 1
    }
}

struct ChordFingering: Codable, Equatable {
    /// 6弦: index 0 = low E, index 5 = high e
    var strings: [StringFingering]
    /// ダイアグラム左端のフレット番号（1 = ナット位置）
    var startFret: Int
    /// 表示するフレット数（デフォルト 5）
    var fretCount: Int

    init(strings: [StringFingering] = Array(repeating: StringFingering(), count: 6),
         startFret: Int = 1,
         fretCount: Int = 5)
    {
        self.strings = strings
        self.startFret = max(1, startFret)
        self.fretCount = max(3, fretCount)
    }

    /// 既存データ（fretCount未保存）との互換性
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strings = try c.decode([StringFingering].self, forKey: .strings)
        startFret = try c.decode(Int.self, forKey: .startFret)
        fretCount = try c.decodeIfPresent(Int.self, forKey: .fretCount) ?? 5
    }

    enum CodingKeys: String, CodingKey {
        case strings, startFret, fretCount
    }

    static var empty: ChordFingering {
        ChordFingering()
    }

    // MARK: - Mutations

    mutating func toggleFret(stringIndex: Int, absoluteFret: Int) {
        guard (0 ..< 6).contains(stringIndex) else { return }
        if strings[stringIndex].fret == absoluteFret {
            strings[stringIndex] = StringFingering(fret: 0)
        } else {
            strings[stringIndex] = StringFingering(fret: absoluteFret)
        }
    }

    /// 左エリアタップ: open ↔ muted を切り替え。押弦中はクリアして muted にする。
    mutating func toggleTopState(stringIndex: Int) {
        guard (0 ..< 6).contains(stringIndex) else { return }
        if strings[stringIndex].isMuted {
            strings[stringIndex] = StringFingering(fret: 0) // muted → open
        } else {
            strings[stringIndex] = StringFingering(fret: -1) // open / pressed → muted
        }
    }

    mutating func incrementStartFret() {
        startFret += 1
        clearOutOfRangeDots()
    }

    mutating func decrementStartFret() {
        guard startFret > 1 else { return }
        startFret -= 1
        clearOutOfRangeDots()
    }

    mutating func setFretCount(_ count: Int) {
        fretCount = max(3, count)
        clearOutOfRangeDots()
    }

    private mutating func clearOutOfRangeDots() {
        for i in 0 ..< 6 where strings[i].isPressed {
            let rel = strings[i].fret - startFret + 1
            if rel < 1 || rel > fretCount {
                strings[i] = StringFingering(fret: 0)
            }
        }
    }

    /// 押弦フレットの実際の範囲だけを表示するコンパクトなコピー。
    /// 開放弦・ミュートはそのまま保持し、表示フレット数を最小化する。
    /// ローポジション（最低押弦フレット ≤ 4）は必ずナット（1フレット）から表示する。
    var effectiveFingering: ChordFingering {
        let pressedFrets = strings.compactMap { $0.isPressed ? $0.fret : nil }
        guard !pressedFrets.isEmpty else {
            // 押弦なし（全開放 or 全ミュート）: ナット位置で最小幅
            return ChordFingering(strings: strings, startFret: 1, fretCount: 3)
        }
        let minFret = pressedFrets.min()!
        let maxFret = pressedFrets.max()!
        // ローポジションはナットから表示。ハイポジションは押弦範囲のみ。
        let start = minFret <= 4 ? 1 : minFret
        let count = max(maxFret - start + 1, 3)
        return ChordFingering(strings: strings, startFret: start, fretCount: count)
    }
}
