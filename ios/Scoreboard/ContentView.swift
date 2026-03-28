import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        switch appState.screen {
        case .setup:
            SetupView(
                onStart: { config, state in appState.startMatch(config: config, state: state) },
                onStats: { appState.goToStats() }
            )
        case .scoreboard:
            if let vm = appState.scoreboardVM {
                ScoreboardView(
                    vm: vm,
                    onSetup: { appState.goToSetup() }
                )
            }
        case .stats:
            StatsView(onBack: { appState.goToSetup() })
        }
    }
}
