import SwiftUI

/// 横スクロール対応コードダイアグラムエディタ
/// - ギター指板風デザイン（ローズウッド・フレットワイヤー・弦色）
/// - 6フレット表示、最大25フレットまでスクロール可能
/// - 左列（弦ラベル・X/O）は固定、フレットグリッドのみスクロール
struct FretBoardEditorView: View {
    @Binding var fingering: ChordFingering

    // MARK: - レイアウト定数
    private let totalFrets   = 25
    private let visibleFrets = 6
    private let stringLabels = ["E", "A", "D", "G", "B", "e"]
    private let rowHeight: CGFloat  = 52
    private let leftColWidth: CGFloat = 62
    private let nutWidth: CGFloat     = 6

    // MARK: - 指板カラー
    private let boardColor  = Color(red: 0.20, green: 0.10, blue: 0.04)   // ローズウッド
    private let fretColor   = Color(red: 0.74, green: 0.74, blue: 0.78)   // シルバーフレット
    private let nutColor    = Color(red: 0.93, green: 0.87, blue: 0.70)   // アイボリーナット
    private let inlayColor  = Color.white.opacity(0.20)                    // ポジションマーク
    private let dotFill     = Color.white                                   // 押弦ドット

    // row0=e(上)→ row5=E(下)  低音弦ほど太く・暗い色
    private let stringColors: [Color] = [
        Color(red: 0.92, green: 0.92, blue: 0.95),   // e  (プレーン・明)
        Color(red: 0.86, green: 0.86, blue: 0.90),   // B  (プレーン)
        Color(red: 0.82, green: 0.76, blue: 0.54),   // G  (ライトワウンド)
        Color(red: 0.76, green: 0.62, blue: 0.34),   // D  (ワウンド)
        Color(red: 0.70, green: 0.54, blue: 0.24),   // A  (ワウンド)
        Color(red: 0.62, green: 0.46, blue: 0.18),   // E  (ヘビーワウンド・暗)
    ]
    private let stringWidths: [CGFloat] = [0.8, 1.0, 1.4, 1.8, 2.2, 2.7]

    // MARK: - ポジションマーク（標準ギター配置）
    private let singleDotFrets = [3, 5, 7, 9, 15, 17, 19, 21]
    private let doubleDotFrets = [12, 24]

    // MARK: - body

