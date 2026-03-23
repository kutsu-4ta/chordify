import SwiftUI
import SwiftData

struct SectionEditView: View {
    @Bindable var section: LyricsSection
    let song: Song

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query var allChords: [ChordDiagram]

    @State private var pendingNormalizedX: Double? = nil
    @State private var showChordPicker = false
    @State private var tappedPlacementID: UUID? = nil
    @State private var showPlacementActions = false
    @State private var showEffectorMemo = false

    var availableChords: [ChordDiagram] {
        allChords.filter { $0.isGlobal || $0.ownerSong?.id == song.id }
    }

    func chordName(for id: UUID) -> String {
        availableChords.first { $0.id == id }?.name ?? "?"
    }

    var tappedChordName: String {
        guard let pid = tappedPlacementID,
              let p = section.chordPlacements.first(where: { $0.id == pid })
        else { return "" }
        return chordName(for: p.chordID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sectionEditor
                        .padding(.horizontal)
                        .padding(.top, 8)

                    effectorSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("セクション編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .sheet(isPresented: $showChordPicker) {
                ChordPickerSheet(song: song, selectedID: nil) { id in
                    if let id, let x = pendingNormalizedX {
                        section.chordPlacements.append(ChordPlacement(normalizedX: x, chordID: id))
                    }
                    pendingNormalizedX = nil
                    showChordPicker = false
                }
            }
            .confirmationDialog(tappedChordName, isPresented: $showPlacementActions, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    if let pid = tappedPlacementID {
                        section.chordPlacements.removeAll { $0.id == pid }
                    }
                    tappedPlacementID = nil
                }
                Button("キャンセル", role: .cancel) { tappedPlacementID = nil }
            }
            .sheet(isPresented: $showEffectorMemo) {
                if let memo = section.effectorMemo {
                    EffectorMemoSheet(memo: memo, isEditing: true)
                }
            }
        }
    }

    // MARK: - 2行エディタ

    var sectionEditor: some View {
        VStack(spacing: 0) {
            // 上行: コード配置
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color(.secondarySystemBackground)
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    let nx = value.location.x / geo.size.width
                                    pendingNormalizedX = max(0.01, min(0.99, nx))
                                    showChordPicker = true
                                }
                        )

                    if section.chordPlacements.isEmpty {
                        Text("タップしてコードを追加")
                            .font(.caption)
                            .foregroundStyle(Color(.placeholderText))
                            .padding(.leading, 8)
                            .allowsHitTesting(false)
                    }

                    ForEach(section.chordPlacements) { placement in
                        Text(chordName(for: placement.chordID))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 3)
                            .background(Color(.secondarySystemBackground))
                            .position(x: placement.normalizedX * geo.size.width, y: 14)
                            .onTapGesture {
                                tappedPlacementID = placement.id
                                showPlacementActions = true
                            }
                    }
                }
            }
            .frame(height: 28)

            Divider()

            // 下行: 歌詞テキスト
            TextField("歌詞を入力", text: $section.lyrics)
                .font(.body)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - エフェクターメモ

    var effectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("エフェクターメモ")
                .font(.headline)

            if let memo = section.effectorMemo {
                HStack {
                    Image(systemName: "guitars")
                        .foregroundStyle(.orange)
                    Text(memo.text.isEmpty ? "（タップして編集）" : memo.text)
                        .lineLimit(2)
                        .foregroundStyle(memo.text.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture { showEffectorMemo = true }

                Button("メモを削除", role: .destructive) {
                    if let memo = section.effectorMemo {
                        modelContext.delete(memo)
                        section.effectorMemo = nil
                    }
                }
                .font(.callout)
            } else {
                Button {
                    let memo = EffectorMemo()
                    memo.section = section
                    section.effectorMemo = memo
                    modelContext.insert(memo)
                    showEffectorMemo = true
                } label: {
                    Label("エフェクターメモを追加", systemImage: "plus.circle")
                }
            }
        }
    }
}
