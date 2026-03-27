import AVFoundation
import Foundation

class RecordManager: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    // 再生状態の管理
    @Published var playingURL: URL?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1.0
    private var timer: Timer?

    func start(songID: UUID, songTitle: String) {
        // オーディオセッションの設定（録音可能にする）
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("セッションの設定に失敗しました: \(error)")
            return
        }

        // 保存先URLの決定 (Documentsディレクトリ配下)
        let fileName = generateFileName(songID: songID, songTitle: songTitle)
        let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = docPath.appendingPathComponent(fileName)

        // 録音設定
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        // レコーダーの初期化と開始
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            print("録音開始: \(audioURL)")
        } catch {
            print("録音の開始に失敗しました: \(error)")
        }
    }

    private func generateFileName(songID: UUID, songTitle: String) -> String {
        // 安全な曲名の抽出（英数字以外を排除し、連続する記号をまとめる）
        let safeTitle = songTitle
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        let finalTitle = safeTitle.isEmpty ? "no_title" : safeTitle

        // 日時文字列の生成
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = formatter.string(from: Date())

        // 結合して拡張子を付与
        return "\(songID.uuidString)-\(finalTitle)-\(dateString).m4a"
    }

    func stop(songID: UUID) {
        audioRecorder?.stop()
        isRecording = false
        fetchRecordings(for: songID)
        print("録音停止")
    }

    func fetchRecordings(for songID: UUID) {
        let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let content = try FileManager.default.contentsOfDirectory(at: docPath, includingPropertiesForKeys: nil)
            // ファイル名が songID で始まるものだけをフィルタリング
            recordings = content.filter {
                $0.lastPathComponent.hasPrefix(songID.uuidString) && $0.pathExtension == "m4a"
            }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            print("取得失敗: \(error)")
        }
    }

    func deleteRecording(at offsets: IndexSet, for songID: UUID) {
        for index in offsets {
            let url = recordings[index]
            do {
                // 再生中なら止める
                if playingURL == url {
                    stopPlayback()
                }
                // 物理ファイルを削除
                try FileManager.default.removeItem(at: url)
            } catch {
                print("ファイル削除失敗: \(error)")
            }
        }
        // リストを再取得してUIを更新
        fetchRecordings(for: songID)
    }

    func togglePlayback(for url: URL) {
        // 1. 別のファイル、またはプレイヤーが未作成の場合は新規再生
        if playingURL != url || audioPlayer == nil {
            startPlayback(url: url)
            return
        }

        // 2. 同じファイルの場合は pause / play を切り替える（インスタンスは壊さない）
        guard let player = audioPlayer else { return }

        if player.isPlaying {
            player.pause() // stop()ではなくpause()を使う
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    private func startPlayback(url: URL) {
        // 新規再生時のみ、古いタイマーとプレイヤーを破棄
        timer?.invalidate()
        audioPlayer?.stop()
        audioPlayer = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()

            audioPlayer = player
            duration = player.duration
            playingURL = url
            isPlaying = true

            player.play()
            startTimer()
        } catch {
            print("再生失敗: \(error)")
        }
    }

    /// 完全に停止してプレイヤーを片付ける（Xボタン用）
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil // ここでnilにするから次は新規再生になる
        timer?.invalidate()
        timer = nil
        playingURL = nil
        isPlaying = false
        currentTime = 0
    }

    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            // UIスレッドで更新
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
            }
        }
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        // 再生中だった場合は、シーク後も再生を継続させる（念のため）
        if isPlaying {
            audioPlayer?.play()
        }
    }
}

extension RecordManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        DispatchQueue.main.async {
            self.stopPlayback() // 終了時は状態をリセット
        }
    }
}
