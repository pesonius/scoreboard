import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var vm: ScoreboardViewModel
    let onSetup: () -> Void

    @State private var developerMode = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    HStack(spacing: 2) {
                        scorePanel(playerIndex: 0, score: vm.displayScore.p1)
                        scorePanel(playerIndex: 1, score: vm.displayScore.p2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    bottomBar
                }

                // Invisible keyboard responder (receives BLE clicker events)
                KeyboardResponderView(inputManager: vm.inputManager)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)

                // Hint bar
                if vm.showHint {
                    VStack {
                        Spacer()
                        HintView(config: vm.config)
                            .padding(.bottom, 60)
                    }
                    .opacity(vm.hintFading ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: vm.hintFading)
                }

                // Game-over overlay
                if vm.showGameOverOverlay {
                    GameOverOverlayView(vm: vm, onSetup: onSetup)
                }

                // Debug overlay
                if developerMode { debugOverlay }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            developerMode = UserDefaults.standard.bool(forKey: "scoreboard.developerMode")
            UIApplication.shared.isIdleTimerDisabled = true
            vm.volumeManager.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            vm.volumeManager.stop()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            playerNameBar(index: 0)
            centerInfo
            playerNameBar(index: 1)
        }
        .frame(height: 80)
        .background(Color(hex: "#0d0d0d"))
    }

    private func playerNameBar(index: Int) -> some View {
        let isServer = vm.state.server == index
        return ZStack {
            (isServer ? Color(hex: "#1a7a1a") : Color(hex: "#1a1a1a"))
                .animation(.easeInOut(duration: 0.2), value: isServer)
            HStack {
                if index == 1 && isServer {
                    shuttleIcon.padding(.leading, 12)
                }
                Spacer()
                nameStack(index: index)
                Spacer()
                if index == 0 && isServer {
                    shuttleIcon.padding(.trailing, 12)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func nameStack(index: Int) -> some View {
        let name    = vm.config.playerNames[index]
        let partner = vm.config.partnerNames[index]
        if partner.isEmpty {
            Text(name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(partner)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private var shuttleIcon: some View {
        Image(systemName: "circle.fill")
            .foregroundStyle(Color(hex: "#4cff4c"))
            .font(.system(size: 10))
    }

    private var centerInfo: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text("🏸").font(.system(size: 18))
                Text(vm.gameLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#aaaaaa"))
                HStack(spacing: 3) {
                    Text("\(vm.state.setsWon[0])")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(":")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color(hex: "#666666"))
                    Text("\(vm.state.setsWon[1])")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            HStack(spacing: 14) {
                timerItem(value: vm.sessionTime, label: "session")
                timerItem(value: vm.gameTime,    label: "game")
                timerItem(value: vm.rallyTime,   label: "rally")
            }
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 160)
    }

    @ViewBuilder
    private func timerItem(value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "#666666"))
        }
    }

    // MARK: - Score panels

    private func scorePanel(playerIndex: Int, score: String) -> some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "#111111")
                Text(score)
                    .font(.system(
                        size: min(geo.size.width * 0.68, geo.size.height * 0.72),
                        weight: .bold,
                        design: .default
                    ))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundStyle(vm.undoFlash ? Color.orange : Color.white)
                    .animation(.easeOut(duration: 0.15), value: vm.undoFlash)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { vm.handlePoint(playerIndex) }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            Button(action: { vm.handleUndo() }) {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(CourtButtonStyle())

            Spacer()

            Button("End") { vm.endSession(); onSetup() }
                .buttonStyle(CourtButtonStyle(danger: true))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(hex: "#0d0d0d"))
    }

    // MARK: - Debug overlay

    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DEBUG")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.yellow)
                Spacer()
                Button("Clear") { vm.debugLog.removeAll() }
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(vm.debugLog, id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
        .frame(width: 340, height: 200)
        .background(Color.black.opacity(0.75))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(12)
        .allowsHitTesting(true)
    }
}