    var body: some View {
        GeometryReader { geo in
            let gridW  = geo.size.width - leftColWidth - nutWidth
            let cellW  = gridW / CGFloat(visibleFrets)
            let totalW = cellW * CGFloat(totalFrets)

            HStack(alignment: .top, spacing: 0) {

                // ── 左固定列：弦ラベル & X/O ───────────────────
                VStack(spacing: 0) {
                    ForEach((0..<6).reversed(), id: \.self) { si in
                        Button {
                            fingering.toggleTopState(stringIndex: si)
                        } label: {
                            HStack(spacing: 6) {
                                Text(stringLabels[si])
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(width: 14)
                                xoView(for: si)
                                    .frame(width: 24, height: 24)
                            }
                            .frame(width: leftColWidth, height: rowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(boardColor.opacity(0.88))

                // ── ナット（アイボリー、固定）──────────────────
                Rectangle()
                    .fill(nutColor)
                    .frame(width: nutWidth, height: rowHeight * 6)

                // ── 横スクロール可能なフレットグリッド ─────────
                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {

                        // 1. 指板背景
                        Rectangle()
                            .fill(boardColor)
                            .frame(width: totalW, height: rowHeight * 6)

                        // 2. ポジションマーク（シングルドット）
                        ForEach(singleDotFrets, id: \.self) { fi in
                            let cx = (CGFloat(fi) - 0.5) * cellW
                            let d  = min(cellW * 0.30, rowHeight * 0.30)
                            Circle()
                                .fill(inlayColor)
                                .frame(width: d, height: d)
                                .position(x: cx, y: rowHeight * 3.0)
                                .allowsHitTesting(false)
                        }

                        // 3. ポジションマーク（ダブルドット：12・24フレット）
                        ForEach(doubleDotFrets, id: \.self) { fi in
                            let cx = (CGFloat(fi) - 0.5) * cellW
                            let d  = min(cellW * 0.30, rowHeight * 0.30)
                            Circle()
                                .fill(inlayColor)
                                .frame(width: d, height: d)
                                .position(x: cx, y: rowHeight * 1.5)
                                .allowsHitTesting(false)
                            Circle()
                                .fill(inlayColor)
                                .frame(width: d, height: d)
                                .position(x: cx, y: rowHeight * 4.5)
                                .allowsHitTesting(false)
                        }

                        // 4. 弦線（水平・色と太さで金属感を表現）
                        ForEach(0..<6, id: \.self) { row in
                            let y = (CGFloat(row) + 0.5) * rowHeight
                            Path { p in
                                p.move(to:    CGPoint(x: 0,      y: y))
                                p.addLine(to: CGPoint(x: totalW, y: y))
                            }
                            .stroke(stringColors[row], lineWidth: stringWidths[row])
                        }

                        // 5. フレット線（垂直・シルバー）
                        ForEach(1...totalFrets, id: \.self) { fi in
                            Path { p in
                                let x = CGFloat(fi) * cellW
                                p.move(to:    CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: rowHeight * 6))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [fretColor.opacity(0.6), fretColor, fretColor.opacity(0.6)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                        }

                        // 6. 押弦ドット（白丸・フレット領域中央）
                        ForEach(0..<6, id: \.self) { row in
                            let si = 5 - row
                            let cy = (CGFloat(row) + 0.5) * rowHeight
                            if fingering.strings[si].isPressed {
                                let absF = fingering.strings[si].fret
                                let cx   = (CGFloat(absF) - 0.5) * cellW
                                let d    = min(cellW * 0.58, rowHeight * 0.58)
                                Circle()
                                    .fill(dotFill)
                                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                    .frame(width: d, height: d)
                                    .position(x: cx, y: cy)
                                    .allowsHitTesting(false)
                            }
                        }

                        // 7. フレット番号（下端）
                        ForEach(1...totalFrets, id: \.self) { fi in
                            Text("\(fi)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.50))
                                .position(
                                    x: (CGFloat(fi) - 0.5) * cellW,
                                    y: rowHeight * 6 + 10
                                )
                        }

                        // 8. タップ検出オーバーレイ（弦エリアのみ）
                        Color.clear
                            .frame(width: totalW, height: rowHeight * 6)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        let fi  = Int(value.location.x / cellW) + 1
                                        let row = Int(value.location.y / rowHeight)
                                        let si  = 5 - row
                                        guard fi >= 1, fi <= totalFrets,
                                              (0..<6).contains(si) else { return }
                                        fingering.toggleFret(stringIndex: si,
                                                             absoluteFret: fi)
                                    }
                            )
                    }
                    .frame(width: totalW, height: rowHeight * 6 + 20)
                }
                .frame(width: gridW)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(height: rowHeight * 6 + 20)
    }

    // MARK: - X/O インジケーター（暗背景対応）

    @ViewBuilder
    private func xoView(for si: Int) -> some View {
        let sf = fingering.strings[si]
        if sf.isMuted {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.red)
        } else if sf.isOpen {
            Circle()
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                .frame(width: 16, height: 16)
        } else {
            // 押弦中（左列タップで muted に変わる）
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 16, height: 16)
        }
    }
}

#Preview {
    @Previewable @State var f = ChordFingering(
        strings: [
            StringFingering(fret: -1),
            StringFingering(fret: 2),
            StringFingering(fret: 4),
            StringFingering(fret: 4),
            StringFingering(fret: 4),
            StringFingering(fret: 2),
        ],
        startFret: 1
    )
    FretBoardEditorView(fingering: $f)
        .padding()
}
