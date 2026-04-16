import Foundation
import Combine
import SwiftUI

final class ScoreboardViewModel: ObservableObject {

    @Published var state:  BadmintonState
    @Published var config: MatchConfig

    // Overlay flags
    @Published var showGameOverOverlay = false

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
    private let sessionId = UUID().uuidString
    private var timerSub: AnyCancellable?
    private var hintTimer: Timer?
    private let storage = AppStorage.shared

    init(config: MatchConfig, state: BadmintonState) {
        self.config = config
        self.state  = state
        self.inputManager = InputManager(keymap: config.keymap)
        inputManager.onPoint = { [weak self] p in self?.handleClickerPoint(p) }
        inputManager.onUndo  = { [weak self] in self?.handleUndo() }
        // Top button = mouse click → P1 via tap gesture
        // Bottom button = volume UP → P2
        volumeManager.onVolumeUp   = { [weak self] in self?.handleVolumePoint(1) }
        volumeManager.onVolumeDown = { [weak self] in self?.handleVolumePoint(1) }
        volumeManager.onDebug = { [weak self] msg in self?.logDebug("VOL: \(msg)") }
        inputManager.onDebug  = { [weak self] msg in self?.logDebug("KEY: \(msg)") }
        startTimers()
        scheduleHintFade()
    }

    // MARK: - Display

    var displayScore: DisplayScore { BadmintonEngine.getDisplayScore(state) }

    var gameLabel: String { "Game \(state.currentGame)" }

    // MARK: - Scoring

    private var lastVolumeAt:  Date = .distantPast
    private var lastClickerAt: Date = .distantPast
    private let volumeCooldown:  TimeInterval = 0.4
    private let clickerCooldown: TimeInterval = 0.3

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

    // Called by InputManager (keyboard / mouse UIPress) — bypasses tap cooldown
    func handleClickerPoint(_ player: Int) {
        lastClickerAt = Date()
        logDebug("CLICK → score P\(player + 1)")
        scorePoint(player)
    }

    // Called by tap gestures — blocked if clicker or volume fired recently
    func handlePoint(_ player: Int) {
        let sinceVolume  = Date().timeIntervalSince(lastVolumeAt)
        let sinceClicker = Date().timeIntervalSince(lastClickerAt)
        if sinceVolume < volumeCooldown {
            logDebug("TAP P\(player + 1) [blocked, vol \(Int(sinceVolume * 1000))ms ago]")
            return
        }
        if sinceClicker < clickerCooldown {
            logDebug("TAP P\(player + 1) [blocked, clicker \(Int(sinceClicker * 1000))ms ago]")
            return
        }
        logDebug("TAP → score P\(player + 1)")
        scorePoint(player)
    }

    private func scorePoint(_ player: Int) {
        if state.gameOver { continueSession(); return }

        let now        = Date()
        let gameStart  = state.gameStartedAt ?? state.startedAt
        let rallyStart = state.lastPointAt ?? gameStart
        let rallySeconds = Int(now.timeIntervalSince(rallyStart).rounded())

        storage.pushUndo(state)

        var next = BadmintonEngine.applyPoint(state, player: player)
        next.lastPointAt = now
        next.pointDurations.append(rallySeconds)

        state = next
        storage.saveState(state)

        if state.gameOver {
            saveGameToHistory()
            showGameOverOverlay = true
        }

        fadeHintNow()
    }

    func handleUndo() {
        if state.gameOver { return }
        guard let prev = storage.popUndo() else { return }
        state = prev
        storage.saveState(state)
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

    // MARK: - History

    private func saveGameToHistory() {
        guard let last = state.gamesHistory.last else { return }
        let dur = Int(Date().timeIntervalSince(state.gameStartedAt ?? state.startedAt).rounded())
        storage.appendMatch(MatchRecord(
            id: UUID().uuidString,
            sessionId: sessionId,
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

    private func makePlayers() -> [MatchRecord.MatchPlayer] {
        config.playerIds.enumerated().map { i, id in
            let name = config.partnerNames[i].isEmpty
                ? config.playerNames[i]
                : "\(config.playerNames[i]) / \(config.partnerNames[i])"
            return .init(id: id, name: name)
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
        guard !state.gameOver else { return }
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
