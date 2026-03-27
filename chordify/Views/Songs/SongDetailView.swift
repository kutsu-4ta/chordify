import SwiftData
import SwiftUI

struct SongDetailView: View {
    @Bindable var song: Song
    @Environment(\.modelContext) var modelContext
    @Query var allChords: [ChordDiagram]

    @State private var viewModel: ScrollViewModel
    @State private var isEditing = false
    @State private var isTeleprompter = false
    @State private var showSettings = false
    @State private var lastDragTranslation: CGFloat = 0
    @State private var sectionToDelete: LyricsSection? = nil
    @FocusState private var focusedSectionID: UUID?
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var recordManager = RecordManager()

    init(song: Song) {
        self.song = song
        _viewModel = State(initialValue: ScrollViewModel(song: song))
    }

    func chord(for id: UUID) -> ChordDiagram? {
        allChords.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) { // 全体をVStackで包み、下にプレイヤーを置く
            Group {
                if isEditing { editView }
                else if isTeleprompter { teleprompterView }
                else { performanceView }
            }

            if recordManager.playingURL != nil {
                audioPlayerBar
            }
        }
        .navigationTitle(isTeleprompter ? "" : song.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(isTeleprompter)
        .navigationBarBackButtonHidden(viewModel.isPlaying || isTeleprompter)
        .toolbar {
            if !isTeleprompter {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(isEditing ? "完了" : "編集") {
                        if isEditing {
                            isEditing = false
                        } else {
                            viewModel.pause()
                            isEditing = true
                            if song.sortedSections.isEmpty { addSection() }
                        }
                    }
                }
            }

            if !isEditing && !isTeleprompter {
                bottomToolbar
            }
        }
        .sheet(isPresented: $showSettings) {
            SongSettingsSheet(song: song, recordManager: recordManager)
        }
        .confirmationDialog(
            "セクションを削除しますか？",
            isPresented: Binding(get: { sectionToDelete != nil },
                                 set: { if !$0 { sectionToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let s = sectionToDelete { modelContext.delete(s) }
                sectionToDelete = nil
            }
            Button("キャンセル", role: .cancel) { sectionToDelete = nil }
        }
        .onDisappear {
            exitTeleprompterIfNeeded()
            viewModel.pause()
            if viewModel.recordingEnabled {
                viewModel.toggleRecording()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { exitTeleprompterIfNeeded() }
        }
    }

    // MARK: - ツールバー

    private var bottomToolbar: some ToolbarContent {
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

            // 録音
            Button { viewModel.toggleRecording() } label: {
                Image(systemName: viewModel.recordingEnabled ? "record.circle.fill" : "record.circle")
                    .font(.title2)
                    .foregroundColor(viewModel.recordingEnabled ? .red : .primary)
            }

            Spacer()

            // コードの表示方法（タップで順番に切り替え）
            Button {
                song.chordDisplayMode = song.chordDisplayMode.next
            } label: {
                Image(systemName: song.chordDisplayMode.systemImage)
                    .font(.title2)
            }

            Spacer()

            // テレプロンプター
            Button { enterTeleprompter() } label: {
                Image(systemName: "arrow.left.and.right.square")
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

    // MARK: - テレプロンプター制御

    private var teleprompterView: some View {
        TeleprompterView(
            song: song,
            viewModel: viewModel,
            chordLookup: { chord(for: $0) },
            onExit: exitTeleprompterIfNeeded
        )
        .ignoresSafeArea()
    }

    private func enterTeleprompter() {
        viewModel.pause()
        viewModel.scrollOffset = 0
        viewModel.isHorizontalMode = true
        isTeleprompter = true
        OrientationManager.enterLandscape()
    }

    private func exitTeleprompterIfNeeded() {
        guard isTeleprompter else { return }
        viewModel.pause()
        viewModel.scrollOffset = 0
        viewModel.isHorizontalMode = false
        isTeleprompter = false
        OrientationManager.exitLandscape()
    }

    // MARK: - パフォーマンスビュー（テレプロンプター、閲覧専用）

    private var performanceView: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                // 先頭を画面中央から開始するための空白
                Color.clear.frame(height: geo.size.height * 0.5)
                ForEach(song.sortedSections) { section in
                    SectionRow(
                        section: section,
                        song: song,
                        isEditing: false,
                        chordLookup: { chord(for: $0) },
                        focus: $focusedSectionID,
                        onSubmit: { _ in }
                    )
                }
                Color.clear.frame(height: geo.size.height * 0.75)
            }
            .contentShape(Rectangle()) // 余白でもスクロールジェスチャーを受け取る
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

    // MARK: - 編集ビュー（ドラッグ&ドロップでセクション並び替え可）

    private var editView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(song.sortedSections) { section in
                    SectionRow(
                        section: section,
                        song: song,
                        isEditing: true,
                        chordLookup: { chord(for: $0) },
                        focus: $focusedSectionID,
                        onSubmit: { remainder in addSectionAfter(section, withLyrics: remainder) }
                    )
                    .id(section.id)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            sectionToDelete = section
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            // フォーカスされたセクションがキーボードに隠れないようスクロール
            .onChange(of: focusedSectionID) { _, id in
                guard let id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
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
        // 改行時に直前のセクションのコードを引き継ぐ
        newSection.chordPlacements = section.chordPlacements.map { p in
            ChordPlacement(normalizedX: p.normalizedX, chordID: p.chordID,
                           showDiagram: p.showDiagram, showName: p.showName)
        }
        modelContext.insert(newSection)
        song.sections.append(newSection)
        let id = newSection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedSectionID = id
        }
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        var sorted = song.sortedSections
        sorted.move(fromOffsets: source, toOffset: destination)
        for (newOrder, section) in sorted.enumerated() {
            section.order = newOrder
        }
    }

    // MARK: - 録音再生プレイヤー

    private var audioPlayerBar: some View {
        VStack(spacing: 4) {
            // Sliderの範囲が 0...0 にならないよう最大値を保証
            Slider(
                value: $recordManager.currentTime,
                in: 0 ... max(recordManager.duration, 1.0),
                onEditingChanged: { editing in
                    if !editing {
                        // 指を離した（editing == false）瞬間に、その位置へシーク
                        recordManager.seek(to: recordManager.currentTime)
                    }
                }
            )
            .tint(.blue)
            .padding(.horizontal)

            HStack {
                Text(formatTime(recordManager.currentTime))
                Spacer()

                // 再生・一時停止ボタン（togglePlaybackを使用）
                Button {
                    if let url = recordManager.playingURL {
                        recordManager.togglePlayback(for: url)
                    }
                } label: {
                    Image(systemName: recordManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .padding(.leading, 20)

                Spacer()
                Text(formatTime(recordManager.duration))
            }
            .font(.caption2)
            .monospacedDigit()
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - SectionRow（編集・閲覧で同一レイアウト）

private struct SectionRow: View {
    @Bindable var section: LyricsSection
    let song: Song
    let isEditing: Bool
    let chordLookup: (UUID) -> ChordDiagram?
    var focus: FocusState<UUID?>.Binding
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
        VStack(alignment: .leading, spacing: 2) {
            chordArea
            lyricsView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
                   let idx = section.chordPlacements.firstIndex(where: { $0.id == pid })
                {
                    section.chordPlacements[idx].showDiagram.toggle()
                }
                tappedPlacementID = nil
            }
            if actionHasName {
                Button(actionShowName ? "コード名を非表示にする" : "コード名を表示する") {
                    if let pid = tappedPlacementID,
                       let idx = section.chordPlacements.firstIndex(where: { $0.id == pid })
                    {
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
        case .custom: return placement.showDiagram
        case .diagramOnly: return true
        case .nameOnly, .hidden: return false
        }
    }

    /// パフォーマンスモードでこのプレースメントのコード名を表示するか
    private func effectiveShowName(_ placement: ChordPlacement, chord: ChordDiagram?) -> Bool {
        guard let chord, !chord.name.isEmpty else { return false }
        switch song.chordDisplayMode {
        case .custom: return placement.showName
        case .nameOnly: return true
        case .diagramOnly, .hidden: return false
        }
    }

    /// ダイアグラム+コード名を収めるのに必要な高さ
    private var diagramWithNameH: CGFloat {
        diagramH + 20
    } // 36+20=56
    /// ダイアグラムのみの高さ
    private var diagramOnlyH: CGFloat {
        diagramH + 8
    } // 36+8=44

    /// パフォーマンスモードでのコードエリアの高さ
    private var performanceChordAreaHeight: CGFloat {
        guard !section.chordPlacements.isEmpty else { return 0 }
        switch song.chordDisplayMode {
        case .hidden: return 0
        case .nameOnly: return 22
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
                        let after = String(newValue[newValue.index(after: nlRange.lowerBound)...])
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
    @ObservedObject var recordManager: RecordManager
//    @StateObject private var recordManager = RecordManager()

    var body: some View {
        NavigationStack {
            Form {
                songInfoSection
                scrollSection
                prompterSection
                recordingsSection
                memoSection
            }
            .navigationTitle("曲の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .onAppear {
                bpmText = "\(song.bpm)"
                recordManager.fetchRecordings(for: song.id)
            }
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
                Text("ステータス")
                TextField("例: 練習中、本番OK、要修正", text: $song.statusLabel)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
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
                in: 0 ... 12
            )
        }
    }

    private var scrollSection: some View {
        Section {
            Stepper(
                "スクロール速度: \(Int(song.scrollSpeed)) pt/秒",
                value: $song.scrollSpeed,
                in: 10 ... 300,
                step: 10
            )
        } header: {
            Text("スクロール")
        } footer: {
            Text("数値が大きいほど速くスクロールします")
                .font(.caption)
        }
    }

    private var recordingsSection: some View {
        Section("この曲の録音") {
            if recordManager.recordings.isEmpty {
                Text("録音データはありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(recordManager.recordings, id: \.self) { url in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(displayFileName(url: url))
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(fileDate(url: url))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: recordManager.playingURL == url ? "stop.circle.fill" : "play.circle")
                            .font(.title2)
                            .foregroundColor(recordManager.playingURL == url ? .red : .blue)
                    }
                    // ここがポイント：透明な部分も含めてタップに反応させる
                    .contentShape(Rectangle())
                    .onTapGesture {
                        recordManager.togglePlayback(for: url)
                    }
                }
                .onDelete { offsets in
                    recordManager.deleteRecording(at: offsets, for: song.id)
                }
            }
        }
    }

    private func displayFileName(url: URL) -> String {
        let name = url.lastPathComponent
        return name.replacingOccurrences(of: "\(song.id.uuidString)-", with: "")
    }

    private func fileDate(url: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let date = attributes?[.creationDate] as? Date ?? Date()
        return date.formatted(date: .numeric, time: .shortened)
    }

    private var prompterSection: some View {
        Section {
            Stepper(
                "スクロール速度: \(Int(song.prompterSpeed)) pt/秒",
                value: $song.prompterSpeed,
                in: 10 ... 400,
                step: 10
            )
        } header: {
            Text("テレプロンプター")
        } footer: {
            Text("横画面テレプロンプター専用のスクロール速度です")
                .font(.caption)
        }
    }

    private var memoSection: some View {
        Section("メモ") {
            TextField("例: 2026春セットリスト", text: $song.memo, axis: .vertical)
                .lineLimit(4 ... 8)
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
