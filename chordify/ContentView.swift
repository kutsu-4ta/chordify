import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @State private var splashVisible = true

    var body: some View {
        ZStack {
            SongListView()
                .preferredColorScheme(.light)
                .onAppear {
                    if !UserDefaults.standard.bool(forKey: DefaultChords.seedKey) {
                        DefaultChords.seed(into: modelContext)
                        UserDefaults.standard.set(true, forKey: DefaultChords.seedKey)
                    }
                }

            if splashVisible {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    splashVisible = false
                }
            }
        }
    }
}

// MARK: - SplashView

private struct SplashView: View {
    @State private var lineProgress: CGFloat = 0
    @State private var orangeScale: CGFloat = 0
    @State private var blueScale: CGFloat = 0
    @State private var pinkScale: CGFloat = 0
    @State private var barsOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(r: 174, g: 225, b: 249), Color(r: 43, g: 152, b: 189)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                ChordifyIconView(
                    lineProgress: lineProgress,
                    orangeScale: orangeScale,
                    blueScale: blueScale,
                    pinkScale: pinkScale,
                    barsOpacity: barsOpacity
                )
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 44))
                .shadow(color: .black.opacity(0.2), radius: 28, x: 0, y: 10)

                Text("Chordify")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(r: 254, g: 255, b: 250))
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            // バー出現
            withAnimation(.easeOut(duration: 0.2).delay(0.05)) { barsOpacity = 1 }
            // スタッフライン左→右に描画
            withAnimation(.easeInOut(duration: 0.6).delay(0.12)) { lineProgress = 1 }
            // 音符（ライン到達タイミングに合わせてスプリングで出現）
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62).delay(0.42)) { orangeScale = 1 }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62).delay(0.58)) { blueScale = 1 }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62).delay(0.72)) { pinkScale = 1 }
            // テキスト
            withAnimation(.easeOut(duration: 0.4).delay(0.68)) { textOpacity = 1 }
        }
    }
}

// MARK: - ChordifyIconView（SVGを忠実に再現）

private struct ChordifyIconView: View {
    let lineProgress: CGFloat
    let orangeScale: CGFloat
    let blueScale: CGFloat
    let pinkScale: CGFloat
    let barsOpacity: Double

    private let white = Color(r: 254, g: 255, b: 250)
    private let blue = Color(r: 5, g: 124, b: 249)
    private let orange = Color(r: 242, g: 155, b: 24)
    private let pink = Color(r: 254, g: 120, b: 125)

    var body: some View {
        GeometryReader { geo in
            // SVGキャンバス 1024×1024 → 実サイズへのスケール係数
            let s = geo.size.width / 1024

            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [Color(r: 174, g: 225, b: 249), Color(r: 43, g: 152, b: 189)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                // 縦バー 2本
                Group {
                    vertBar(cx: 164.305, top: 239.97, bottom: 752.409, w: 32.61, s: s)
                    vertBar(cx: 255.923, top: 238.418, bottom: 750.857, w: 32.61, s: s)
                }
                .opacity(barsOpacity)

                // スタッフライン 3本（左から右へ trim アニメーション）
                staffLine(y: 738.822, s: s)
                staffLine(y: 492.696, s: s)
                staffLine(y: 255.111, s: s)

                // 音符（スプリングでスケールイン）
                note(cx: 427.512, cy: 495.414, r: 94.7236, color: orange, scale: orangeScale, s: s)
                note(cx: 669.756, cy: 739.211, r: 94.7236, color: blue, scale: blueScale, s: s)
                note(cx: 817.276, cy: 254.724, r: 94.7236, color: pink, scale: pinkScale, s: s)
            }
        }
    }

    /// スタッフライン
    private func staffLine(y: CGFloat, s: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 165.47 * s, y: y * s))
            path.addLine(to: CGPoint(x: 878.614 * s, y: y * s))
        }
        .trim(from: 0, to: lineProgress)
        .stroke(white, style: StrokeStyle(lineWidth: 40 * s, lineCap: .round))
    }

    /// 縦バー（角丸矩形）
    private func vertBar(cx: CGFloat, top: CGFloat, bottom: CGFloat, w: CGFloat, s: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: (w * s) / 2)
            .fill(white)
            .frame(width: w * s, height: (bottom - top) * s)
            .position(x: cx * s, y: (top + bottom) / 2 * s)
    }

    /// 音符（円）— scaleEffect を position より先に適用して自分の中心から拡大
    private func note(cx: CGFloat, cy: CGFloat, r: CGFloat, color: Color, scale: CGFloat, s: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: r * 2 * s, height: r * 2 * s)
            .scaleEffect(scale)
            .position(x: cx * s, y: cy * s)
    }
}

// MARK: - Color helper（8bit RGB）

private extension Color {
    init(r: Double, g: Double, b: Double) {
        self.init(red: r / 255, green: g / 255, blue: b / 255)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self], inMemory: true)
}
