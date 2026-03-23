import SwiftUI
import SwiftData

struct SongListView: View {
    @Query(sort: \Song.createdAt, order: .reverse) var songs: [Song]
    @Environment(\.modelContext) var modelContext

    @State private var showingAddSong = false
    @State private var newSongTitle = ""

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(songs) { song in
                            NavigationLink(value: song) {
                                songRow(song)
                            }
                        }
                        .onDelete(perform: deleteSongs)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("曲一覧")
            .navigationDestination(for: Song.self) { song in
                SongDetailView(song: song)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newSongTitle = ""
                        showingAddSong = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .alert("新しい曲を追加", isPresented: $showingAddSong) {
                TextField("曲のタイトル", text: $newSongTitle)
                    .autocorrectionDisabled()
                Button("追加") { addSong() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("曲のタイトルを入力してください")
            }
        }
    }

    private func songRow(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(song.title)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                infoChip("\(song.bpm) BPM", systemImage: "metronome")
                infoChip("\(song.sections.count)セクション", systemImage: "text.alignleft")
                if song.capo > 0 {
                    infoChip("カポ \(song.capo)", systemImage: "slider.horizontal.3", accent: true)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func infoChip(_ text: String, systemImage: String, accent: Bool = false) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(accent ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(accent ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.mic")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            VStack(spacing: 8) {
                Text("まだ曲がありません")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("+ をタップして最初の曲を追加しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func addSong() {
        let title = newSongTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let song = Song(title: title)
        modelContext.insert(song)
    }

    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(songs[index])
        }
    }
}

#Preview {
    SongListView()
        .modelContainer(for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self], inMemory: true)
}
