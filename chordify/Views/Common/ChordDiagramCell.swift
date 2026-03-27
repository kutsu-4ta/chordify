import SwiftUI

/// コード一覧・ピッカー用の小型ダイアグラムセル
struct ChordDiagramCell: View {
    let chord: ChordDiagram?

    var body: some View {
        VStack(spacing: 2) {
            if let chord {
                FretBoardView(fingering: chord.fingering.effectiveFingering)
                    .frame(width: 90, height: 50)
                Text(chord.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Color.clear
                    .frame(width: 90, height: 50)
                Text(" ")
                    .font(.system(size: 11))
            }
        }
        .frame(width: 94)
    }
}

#Preview {
    HStack(spacing: 12) {
        ChordDiagramCell(chord: nil)
        ChordDiagramCell(chord: {
            let c = ChordDiagram(name: "Am")
            c.fingering = ChordFingering(
                strings: [
                    StringFingering(fret: -1),
                    StringFingering(fret: 0),
                    StringFingering(fret: 2),
                    StringFingering(fret: 2),
                    StringFingering(fret: 1),
                    StringFingering(fret: 0),
                ],
                startFret: 1
            )
            return c
        }())
    }
    .padding()
}
