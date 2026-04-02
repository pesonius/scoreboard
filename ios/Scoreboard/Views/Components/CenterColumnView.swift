import SwiftUI

struct CenterColumnView: View {
    @ObservedObject var vm: ScoreboardViewModel
    let onSetup:      () -> Void
    let onEndSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // TOP: sport icon, game label, sets tally, timers
            VStack(spacing: 4) {
                Text("🏸")
                    .font(.system(size: 28))

                Text(vm.gameLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#aaaaaa"))

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

                VStack(spacing: 2) {
                    timerRow(value: vm.sessionTime, label: "session")
                    timerRow(value: vm.gameTime,    label: "game")
                    timerRow(value: vm.rallyTime,   label: "rally")
                }
                .padding(.top, 4)
            }
            .padding(.top, 10)

            Spacer()

            // BOTTOM: buttons
            VStack(spacing: 6) {
                Button(action: { vm.handleUndo() }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12))
                }
                .buttonStyle(CourtButtonStyle())

                Button("Setup", action: onSetup)
                    .buttonStyle(CourtButtonStyle(dim: true))

                Button("End", action: onEndSession)
                    .buttonStyle(CourtButtonStyle(danger: true))
            }
            .padding(.bottom, 10)
        }
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
