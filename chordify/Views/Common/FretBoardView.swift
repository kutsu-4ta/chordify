import SwiftUI

/// 表示専用の水平コードダイアグラム
/// 左 = 低フレット（ナット側）、上 = 高音弦（e, B, G, D, A, E 上から順）
struct FretBoardView: View {
    let fingering: ChordFingering

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
        )
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let fretCount = fingering.fretCount

        let xoWidth: CGFloat = size.width * 0.13
        let topPad: CGFloat = size.height * 0.05
        let bottomPad: CGFloat = size.height * 0.07

        let nutX: CGFloat = xoWidth
        let gridWidth: CGFloat = size.width - nutX
        let gridTop: CGFloat = topPad
        let gridBottom: CGFloat = size.height - bottomPad
        let gridHeight: CGFloat = gridBottom - gridTop

        let stringSpacing: CGFloat = gridHeight / 5.0
        let fretCellWidth: CGFloat = gridWidth / CGFloat(fretCount)

        let fg = GraphicsContext.Shading.color(.primary)

        func sy(_ si: Int) -> CGFloat {
            gridTop + CGFloat(5 - si) * stringSpacing
        }
        func fx(_ fi: Int) -> CGFloat {
            nutX + CGFloat(fi) * fretCellWidth
        }

        // 背景（薄いグレー）
        let bgRect = CGRect(x: nutX, y: gridTop, width: gridWidth, height: gridHeight)
        context.fill(
            Path(roundedRect: bgRect, cornerRadius: 1.5),
            with: .color(.primary.opacity(0.04))
        )

        // ナット
        context.stroke(Path { p in
            p.move(to: CGPoint(x: nutX, y: gridTop))
            p.addLine(to: CGPoint(x: nutX, y: gridBottom))
        }, with: fg, lineWidth: fingering.startFret == 1 ? 3 : 1.2)

        if fingering.startFret > 1 {
            context.draw(
                Text("\(fingering.startFret)fr")
                    .font(.system(size: max(7, size.width * 0.085), weight: .medium))
                    .foregroundStyle(Color.secondary),
                at: CGPoint(x: nutX + 2, y: gridBottom + bottomPad * 0.6),
                anchor: .leading
            )
        }

        // フレット線（垂直）
        for fi in 1 ... fretCount {
            context.stroke(Path { p in
                p.move(to: CGPoint(x: fx(fi), y: gridTop))
                p.addLine(to: CGPoint(x: fx(fi), y: gridBottom))
            }, with: fg, lineWidth: 0.7)
        }

        // 弦線（水平）低音弦ほど太く
        for si in 0 ..< 6 {
            context.stroke(Path { p in
                p.move(to: CGPoint(x: nutX, y: sy(si)))
                p.addLine(to: CGPoint(x: size.width, y: sy(si)))
            }, with: fg, lineWidth: 0.5 + CGFloat(5 - si) * 0.18)
        }

        // X / O / ドット
        let xoCX: CGFloat = xoWidth * 0.5
        let indR: CGFloat = min(xoWidth * 0.34, stringSpacing * 0.38)
        let dotR: CGFloat = min(fretCellWidth * 0.36, stringSpacing * 0.44)

        for si in 0 ..< 6 {
            let sf = fingering.strings[si]
            let y = sy(si)

            if sf.isMuted {
                let r = indR
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: xoCX - r, y: y - r))
                    p.addLine(to: CGPoint(x: xoCX + r, y: y + r))
                    p.move(to: CGPoint(x: xoCX + r, y: y - r))
                    p.addLine(to: CGPoint(x: xoCX - r, y: y + r))
                }, with: fg, lineWidth: 1.4)

            } else if sf.isOpen {
                context.stroke(
                    Path(ellipseIn: CGRect(x: xoCX - indR, y: y - indR,
                                           width: indR * 2, height: indR * 2)),
                    with: fg, lineWidth: 1.2
                )

            } else if sf.isPressed {
                let rel = sf.fret - fingering.startFret + 1
                if (1 ... fretCount).contains(rel) {
                    let dotX = fx(rel) - fretCellWidth * 0.5
                    context.fill(
                        Path(ellipseIn: CGRect(x: dotX - dotR, y: y - dotR,
                                               width: dotR * 2, height: dotR * 2)),
                        with: fg
                    )
                }
            }
        }
    }
}

#Preview {
    let f = ChordFingering(
        strings: [
            StringFingering(fret: -1),
            StringFingering(fret: 3),
            StringFingering(fret: 2),
            StringFingering(fret: 0),
            StringFingering(fret: 1),
            StringFingering(fret: 0),
        ],
        startFret: 1, fretCount: 5
    )
    FretBoardView(fingering: f)
        .frame(width: 120, height: 60)
        .padding()
}
