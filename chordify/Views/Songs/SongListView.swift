import SwiftUI
import SwiftData

struct SongListView: View {
    @Query(sort: \Song.createdAt, order: .reverse) var songs: [Song]
    @Environment(\.modelContext) var modelContext

    @State private var showingAddSong = false
    @State private var newSongTitle = ""
    @State private var showChordBook = false
    @State private var searchText = ""
    @State private var songToDelete: Song? = nil

    var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return songs }
        let q = searchText.lowercased()
        return songs.filter {
            $0.title.lowercased().contains(q) ||
            $0.memo.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    emptyState
                } else if filteredSongs.isEmpty {
                    noResults
                } else {
                    songList
                }
            }
            .navigationTitle("曲一覧")
            .navigationDestination(for: Song.self) { song in
                SongDetailView(song: song)
            }
            .searchable(text: $searchText, prompt: "検索")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showChordBook = true
                    } label: {
                        Image(systemName: "music.note.list")
                    }
                    Button {
                        newSongTitle = ""
                        showingAddSong = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showChordBook) {
                ChordBookView()
            }
            .alert("新しい曲を追加", isPresented: $showingAddSong) {
                TextField("曲のタイトル", text: $newSongTitle)
                    .autocorrectionDisabled()
                Button("追加") { addSong() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("曲のタイトルを入力してください")
            }
            .confirmationDialog(
                songToDelete.map { "\"\($0.title)\" を削除しますか？" } ?? "",
                isPresented: Binding(get: { songToDelete != nil },
                                     set: { if !$0 { songToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let s = songToDelete { modelContext.delete(s) }
                    songToDelete = nil
                }
                Button("キャンセル", role: .cancel) { songToDelete = nil }
            }
        }
    }

    // MARK: - リスト

    private var songList: some View {
        List {
            ForEach(filteredSongs) { song in
                NavigationLink(value: song) {
                    songRow(song)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        songToDelete = song
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 空状態

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

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("「\(searchText)」に一致する曲はありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - 行

    private func songRow(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(song.title)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                infoChip("\(song.bpm) BPM", systemImage: "metronome")
                if song.capo > 0 {
                    infoChip("カポ \(song.capo)", systemImage: "slider.horizontal.3", accent: true)
                }
                if !song.statusLabel.trimmingCharacters(in: .whitespaces).isEmpty {
                    statusChip(song.statusLabel)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func statusChip(_ label: String) -> some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
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

    // MARK: - ヘルパー

    private func addSong() {
        let title = newSongTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let song = Song(title: title)
        modelContext.insert(song)
    }
}

#Preview {
    SongListView()
        .modelContainer(for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self], inMemory: true)
}
