import SwiftUI
import SwiftData

struct SongDetailView: View {
    @Bindable var song: Song
    @Environment(\.modelContext) var modelContext
    @Query var allChords: [ChordDiagram]

    @State private var viewModel: ScrollViewModel
    @State private var isEditing = false
    @State private var showSettings = false
    @State private var lastDragTranslation: CGFloat = 0
    @FocusState private var focusedSectionID: UUID?

    init(song: Song) {
        self.song = song
        self._viewModel = State(initialValue: ScrollViewModel(song: song))
    }

    func chord(for id: UUID) -> ChordDiagram? {
        allChords.first { $0.id == id }
    }

    var body: some View {
        Group {
            if isEditing {
                editView
            } else {
                performanceView
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isPlaying)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "完了" : "編集") {
                    if isEditing {
                        isEditing = false
                    } else {
                        viewModel.pause()
                        isEditing = true
                        // 行がなければ最初の行を自動作成
                        if song.sortedSections.isEmpty { addSection() }
                    }
                }
            }

            if !isEditing {
                ToolbarItemGroup(placement: .bottomBar) {
                    // 自動スクロール
                    Button { viewModel.toggle() } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }

                    Spacer()

                    // メトロノーム
                    Button { viewModel.toggleClick() } label: {
                        Image(systemName: viewModel.clickEnabled ? "metronome.fill" : "metronome")
                            .font(.title2)
                            .foregroundColor(viewModel.clickEnabled ? .accentColor : .primary)
                    }

                    Spacer()

                    // コードの表示方法
                    Menu {
                        Picker("コードの表示方法", selection: $song.chordDisplayMode) {
                            ForEach(ChordDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } label: {
                        Image(systemName: "eye")
                            .font(.title2)
                    }

                    Spacer()

                    // 設定
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SongSettingsSheet(song: song)
        }
        .onDisappear {
            viewModel.pause()
        }
    }

    // MARK: - パフォーマンスビュー（テレプロンプター、閲覧専用）

    private var performanceView: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(song.sortedSections) { section in
                    SectionRow(
                        section: section,
                        song: song,
                        isEditing: false,
                        chordLookup: { chord(for: $0) },
                        focus: $focusedSectionID,
                        onDelete: {},
                        onSubmit: { _ in }
                    )
                }
                Color.clear.frame(height: geo.size.height * 0.75)
            }
            .background(
                GeometryReader { inner in
                    Color.clear
                        .onAppear { viewModel.contentHeight = inner.size.height }
                        .onChange(of: inner.size.height) { _, h in viewModel.contentHeight = h }
                }
            )
            .offset(y: -viewModel.scrollOffset)
            .frame(width: geo.size.width, alignment: .leading)
            .onAppear { viewModel.viewHeight = geo.size.height }
            .onChange(of: geo.size.height) { _, h in viewModel.viewHeight = h }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let delta = value.translation.height - lastDragTranslation
                        lastDragTranslation = value.translation.height
                        viewModel.manualScroll(deltaY: -delta)
                    }
                    .onEnded { value in
                        lastDragTranslation = 0
                        viewModel.manualScrollEnd(velocityY: -value.velocity.height)
                    }
            )
        }
        .clipped()
    }

    // MARK: - 編集ビュー（同じ見た目、編集可能）

    private var editView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(song.sortedSections) { section in
                    SectionRow(
                        section: section,
                        song: song,
                        isEditing: true,
                        chordLookup: { chord(for: $0) },
                        focus: $focusedSectionID,
                        onDelete: { modelContext.delete(section) },
                        onSubmit: { remainder in addSectionAfter(section, withLyrics: remainder) }
                    )
                }
            }
            .padding(.bottom, 200)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - ヘルパー

    private func addSection() {
        let order = song.sortedSections.count
        let newSection = LyricsSection(order: order, song: song)
        modelContext.insert(newSection)
        song.sections.append(newSection)
        let id = newSection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedSectionID = id
        }
    }

    private func addSectionAfter(_ section: LyricsSection, withLyrics lyrics: String = "") {
        let sorted = song.sortedSections
        guard let index = sorted.firstIndex(where: { $0.id == section.id }) else {
            addSection()
            return
        }
        let insertOrder = index + 1
        for sec in sorted[insertOrder...] {
            sec.order += 1
        }
        let newSection = LyricsSection(order: insertOrder, song: song)
        newSection.lyrics = lyrics
        modelContext.insert(newSection)
        song.sections.append(newSection)
        let id = newSection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedSectionID = id
        }
    }
}

// MARK: - SectionRow（編集・閲覧で同一レイアウト）

private struct SectionRow: View {
    @Bindable var section: LyricsSection
    let song: Song
    let isEditing: Bool
    let chordLookup: (UUID) -> ChordDiagram?
    var focus: FocusState<UUID?>.Binding
    let onDelete: () -> Void
    let onSubmit: (String) -> Void

