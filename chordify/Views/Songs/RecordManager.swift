    import Foundation
    import AVFoundation

    class RecordManager: NSObject, ObservableObject {
        private var audioRecorder: AVAudioRecorder?
        @Published var isRecording = false
        @Published var recordings: [URL] = []

        func start(songID: UUID, songTitle: String){
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
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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
                self.recordings = content.filter {
                    $0.lastPathComponent.hasPrefix(songID.uuidString) && $0.pathExtension == "m4a"
                }.sorted { $0.lastPathComponent > $1.lastPathComponent }
            } catch {
                print("取得失敗: \(error)")
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
    }
