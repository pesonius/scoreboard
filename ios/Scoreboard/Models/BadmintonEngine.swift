import Foundation

// MARK: - State

struct BadmintonState: Codable {
    var sport: String = "badminton"
    var sessionMode: Bool
    var bestOf: Int?
    var targetScore: Int
    var setsWon: [Int]
    var currentGame: Int
    var gamesHistory: [GameRecord]
    var points: [Int]
    var server: Int
    var initialServer: Int
    var matchOver: Bool
    var gameOver: Bool        // session mode: game ended, waiting to continue
    var lastGameWinner: Int?  // session mode: winner of just-finished game
    var winner: Int?
    var startedAt: Date
    var gameStartedAt: Date?
    var lastPointAt: Date?
    var pointDurations: [Int]
    var version: Int = 1

    struct GameRecord: Codable {
        var points: [Int]
    }
}

// MARK: - Display

struct DisplayScore {
    var p1: String
    var p2: String
    var extra: String?
}

// MARK: - Engine

enum BadmintonEngine {

    static func initState(config: MatchConfig) -> BadmintonState {
        let now = Date()
        return BadmintonState(
            sessionMode: config.sessionMode,
            bestOf: config.sessionMode ? nil : config.bestOf,
            targetScore: config.targetScore,
            setsWon: [0, 0],
            currentGame: 1,
            gamesHistory: [],
            points: [0, 0],
            server: config.initialServer,
            initialServer: config.initialServer,
            matchOver: false,
            gameOver: false,
            lastGameWinner: nil,
            winner: nil,
            startedAt: now,
            gameStartedAt: now,
            lastPointAt: nil,
            pointDurations: []
        )
    }

    static func applyPoint(_ state: BadmintonState, player: Int) -> BadmintonState {
        var s = state
        s.points[player] += 1
        s.server = player  // rally-point scoring: winner of rally serves next

        let p0 = s.points[0], p1 = s.points[1]

        if let gameWinner = isGameOver(p0: p0, p1: p1, targetScore: s.targetScore) {
            if s.sessionMode {
                s.setsWon[gameWinner] += 1
                s.gamesHistory.append(.init(points: s.points))
                s.gameOver = true
                s.lastGameWinner = gameWinner
            } else {
                startNextGame(&s, winner: gameWinner)
                if !s.matchOver { s.server = player }
            }
        } else {
            // Deciding game: change server when leading player first reaches halfway
            if !s.sessionMode, let bestOf = s.bestOf {
                let decidingGame = Int(ceil(Double(bestOf) / 2)) * 2 - 1
                if s.currentGame == decidingGame {
                    let halfway = Int(ceil(Double(s.targetScore) / 2))
                    let prevMax = max(state.points[0], state.points[1])
                    let nowMax  = max(s.points[0], s.points[1])
                    if prevMax < halfway && nowMax >= halfway {
                        s.server = (s.points[0] >= halfway && s.points[0] > s.points[1]) ? 0 : 1
                    }
                }
            }
        }
        return s
    }

    static func continueSession(_ state: BadmintonState) -> BadmintonState {
        var s = state
        s.gameOver = false
        s.currentGame += 1
        s.points = [0, 0]
        s.server = s.lastGameWinner ?? 0
        s.lastGameWinner = nil
        return s
    }

    static func getDisplayScore(_ state: BadmintonState) -> DisplayScore {
        DisplayScore(p1: "\(state.points[0])", p2: "\(state.points[1])", extra: nil)
    }

    // MARK: - Private helpers

    static func isGameOver(p0: Int, p1: Int, targetScore: Int) -> Int? {
        let cap = targetScore + 9
        if p0 >= targetScore || p1 >= targetScore {
            if abs(p0 - p1) >= 2 { return p0 > p1 ? 0 : 1 }
        }
        if p0 == cap { return 0 }
        if p1 == cap { return 1 }
        return nil
    }

    private static func startNextGame(_ s: inout BadmintonState, winner: Int) {
        s.setsWon[winner] += 1
        s.gamesHistory.append(.init(points: s.points))
        checkMatchOver(&s)
        if !s.matchOver {
            s.currentGame += 1
            s.points = [0, 0]
        }
    }

    private static func checkMatchOver(_ s: inout BadmintonState) {
        guard let bestOf = s.bestOf else { return }
        let needed = Int(ceil(Double(bestOf) / 2))
        if s.setsWon[0] >= needed { s.matchOver = true; s.winner = 0 }
        if s.setsWon[1] >= needed { s.matchOver = true; s.winner = 1 }
    }
}
