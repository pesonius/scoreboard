import SwiftUI

// MARK: - Game Over Overlay (session mode)

struct GameOverOverlayView: View {
    @ObservedObject var vm: ScoreboardViewModel
    let onSetup: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            VStack(spacing: 16) {
                Text("Game \(vm.state.currentGame)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(hex: "#aaaaaa"))

                if let w = vm.state.lastGameWinner {
                    Text(teamName(w))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color(hex: "#4cff4c"))
                }

                if let last = vm.state.gamesHistory.last {
                    Text("\(last.points[0]) – \(last.points[1])")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("\(teamName(0))  \(vm.state.setsWon[0]) – \(vm.state.setsWon[1])  \(teamName(1))")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#aaaaaa"))

                HStack(spacing: 20) {
                    Button("Setup") { vm.endSession(); onSetup() }
                        .buttonStyle(OverlayButtonStyle())
                    Button("Continue") { vm.continueSession() }
                        .buttonStyle(OverlayButtonStyle(success: true))
                }
                .padding(.top, 8)
            }
            .padding(40)
        }
        .ignoresSafeArea()
    }

    private func teamName(_ index: Int) -> String {
        let name    = vm.config.playerNames[index]
        let partner = vm.config.partnerNames[index]
        return partner.isEmpty ? name : "\(name) / \(partner)"
    }
}

// MARK: - Hint bar

struct HintView: View {
    let config: MatchConfig

    var body: some View {
        HStack(spacing: 20) {
            hintItem(key: friendlyKey(config.keymap.button1), action: config.playerNames[0])
            Text("│").foregroundStyle(Color(hex: "#333333"))
            hintItem(key: friendlyKey(config.keymap.button2), action: config.playerNames[1])
            Text("│").foregroundStyle(Color(hex: "#333333"))
            Text("Hold ≥ 0.8s → Undo")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#888888"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func hintItem(key: String, action: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color(hex: "#333333"))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.white)
            Text(action)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#aaaaaa"))
        }
    }

    private func friendlyKey(_ key: String) -> String {
        switch key {
        case "ArrowLeft":  return "←"
        case "ArrowRight": return "→"
        case "ArrowUp":    return "↑"
        case "ArrowDown":  return "↓"
        case "Space":      return "SPC"
        case "Enter":      return "RET"
        default:           return key
        }
    }
}

// MARK: - Overlay button style

struct OverlayButtonStyle: ButtonStyle {
    var success: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(success ? Color(hex: "#1a7a1a") : Color(hex: "#3a3a3a"))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
    }
}
