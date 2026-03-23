import SwiftUI
import AVFoundation
import Observation

// MARK: - ScrollViewModel

@Observable final class ScrollViewModel {
    var isPlaying: Bool = false
    /// 現在のスクロールオフセット（pt）
    var scrollOffset: CGFloat = 0
    var speedMultiplier: Double = 1.0
    var clickEnabled: Bool

    /// コンテンツ全体の高さ（ビューから設定）
    var contentHeight: CGFloat = 0
    /// 表示エリアの高さ（ビューから設定）
    var viewHeight: CGFloat = 0
    /// 手動ドラッグ中フラグ（自動スクロールタイマーを一時停止）
    var isDragging: Bool = false

    private let song: Song
    private var scrollTimer: Timer?
    private var clickTimer: Timer?

    private let audioEngine = AVAudioEngine()
    private let clickPlayer = AVAudioPlayerNode()
    private var clickBuffer: AVAudioPCMBuffer?

    /// タイマー間隔（秒）
    private static let timerInterval: Double = 0.5

    init(song: Song) {
        self.song = song
        self.clickEnabled = song.isClickEnabled
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.attach(clickPlayer)
        audioEngine.connect(clickPlayer, to: audioEngine.mainMixerNode, format: format)
        clickBuffer = makeClickBuffer(format: format)
        try? audioEngine.start()
    }

    private func makeClickBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * 0.05)  // 50ms
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // 880Hz の短いサイン波 + 指数減衰
            data[i] = Float(sin(2 * .pi * 880 * t) * exp(-t * 80) * 0.9)
        }
        return buffer
    }

    private func playClick() {
        guard let buffer = clickBuffer else { return }
        if !audioEngine.isRunning { try? audioEngine.start() }
        clickPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !clickPlayer.isPlaying { clickPlayer.play() }
    }

    var bpm: Int { song.bpm }
    var scrollSpeed: Double { song.scrollSpeed }
    var clickInterval: Double { 60.0 / Double(song.bpm) }

    /// スクロール可能な最大オフセット
    var maxScrollOffset: CGFloat {
        max(0, contentHeight - viewHeight * 0.25)
    }

    func play() {
        guard !isPlaying else { return }
        // 末尾に達していたら先頭から再生
        if scrollOffset >= maxScrollOffset && maxScrollOffset > 0 {
            scrollOffset = 0
        }
        isPlaying = true
        startScrollTimer()
        if clickEnabled { startClickTimer() }
    }

    func pause() {
        isPlaying = false
        stopScrollTimer()
        stopClickTimer()
    }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    func setSpeedMultiplier(_ multiplier: Double) {
        speedMultiplier = max(0.25, multiplier)
        if isPlaying {
            stopScrollTimer()
            startScrollTimer()
        }
    }

    private func startScrollTimer() {
        stopScrollTimer()
        let interval = Self.timerInterval
        animateStep(interval: interval)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.animateStep(interval: interval)
        }
        RunLoop.main.add(t, forMode: .common)
        scrollTimer = t
    }

    // MARK: - 手動スクロール

    func manualScroll(deltaY: CGFloat) {
        if isPlaying { pause() }
        isDragging = true
        scrollOffset = max(0, min(maxScrollOffset, scrollOffset + deltaY))
    }

    func manualScrollEnd(velocityY: CGFloat) {
        isDragging = false
        let speed = abs(velocityY)
        guard speed > 80 else { return }
        let dist = min(viewHeight * 2, speed * 0.12) * (velocityY > 0 ? 1 : -1)
        let target = max(0, min(maxScrollOffset, scrollOffset + dist))
        withAnimation(.easeOut(duration: 0.38)) {
            scrollOffset = target
        }
    }

    // MARK: - 自動スクロール内部

    private func animateStep(interval: Double) {
        guard maxScrollOffset > 0, !isDragging else { return }
        let step = CGFloat(scrollSpeed * speedMultiplier * interval)
        let target = min(scrollOffset + step, maxScrollOffset)
        withAnimation(.linear(duration: interval)) {
            scrollOffset = target
        }
        if target >= maxScrollOffset {
            // アニメーション完了後に停止
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                self?.pause()
            }
        }
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func startClickTimer() {
        stopClickTimer()
        guard clickInterval > 0 else { return }
        playClick()
        let t = Timer(timeInterval: clickInterval, repeats: true) { [weak self] _ in
            self?.playClick()
        }
        RunLoop.main.add(t, forMode: .common)
        clickTimer = t
    }

    private func stopClickTimer() {
        clickTimer?.invalidate()
        clickTimer = nil
    }

    func toggleClick() {
        clickEnabled.toggle()
        song.isClickEnabled = clickEnabled
        if isPlaying {
            if clickEnabled { startClickTimer() }
            else { stopClickTimer() }
        }
    }
}

