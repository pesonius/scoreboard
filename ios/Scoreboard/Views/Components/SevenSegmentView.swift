import SwiftUI

// MARK: - Seven-segment digit

private enum Seg: Int, CaseIterable {
    case a, b, c, d, e, f, g
}

private let segmentMap: [Character: [Seg]] = [
    "0": [.a, .b, .c, .d, .e, .f],
    "1": [.b, .c],
    "2": [.a, .b, .d, .e, .g],
    "3": [.a, .b, .c, .d, .g],
    "4": [.b, .c, .f, .g],
    "5": [.a, .c, .d, .f, .g],
    "6": [.a, .c, .d, .e, .f, .g],
    "7": [.a, .b, .c],
    "8": [.a, .b, .c, .d, .e, .f, .g],
    "9": [.a, .b, .c, .d, .f, .g],
]

struct SevenSegmentDigit: View {
    let char: Character
    let width: CGFloat
    let height: CGFloat
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let active = Set(segmentMap[char] ?? [])
            let w = size.width
            let h = size.height
            let t = w * 0.13        // segment thickness
            let g = t * 0.3         // gap between segments at corners
            let r = t * 0.4         // corner radius of each segment

            func hSeg(y: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: t + g, y: y, width: w - 2 * (t + g), height: t), cornerRadius: r)
            }
            func vSeg(x: CGFloat, topHalf: Bool) -> Path {
                let y = topHalf ? (t + g) : (h / 2 + g)
                let segH = h / 2 - t - 2 * g
                return Path(roundedRect: CGRect(x: x, y: y, width: t, height: segH), cornerRadius: r)
            }

            let paths: [Seg: Path] = [
                .a: hSeg(y: 0),
                .b: vSeg(x: w - t, topHalf: true),
                .c: vSeg(x: w - t, topHalf: false),
                .d: hSeg(y: h - t),
                .e: vSeg(x: 0, topHalf: false),
                .f: vSeg(x: 0, topHalf: true),
                .g: hSeg(y: h / 2 - t / 2),
            ]

            for seg in Seg.allCases {
                var c = ctx
                c.opacity = active.contains(seg) ? 1.0 : 0.08
                c.fill(paths[seg]!, with: .foreground)
            }
        }
        .foregroundColor(color)
        .frame(width: width, height: height)
    }
}

// MARK: - Multi-digit display

struct SevenSegmentText: View {
    let value: String
    let digitHeight: CGFloat
    var color: Color = .segmentGreen

    private var digitWidth: CGFloat { digitHeight * 0.58 }
    private var spacing:    CGFloat { digitWidth * 0.18 }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(value.enumerated()), id: \.offset) { _, ch in
                SevenSegmentDigit(char: ch, width: digitWidth, height: digitHeight, color: color)
            }
        }
    }
}

// MARK: - Color

extension Color {
    static let segmentGreen = Color(red: 0.82, green: 1.0, blue: 0.08)
}
