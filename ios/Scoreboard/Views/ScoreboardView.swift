import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var vm: ScoreboardViewModel
    let onSetup: () -> Void

    @State private var p0Hovered = false
    @State private var p1Hovered = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                HStack(spacing: 0) {
                    // Left side strip (game history)
                    SideStripView(gamesHistory: vm.state.gamesHistory, playerIndex: 0)
                        .frame(width: 40)

                    // Left player panel
                    PlayerPanelView(
                        name:      vm.config.playerNames[0],
                        score:     vm.displayScore.p1,
                        isServer:  vm.state.server == 0,
                        isRight:   false,
                        undoFlash: vm.undoFlash
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(hoverBorder(active: p0Hovered))
                    .onHover {
                        p0Hovered = $0
                        vm.logDebug("hover P1=\($0)")
                    }

                    // Center column
                    CenterColumnView(
                        vm: vm,
                        onSetup:      onSetup,
                        onEndSession: { vm.endSession(); onSetup() }
                    )
                    .frame(width: max(geo.size.width * 0.18, 100))

                    // Right player panel
                    PlayerPanelView(
                        name:      vm.config.playerNames[1],
                        score:     vm.displayScore.p2,
                        isServer:  vm.state.server == 1,
                        isRight:   true,
                        undoFlash: vm.undoFlash
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(hoverBorder(active: p1Hovered))
                    .onHover {
                        p1Hovered = $0
                        vm.logDebug("hover P2=\($0)")
                    }

                    // Right side strip
                    SideStripView(gamesHistory: vm.state.gamesHistory, playerIndex: 1)
                        .frame(width: 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Full-screen tap handler — scores based on cursor hover position
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        let player: Int
                        let reason: String
                        if p1Hovered {
                            player = 1; reason = "hover-P2"
                        } else if p0Hovered {
                            player = 0; reason = "hover-P1"
                        } else {
                            player = location.x < geo.size.width / 2 ? 0 : 1
                            reason = "pos-x\(Int(location.x))"
                        }
                        vm.logDebug("click x=\(Int(location.x)) [\(reason)]")
                        vm.handlePoint(player)
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
                            .padding(.bottom, 12)
                    }
                    .opacity(vm.hintFading ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: vm.hintFading)
                }

                // Game-over overlay (session mode)
                if vm.showGameOverOverlay {
                    GameOverOverlayView(vm: vm)
                }

                // Winner overlay (best-of mode)
                if vm.showWinnerOverlay {
                    WinnerOverlayView(vm: vm, onNewMatch: onSetup)
                }

                // Debug overlay
                debugOverlay
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            vm.volumeManager.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            vm.volumeManager.stop()
        }
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

    // MARK: - Helpers

    @ViewBuilder
    private func hoverBorder(active: Bool) -> some View {
        Rectangle()
            .strokeBorder(Color.white.opacity(active ? 0.35 : 0), lineWidth: 6)
    }
}
