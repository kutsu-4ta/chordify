import SwiftUI
import SwiftData

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.5)) {
                    splashVisible = false
                }
            }
        }
    }
}

// MARK: - SplashView

private struct SplashView: View {
    @State private var iconScale: CGFloat = 0.7
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "guitars.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                Spacer().frame(height: 28)

                // アプリ名
                Text("Chordify")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer().frame(height: 8)

                // サブタイトル
                Text("ライブ・練習サポート")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .opacity(taglineOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                iconScale = 1.0
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.35)) {
                titleOffset = 0
                titleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
                taglineOpacity = 1
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self], inMemory: true)
}
