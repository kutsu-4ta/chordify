import SwiftData
import SwiftUI

struct EffectorMemoSheet: View {
    @Bindable var memo: EffectorMemo
    var isEditing: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("メモ") {
                    if isEditing {
                        TextField("メモを入力", text: $memo.text, axis: .vertical)
                            .lineLimit(4 ... 8)
                    } else {
                        Text(memo.text.isEmpty ? "（なし）" : memo.text)
                            .foregroundColor(memo.text.isEmpty ? .secondary : .primary)
                    }
                }

                Section("ツマミ設定") {
                    if isEditing {
                        TextField("ツマミ設定を入力", text: $memo.knobSettings, axis: .vertical)
                            .lineLimit(4 ... 8)
                    } else {
                        Text(memo.knobSettings.isEmpty ? "（なし）" : memo.knobSettings)
                            .foregroundColor(memo.knobSettings.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle("エフェクターメモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
