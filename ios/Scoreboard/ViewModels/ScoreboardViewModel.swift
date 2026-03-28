import Foundation
import Combine
import SwiftUI

final class ScoreboardViewModel: ObservableObject {

    @Published var state:  BadmintonState
    @Published var config: MatchConfig

    // Overlay flags
    @Published var showGameOverOverlay = false
    @Published var showWinnerOverlay   = false

    // Hint
    @Published var showHint   = true
    @Published var hintFading = false

    // Timers display
    @Published var sessionTime = "0:00"
    @Published var gameTime    = "0:00"
    @Published var rallyTime   = "0:00"

    // Visual feedback
    @Published var undoFlash = false

    // Debug log (last 30 events, newest first)
    @Published var debugLog: [String] = []

    let inputManager: InputManager
    let volumeManager = VolumeInputManager()
    private var timerSub: AnyCancellable?
    private var hintTimer: Timer?
    private let storage = AppStorage.shared

    init(config: MatchConfig, state: BadmintonState) {
        self.config = config
        self.state  = state
        self.inputManager = InputManager(keymap: config.keymap)
        inputManager.onPoint = { [weak self] p in self?.handlePoint(p) }
        inputManager.onUndo  = { [weak self] in self?.handleUndo() }
        // Top button = mouse click (cursor at left) → P1 via tap gesture
        // Bottom button = volume UP → P2
        volumeManager.onVolumeUp   = { [weak self] in self?.handleVolumePoint(1) }
        volumeManager.onVolumeDown = { [weak self] in self?.handleVolumePoint(0) }
        volumeManager.onDebug = { [weak self] msg in self?.logDebug("VOL: \(msg)") }
        inputManager.onDebug  = { [weak self] msg in self?.logDebug("KEY: \(msg)") }
        startTimers()
        scheduleHintFade()
    }

    // MARK: - Display

    var displayScore: DisplayScore { BadmintonEngine.getDisplayScore(state) }

    var gameLabel: String {
        config.sessionMode
            ? "Game \(state.currentGame)"
            : "Game \(state.currentGame) of \(state.bestOf ?? config.bestOf)"
    }

    // MARK: - Scoring

    private var lastVolumeAt: Date = .distantPast
    private let volumeCooldown: TimeInterval = 0.4

    func logDebug(_ msg: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        let entry = "\(f.string(from: Date())) \(msg)"
        debugLog.insert(entry, at: 0)
        if debugLog.count > 30 { debugLog.removeLast() }
    }

    func handleVolumePoint(_ player: Int) {
        lastVolumeAt = Date()
        logDebug("→ scoreVol P\(player + 1)")
        scorePoint(player)
    }

    func handlePoint(_ player: Int) {
        let elapsed = Date().timeIntervalSince(lastVolumeAt)
        if elapsed < volumeCooldown {
            logDebug("TAP P\(player + 1) [blocked, vol \(String(format: "%.0f", elapsed * 1000))ms ago]")
            return
        }
        logDebug("TAP → score P\(player + 1)")
        scorePoint(player)
    }

    private func scorePoint(_ player: Int) {

        if state.gameOver  { continueSession(); return }
        if state.matchOver { return }

        let now       = Date()
        let gameStart = state.gameStartedAt ?? state.startedAt
        let rallyStart = state.lastPointAt ?? gameStart
        let rallySeconds = Int(now.timeIntervalSince(rallyStart).rounded())

        let prevGame = state.currentGame
        storage.pushUndo(state)

        var next = BadmintonEngine.applyPoint(state, player: player)
        next.lastPointAt = now
        next.pointDurations.append(rallySeconds)

        if !config.sessionMode && next.currentGame != prevGame && !next.matchOver {
            next.gameStartedAt = now
            next.lastPointAt   = nil
            next.pointDurations = []
        }

        state = next
        storage.saveState(state)

        if state.gameOver {
            saveGameToHistory()
            showGameOverOverlay = true
        } else if state.matchOver {
            saveMatchToHistory()
            showWinnerOverlay = true
        }

        fadeHintNow()
    }

    func handleUndo() {
        if state.gameOver { return }
        guard let prev = storage.popUndo() else { return }
        state = prev
        storage.saveState(state)
        showWinnerOverlay = false
        flashUndo()
    }

    // MARK: - Session flow

    func continueSession() {
        showGameOverOverlay = false
        state = BadmintonEngine.continueSession(state)
        state.gameStartedAt = Date()
        state.lastPointAt   = nil
        state.pointDurations = []
        storage.saveState(state)
        storage.clearUndoStack()
    }

    func endSession() {
        storage.clearState()
    }

    // MARK: - Best-of flow

    func rematch() {
        var newConfig = config
        newConfig.initialServer = 1 - config.initialServer
        config = newConfig
        storage.saveConfig(config)
        state = BadmintonEngine.initState(config: config)
        storage.saveState(state)
        storage.clearUndoStack()
        showWinnerOverlay = false
    }

    func newMatch() {
        storage.clearState()
    }

    // MARK: - History

    private func saveGameToHistory() {
        guard let last = state.gamesHistory.last else { return }
        let dur = Int(Date().timeIntervalSince(state.gameStartedAt ?? state.startedAt).rounded())
        storage.appendMatch(MatchRecord(
            id: UUID().uuidString,
            date: Date(),
            sport: "badminton",
            sessionMode: true,
            bestOf: nil,
            players: makePlayers(),
            winner: state.lastGameWinner ?? 0,
            setsWon: state.lastGameWinner == 0 ? [1, 0] : [0, 1],
            gamesHistory: [.init(points: last.points)],
            durationSeconds: dur,
            pointDurations: state.pointDurations
        ))
    }

    private func saveMatchToHistory() {
        storage.appendMatch(MatchRecord(
            id: UUID().uuidString,
            date: state.startedAt,
            sport: "badminton",
            sessionMode: false,
            bestOf: state.bestOf,
            players: makePlayers(),
            winner: state.winner ?? 0,
            setsWon: state.setsWon,
            gamesHistory: state.gamesHistory.map { .init(points: $0.points) },
            durationSeconds: Int(Date().timeIntervalSince(state.startedAt).rounded()),
            pointDurations: state.pointDurations
        ))
    }

    private func makePlayers() -> [MatchRecord.MatchPlayer] {
        config.playerIds.enumerated().map { i, id in
            .init(id: id, name: config.playerNames[i])
        }
    }

    // MARK: - Timers

    private func startTimers() {
        timerSub = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        tick()
    }

    private func tick() {
        let now = Date()
        sessionTime = fmt(now.timeIntervalSince(state.startedAt))
        guard !state.gameOver && !state.matchOver else { return }
        let gs = state.gameStartedAt ?? state.startedAt
        gameTime  = fmt(now.timeIntervalSince(gs))
        let rs = state.lastPointAt ?? gs
        rallyTime = fmt(now.timeIntervalSince(rs))
    }

    private func fmt(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    // MARK: - Hint

    private func scheduleHintFade() {
        hintTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.fadeHintNow()
        }
    }

    func fadeHintNow() {
        hintTimer?.invalidate(); hintTimer = nil
        guard showHint else { return }
        withAnimation(.easeOut(duration: 0.5)) { hintFading = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showHint = false
        }
    }

    // MARK: - Undo flash

    private func flashUndo() {
        undoFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.undoFlash = false
        }
    }
}
