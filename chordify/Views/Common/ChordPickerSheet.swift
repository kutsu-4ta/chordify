import SwiftData
import SwiftUI

struct ChordPickerSheet: View {
    let song: Song
    let selectedID: UUID?
    let onSelect: (UUID?) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(filter: #Predicate<ChordDiagram> { $0.isGlobal }, sort: \ChordDiagram.createdAt)
    var globalChords: [ChordDiagram]

    @State private var showAddChord = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var localChords: [ChordDiagram] {
        song.localChords.sorted { $0.createdAt < $1.createdAt }
    }

    var globalFolders: [String] {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // なし
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                            Text("なし")
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    Divider()
                        .padding(.horizontal, 16)

                    // コードブック（フォルダ別）
                    if !globalChords.isEmpty {
                        ForEach(globalFolders, id: \.self) { folder in
                            let folderChords = globalChords.filter { $0.folder == folder }
                            sectionHeader(folder.isEmpty ? "コードブック" : folder)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(folderChords) { chord in
                                    pickerCell(chord)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }

                    // この曲のコード
                    sectionHeader("この曲のコード")
                    if !localChords.isEmpty {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(localChords) { chord in
                                pickerCell(chord)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                    Button {
                        showAddChord = true
                    } label: {
                        Label("新しいコードを追加", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("コードを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddChord) {
                ChordEditView(chord: nil, isGlobal: false, song: song)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func pickerCell(_ chord: ChordDiagram) -> some View {
        let isSelected = chord.id == selectedID
        return Button {
            onSelect(chord.id)
            dismiss()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    FretBoardView(fingering: chord.fingering.effectiveFingering)
                        .frame(width: 78, height: 42)
                        .cornerRadius(4)
                    if !chord.name.isEmpty {
                        Text(chord.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
