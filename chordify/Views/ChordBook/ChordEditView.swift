import SwiftData
import SwiftUI

struct ChordEditView: View {
    var chord: ChordDiagram?
    var isGlobal: Bool = true
    var song: Song? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var name = ""
    @State private var folder = ""
    @State private var fingering = ChordFingering.empty

    @Query(filter: #Predicate<ChordDiagram> { $0.isGlobal }, sort: \ChordDiagram.createdAt)
    private var globalChords: [ChordDiagram]

    var isEditing: Bool {
        chord != nil
    }

    var existingFolders: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for c in globalChords where !c.folder.isEmpty {
            if seen.insert(c.folder).inserted { result.append(c.folder) }
        }
        return result
    }

    // MARK: - body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                if isGlobal { folderSection }
                fingeringSection
            }
            .navigationTitle(isEditing ? "コードを編集" : "コードを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(isGlobal && name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let chord {
                    name = chord.name
                    fingering = chord.fingering
                    folder = chord.folder
                }
            }
        }
    }

    // MARK: - セクション（コンパイラの型推論負荷を分散）

    private var nameSection: some View {
        Section(isGlobal ? "コード名" : "コード名（任意）") {
            TextField("例: Am, G, C/E", text: $name)
                .autocorrectionDisabled()
        }
    }

    private var folderSection: some View {
        Section("フォルダー") {
            TextField("フォルダー名（任意）", text: $folder)
                .autocorrectionDisabled()
            if !existingFolders.isEmpty {
                folderChips
            }
        }
    }

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(existingFolders, id: \.self) { f in
                    folderChip(f)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func folderChip(_ f: String) -> some View {
        let isSelected = folder == f
        return Button(action: { folder = f }) {
            Text(f)
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var fingeringSection: some View {
        Section("フィンガリング") {
            FretBoardEditorView(fingering: $fingering)
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    // MARK: - 保存

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedFolder = folder.trimmingCharacters(in: .whitespaces)
        if let chord {
            chord.name = trimmedName
            chord.fingering = fingering
            chord.folder = trimmedFolder
        } else {
            let newChord = ChordDiagram(
                name: trimmedName,
                fingering: fingering,
                isGlobal: isGlobal,
                folder: isGlobal ? trimmedFolder : "",
                ownerSong: isGlobal ? nil : song
            )
            modelContext.insert(newChord)
            if let song, !isGlobal {
                song.localChords.append(newChord)
            }
        }
        dismiss()
    }
}

#Preview {
    ChordEditView()
        .modelContainer(
            for: [ChordDiagram.self, Song.self, LyricsSection.self, EffectorMemo.self],
            inMemory: true
        )
}