    @State private var pendingNX: Double? = nil
    @State private var showPicker = false
    @State private var tappedPlacementID: UUID? = nil
    @State private var showActions = false
    @State private var actionChordName = ""
    @State private var showEffectorMemo = false
    @State private var performanceTappedChord: ChordDiagram? = nil
    @State private var draggingID: UUID? = nil
    @State private var dragDeltaX: CGFloat = 0
    @State private var actionShowDiagram: Bool = true
    @State private var actionShowName: Bool = true
    @State private var actionHasName: Bool = false

    private let diagramW: CGFloat = 64
    private let diagramH: CGFloat = 36

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                chordArea
                lyricsView
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .font(.system(size: 16))
                }
                .padding(.top, section.chordPlacements.isEmpty ? 10 : (diagramH + 20))
                .padding(.trailing, 12)
            }
        }
        .background(isEditing ? Color(.systemBackground) : .clear)
        .overlay(alignment: .bottom) {
            Divider().opacity(isEditing ? 1.0 : 0.18)
        }
        .sheet(isPresented: $showPicker) {
            ChordPickerSheet(song: song, selectedID: nil) { id in
                if let id, let nx = pendingNX {
                    section.chordPlacements.append(ChordPlacement(normalizedX: nx, chordID: id))
                }
                pendingNX = nil
            }
        }
        .confirmationDialog(actionChordName, isPresented: $showActions, titleVisibility: .visible) {
            Button(actionShowDiagram ? "ダイアグラムを非表示にする" : "ダイアグラムを表示する") {
                if let pid = tappedPlacementID,
                   let idx = section.chordPlacements.firstIndex(where: { $0.id == pid }) {
                    section.chordPlacements[idx].showDiagram.toggle()
                }
                tappedPlacementID = nil
            }
            if actionHasName {
                Button(actionShowName ? "コード名を非表示にする" : "コード名を表示する") {
                    if let pid = tappedPlacementID,
                       let idx = section.chordPlacements.firstIndex(where: { $0.id == pid }) {
                        section.chordPlacements[idx].showName.toggle()
                    }
                    tappedPlacementID = nil
                }
            }
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
                EffectorMemoSheet(memo: memo, isEditing: isEditing)
            }
        }
        .sheet(item: $performanceTappedChord) { chord in
            ChordPreviewSheet(chord: chord)
        }
    }

    // MARK: コードエリア ヘルパー

    /// パフォーマンスモードでこのプレースメントのダイアグラムを表示するか
    private func effectiveShowDiagram(_ placement: ChordPlacement) -> Bool {
        switch song.chordDisplayMode {
        case .custom:      return placement.showDiagram
        case .diagramOnly: return true
        case .nameOnly, .hidden: return false
        }
    }

    /// パフォーマンスモードでこのプレースメントのコード名を表示するか
    private func effectiveShowName(_ placement: ChordPlacement, chord: ChordDiagram?) -> Bool {
        guard let chord, !chord.name.isEmpty else { return false }
        switch song.chordDisplayMode {
        case .custom:    return placement.showName
        case .nameOnly:  return true
        case .diagramOnly, .hidden: return false
        }
    }

    /// ダイアグラム+コード名を収めるのに必要な高さ
    private var diagramWithNameH: CGFloat { diagramH + 20 }  // 36+20=56
    /// ダイアグラムのみの高さ
    private var diagramOnlyH: CGFloat    { diagramH + 8  }   // 36+8=44

    /// パフォーマンスモードでのコードエリアの高さ
    private var performanceChordAreaHeight: CGFloat {
        guard !section.chordPlacements.isEmpty else { return 0 }
        switch song.chordDisplayMode {
        case .hidden:      return 0
        case .nameOnly:    return 22
        case .diagramOnly: return diagramOnlyH
        case .custom:
            let anyDiag = section.chordPlacements.contains { $0.showDiagram }
            return anyDiag ? diagramWithNameH : 22
        }
    }

    // MARK: コードエリア

    @ViewBuilder
    private var chordArea: some View {
        let hasDiagrams = !section.chordPlacements.isEmpty
        let frameH = isEditing ? (hasDiagrams ? diagramWithNameH : 26) : performanceChordAreaHeight

        if frameH > 0 || isEditing {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 編集時のタップ領域
                    if isEditing {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        pendingNX = max(0.01, min(0.99, value.location.x / geo.size.width))
                                        showPicker = true
                                    }
                            )
                    }

                    // コードなし時のプレースホルダー（編集時のみ）
                    if !hasDiagrams && isEditing {
                        Text("コード")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.placeholderText))
                            .padding(.leading, 2)
                            .allowsHitTesting(false)
                    }

                    // ダイアグラム
                    ForEach(section.chordPlacements) { placement in
                        let ch = chordLookup(placement.chordID)
                        let isDragging = draggingID == placement.id
                        // 編集モード: 常に表示（非表示設定は半透明で示す）
                        // パフォーマンスモード: 表示設定に従う
                        let showDiag = isEditing || effectiveShowDiagram(placement)
                        let showNameText = isEditing
                            ? (placement.showName && ch?.name.isEmpty == false)
                            : effectiveShowName(placement, chord: ch)
                        let yCtr: CGFloat = showDiag
                            ? (showNameText ? diagramWithNameH / 2 : diagramOnlyH / 2)
                            : 11

                        VStack(spacing: 1) {
                            if let ch {
                                if showDiag {
                                    FretBoardView(fingering: ch.fingering.effectiveFingering)
                                        .frame(width: diagramW, height: diagramH)
                                        .opacity(isEditing && !placement.showDiagram ? 0.3 : 1.0)
                                }
                                if showNameText {
                                    Text(ch.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(1)
                                        .opacity(isEditing && !placement.showName ? 0.3 : 1.0)
                                }
                            } else {
                                if showDiag {
                                    Color.clear.frame(width: diagramW, height: diagramH)
                                }
                            }
                        }
                        .position(
                            x: placement.normalizedX * geo.size.width + (isDragging ? dragDeltaX : 0),
                            y: yCtr
                        )
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    guard isEditing else { return }
                                    draggingID = placement.id
                                    dragDeltaX = value.translation.width
                                }
                                .onEnded { value in
                                    guard isEditing, draggingID == placement.id else { return }
                                    let newNX = placement.normalizedX + value.translation.width / geo.size.width
                                    if let idx = section.chordPlacements.firstIndex(where: { $0.id == placement.id }) {
                                        section.chordPlacements[idx].normalizedX = max(0.01, min(0.99, newNX))
                                    }
                                    draggingID = nil
                                    dragDeltaX = 0
                                }
                        )
                        .onTapGesture {
                            if isEditing {
                                tappedPlacementID = placement.id
                                actionChordName = ch?.name.isEmpty == false ? ch!.name : "コード"
                                actionShowDiagram = placement.showDiagram
                                actionShowName = placement.showName
                                actionHasName = ch?.name.isEmpty == false
                                showActions = true
                            } else if let ch {
                                performanceTappedChord = ch
                            }
                        }
                    }

                    // エフェクターメモ
                    if section.effectorMemo != nil {
                        Button { showEffectorMemo = true } label: {
                            Image(systemName: "guitars")
                                .foregroundStyle(.orange)
                                .font(.body)
                        }
                        .position(x: geo.size.width - 24, y: diagramOnlyH / 2)
                    }
                }
            }
            .frame(height: frameH)
            .background(isEditing ? Color(.secondarySystemBackground) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: isEditing ? 6 : 0))
        }
    }

    // MARK: 歌詞エリア

    @ViewBuilder
    private var lyricsView: some View {
        if isEditing {
            TextField("", text: $section.lyrics, axis: .vertical)
                .font(.system(size: 22))
                .focused(focus, equals: section.id)
                .onChange(of: section.lyrics) { _, newValue in
                    // Return キーを改行挿入ではなく次行作成に使う
                    if let nlRange = newValue.range(of: "\n") {
                        let before = String(newValue[..<nlRange.lowerBound])
                        let after  = String(newValue[newValue.index(after: nlRange.lowerBound)...])
                        section.lyrics = before
                        onSubmit(after)
                    }
                }
        } else {
            if !section.lyrics.isEmpty {
                Text(section.lyrics)
                    .font(.system(size: 22))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - SongSettingsSheet

private struct SongSettingsSheet: View {
    @Bindable var song: Song
    @Environment(\.dismiss) var dismiss
    @State private var bpmText = ""

    var body: some View {
        NavigationStack {
            Form {
                songInfoSection
                scrollSection
                memoSection
            }
            .navigationTitle("曲の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .onAppear { bpmText = "\(song.bpm)" }
        }
    }

    private var songInfoSection: some View {
        Section("曲の情報") {
            HStack {
                Text("タイトル")
                TextField("タイトル", text: $song.title)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("BPM")
                Spacer()
                TextField("BPM", text: $bpmText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .onChange(of: bpmText) { _, v in
                        if let val = Int(v), val > 0 { song.bpm = val }
                    }
            }
            Stepper(
                song.capo == 0 ? "カポ: なし" : "カポ: \(song.capo)フレット",
                value: $song.capo,
                in: 0...12
            )
        }
    }

    private var scrollSection: some View {
        Section {
            Stepper(
                "スクロール速度: \(Int(song.scrollSpeed)) pt/秒",
                value: $song.scrollSpeed,
                in: 10...300,
                step: 10
            )
        } header: {
            Text("スクロール")
        } footer: {
            Text("数値が大きいほど速くスクロールします")
                .font(.caption)
        }
    }

    private var memoSection: some View {
        Section("メモ") {
            TextField("自由にメモを入力", text: $song.memo, axis: .vertical)
                .lineLimit(4...8)
        }
    }
}

// MARK: - ChordPreviewSheet

private struct ChordPreviewSheet: View {
    let chord: ChordDiagram
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                FretBoardView(fingering: chord.fingering.effectiveFingering)
                    .frame(width: 220, height: 128)
                    .padding(.top, 8)

                if !chord.name.isEmpty {
                    Text(chord.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
            .navigationTitle(chord.name.isEmpty ? "コード" : chord.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
