import SwiftUI

/// 横スクロール テレプロンプター（ランドスケープ専用）
struct TeleprompterView: View {
    let song: Song
    let viewModel: ScrollViewModel
    let chordLookup: (UUID) -> ChordDiagram?
    let onExit: () -> Void

    // コンテンツ横スクロール
    @State private var lastDragTranslation: CGFloat = 0

    // ストラクトラベル
    @State private var showStructLabels: Bool = true
    @State private var showLabelSheet: Bool = false
    @State private var editingSection: LyricsSection? = nil
    @State private var editingLabel: String = ""

    private let columnWidth: CGFloat    = 280
    private let diagramW: CGFloat       = 64
    private let diagramH: CGFloat       = 36
    private let timelineH: CGFloat      = 44
    private let sideBarW: CGFloat       = 52

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // メインエリア
            VStack(spacing: 0) {
                scrollContent
                playheadTimeline
            }

            // 右サイドバー
            rightSideBar
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showLabelSheet) {
            structLabelSheet
        }
    }

    // MARK: - スクロールコンテンツ

    private var scrollContent: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 0) {
                // 先頭を画面中央から開始するための空白
                Color.clear.frame(width: geo.size.width * 0.5)
                ForEach(song.sortedSections) { section in
                    sectionColumn(section, height: geo.size.height)
                }
                Color.clear.frame(width: geo.size.width * 0.6)
            }
            .contentShape(Rectangle())   // 余白でもジェスチャーを受け取る
            .background(
                GeometryReader { inner in
                    Color.clear
                        .onAppear { viewModel.contentWidth = inner.size.width }
                        .onChange(of: inner.size.width) { _, w in viewModel.contentWidth = w }
                }
            )
            .offset(x: -viewModel.scrollOffset)
            .onAppear { viewModel.viewWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, w in viewModel.viewWidth = w }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { v in
                        let d = v.translation.width - lastDragTranslation
                        lastDragTranslation = v.translation.width
                        viewModel.manualScrollH(delta: -d)
                    }
                    .onEnded { v in
                        lastDragTranslation = 0
                        viewModel.manualScrollEndH(velocity: -v.velocity.width)
                    }
            )
        }
        .clipped()
        .background(Color(.systemBackground))
    }

    // MARK: - ストラクトラベル編集シート

    private var structLabelSheet: some View {
        NavigationStack {
            Form {
                Section("メモ") {
                    TextField("例: Aメロ、サビ、エフェクター①", text: $editingLabel)
                        .autocorrectionDisabled()
                }
                if let sec = editingSection,
                   !sec.structLabel.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Button("メモを削除", role: .destructive) {
                            editingSection?.structLabel = ""
                            showLabelSheet = false
                        }
                    }
                }
            }
            .navigationTitle("セクションメモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showLabelSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        editingSection?.structLabel = editingLabel.trimmingCharacters(in: .whitespaces)
                        showLabelSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - 再生タイムライン

    private var playheadTimeline: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress: CGFloat = viewModel.maxScrollOffsetH > 0
                ? min(1, viewModel.scrollOffset / viewModel.maxScrollOffsetH)
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)

                Capsule()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: max(0, w * progress), height: 6)

                ForEach(song.teleprompterMarkers, id: \.self) { pos in
                    markerShape(pos: pos, trackWidth: w)
                }

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .offset(x: w * progress - 9)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if viewModel.isPlaying { viewModel.pause() }
                        let norm = Double(max(0, min(w, v.location.x)) / w)
                        viewModel.seekToNormalized(norm)
                    }
            )
        }
        .padding(.horizontal, 16)
        .frame(height: timelineH)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    private func markerShape(pos: Double, trackWidth: CGFloat) -> some View {
        let x = CGFloat(pos) * trackWidth
        return VStack(spacing: 0) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.orange)
                .frame(width: 2, height: 14)
        }
        .offset(x: x - 1)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .onTapGesture {
            song.teleprompterMarkers.removeAll { abs($0 - pos) < 0.001 }
        }
    }

    // MARK: - 右サイドバー

    private var rightSideBar: some View {
        VStack(spacing: 24) {
            Spacer()

            Button { viewModel.toggle() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }

            Button {
                song.chordDisplayMode = song.chordDisplayMode.next
            } label: {
                Image(systemName: song.chordDisplayMode.systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showStructLabels.toggle()
                }
            } label: {
                Image(systemName: showStructLabels ? "tag.fill" : "tag")
                    .font(.system(size: 22))
                    .foregroundStyle(showStructLabels ? Color.indigo : Color.secondary)
            }

            Button {
                let pos = viewModel.maxScrollOffsetH > 0
                    ? Double(min(1, viewModel.scrollOffset / viewModel.maxScrollOffsetH))
                    : 0
                song.teleprompterMarkers.append(pos)
            } label: {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
            }

            Spacer()

            Button { onExit() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
        }
        .frame(width: sideBarW)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .leading) { Divider() }
    }

    // MARK: - セクション列

    @ViewBuilder
    private func sectionColumn(_ section: LyricsSection, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                chordAreaView(for: section)
                if !section.lyrics.isEmpty {
                    Text(section.lyrics)
                        .font(.system(size: 30))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(width: columnWidth, height: height, alignment: .top)
            // メモをセクション列の底部にオーバーレイ（タイムライン直上）
            .overlay(alignment: .bottom) {
                if showStructLabels {
                    sectionMemoArea(for: section)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func sectionMemoArea(for section: LyricsSection) -> some View {
        let memo = section.structLabel.trimmingCharacters(in: .whitespaces)
        Button {
            editingLabel = section.structLabel
            editingSection = section
            showLabelSheet = true
        } label: {
            ZStack(alignment: .topLeading) {
                // メモテキスト or プレースホルダー
                if memo.isEmpty {
                    Text("メモを追加…")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                } else {
                    Text(memo)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                }
            }
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - コードエリア

    @ViewBuilder
    private func chordAreaView(for section: LyricsSection) -> some View {
        let placements = section.chordPlacements
        let showAnyDiag = placements.contains { effectiveShowDiagram($0) }
        let showAnyName = placements.contains { effectiveShowName($0, chord: chordLookup($0.chordID)) }
        let areaH: CGFloat = showAnyDiag
            ? (showAnyName ? diagramH + 20 : diagramH + 8)
            : (showAnyName ? 22 : 0)

        if !placements.isEmpty && areaH > 0 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    ForEach(placements) { placement in
                        let ch = chordLookup(placement.chordID)
                        let showDiag = effectiveShowDiagram(placement)
                        let showName = effectiveShowName(placement, chord: ch)
                        let yCtr: CGFloat = showDiag
                            ? (showName ? (diagramH + 20) / 2 : (diagramH + 8) / 2)
                            : 11

                        VStack(spacing: 1) {
                            if let ch {
                                if showDiag {
                                    FretBoardView(fingering: ch.fingering.effectiveFingering)
                                        .frame(width: diagramW, height: diagramH)
                                }
                                if showName && !ch.name.isEmpty {
                                    Text(ch.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .position(x: placement.normalizedX * geo.size.width, y: yCtr)
                    }
                }
            }
            .frame(height: areaH)
        }
    }

    // MARK: - 表示判定

    private func effectiveShowDiagram(_ placement: ChordPlacement) -> Bool {
        switch song.chordDisplayMode {
        case .custom:            return placement.showDiagram
        case .diagramOnly:       return true
        case .nameOnly, .hidden: return false
        }
    }

    private func effectiveShowName(_ placement: ChordPlacement, chord: ChordDiagram?) -> Bool {
        guard let chord, !chord.name.isEmpty else { return false }
        switch song.chordDisplayMode {
        case .custom:               return placement.showName
        case .nameOnly:             return true
        case .diagramOnly, .hidden: return false
        }
    }
}
