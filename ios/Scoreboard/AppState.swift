import Foundation
import Combine

enum Screen {
    case setup
    case scoreboard
    case stats
}

final class AppState: ObservableObject {
    @Published var screen: Screen = .setup
    @Published var scoreboardVM: ScoreboardViewModel? = nil

    func startMatch(config: MatchConfig, state: BadmintonState) {
        scoreboardVM = ScoreboardViewModel(config: config, state: state)
        screen = .scoreboard
    }

    func goToSetup() {
        scoreboardVM = nil
        screen = .setup
    }

    func goToStats() {
        screen = .stats
    }
}
