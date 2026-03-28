import SwiftUI

struct CenterColumnView: View {
    @ObservedObject var vm: ScoreboardViewModel
    let onSetup:      () -> Void
    let onEndSession: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Sport icon
            Text("🏸")
                .font(.system(size: 28))

            // Game label
            Text(vm.gameLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#aaaaaa"))

            // Sets tally
            HStack(spacing: 4) {
                Text("\(vm.state.setsWon[0])")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(":")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color(hex: "#666666"))
                Text("\(vm.state.setsWon[1])")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Timers
            VStack(spacing: 2) {
                timerRow(value: vm.sessionTime, label: "session")
                timerRow(value: vm.gameTime,    label: "game")
                timerRow(value: vm.rallyTime,   label: "rally")
            }

            Spacer()

            // Buttons
            VStack(spacing: 6) {
                Button(action: { vm.handleUndo() }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12))
                }
                .buttonStyle(CourtButtonStyle())

                Button("Setup", action: onSetup)
                    .buttonStyle(CourtButtonStyle(dim: true))

                if vm.config.sessionMode {
                    Button("End", action: onEndSession)
                        .buttonStyle(CourtButtonStyle(danger: true))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color(hex: "#0d0d0d"))
    }

    @ViewBuilder
    private func timerRow(value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "#666666"))
        }
    }
}

// MARK: - Button style

struct CourtButtonStyle: ButtonStyle {
    var dim:    Bool = false
    var danger: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(danger ? .white : (dim ? Color(hex: "#888888") : Color(hex: "#cccccc")))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(danger ? Color(hex: "#8b0000") : Color(hex: "#2a2a2a"))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
    }
}
