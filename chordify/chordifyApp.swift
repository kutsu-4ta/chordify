import SwiftUI
import SwiftData

@main
struct chordifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self])
    }
}
