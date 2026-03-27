import SwiftData
import SwiftUI

struct ChordBookView: View {
    @Query(filter: #Predicate<ChordDiagram> { $0.isGlobal }, sort: \ChordDiagram.createdAt)
    var globalChords: [ChordDiagram]

    @Environment(\.modelContext) var modelContext
    @State private var showingAddChord = false
    @State private var editingChord: ChordDiagram? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var sortedFolders: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for chord in globalChords {
            if !chord.folder.isEmpty, !seen.contains(chord.folder) {
                seen.insert(chord.folder)
                ordered.append(chord.folder)
            }
        }
        if globalChords.contains(where: { $0.folder.isEmpty }) {
            ordered.append("")
        }
        return ordered
    }

    func chords(in folder: String) -> [ChordDiagram] {
        globalChords.filter { $0.folder == folder }
    }

    var body: some View {
        NavigationStack {
            Group {
                if globalChords.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(sortedFolders, id: \.self) { folder in
                                Section {
                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(chords(in: folder)) { chord in
                                            chordCell(chord)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 20)
                                } header: {
                                    folderHeader(folder.isEmpty ? "その他" : folder)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("コードブック")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddChord = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddChord) {
                ChordEditView(chord: nil, isGlobal: true, song: nil)
            }
            .sheet(item: $editingChord) { chord in
                ChordEditView(chord: chord, isGlobal: true, song: nil)
            }
        }
    }

    private func folderHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
    }

    private func chordCell(_ chord: ChordDiagram) -> some View {
        Button { editingChord = chord } label: {
            VStack(spacing: 6) {
                FretBoardView(fingering: chord.fingering.effectiveFingering)
                    .frame(width: 80, height: 44)
                    .cornerRadius(4)
                Text(chord.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { editingChord = chord } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(chord)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "guitars")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            VStack(spacing: 8) {
                Text("まだコードがありません")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("+ をタップしてコードを登録しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ChordBookView()
        .modelContainer(for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self], inMemory: true)
}
