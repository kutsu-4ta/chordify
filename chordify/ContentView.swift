import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext

    var body: some View {
        SongListView()
            .preferredColorScheme(.light)
            .onAppear {
                if !UserDefaults.standard.bool(forKey: DefaultChords.seedKey) {
                    DefaultChords.seed(into: modelContext)
                    UserDefaults.standard.set(true, forKey: DefaultChords.seedKey)
                }
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self], inMemory: true)
}
