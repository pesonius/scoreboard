import SwiftUI

struct PlayerPanelView: View {
    let name:      String
    let score:     String
    let isServer:  Bool
    let isRight:   Bool   // right side flips serve icon to the left
    let undoFlash: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Name bar
                ZStack {
                    (isServer ? Color(hex: "#1a7a1a") : Color(hex: "#1a1a1a"))
                        .animation(.easeInOut(duration: 0.2), value: isServer)
                    HStack {
                        if isRight && isServer {
                            shuttleIcon
                                .padding(.leading, 8)
                        }
                        Spacer()
                        Text(name)
                            .font(.system(size: min(geo.size.width * 0.07, 26), weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer()
                        if !isRight && isServer {
                            shuttleIcon
                                .padding(.trailing, 8)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: max(geo.size.height * 0.12, 36))

                // Score
                Spacer()
                Text(score)
                    .font(.system(
                        size: score.count <= 1
                            ? min(geo.size.width * 0.55, geo.size.height * 0.62)
                            : min(geo.size.width * 0.38, geo.size.height * 0.52),
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(undoFlash ? Color.orange : Color.white)
                    .animation(.easeOut(duration: 0.15), value: undoFlash)
                    .monospacedDigit()
                Spacer()
            }
        }
        .background(Color(hex: "#111111"))
    }

    private var shuttleIcon: some View {
        Image(systemName: "circle.fill")
            .foregroundStyle(Color(hex: "#4cff4c"))
            .font(.system(size: 10))
    }
}

// MARK: - Hex color convenience

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8)  & 0xFF) / 255
            b = Double( int        & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
