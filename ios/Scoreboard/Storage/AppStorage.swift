import Foundation

final class AppStorage {
    static let shared = AppStorage()

    private let defaults = UserDefaults.standard
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // UserDefaults keys
    private let configKey  = "scoreboard.config"
    private let stateKey   = "scoreboard.state"
    private let undoKey    = "scoreboard.undoStack"
    private let playersKey = "scoreboard.players"
    private let teamsKey   = "scoreboard.teams"
    private let historyKey = "scoreboard.history"
    private let maxUndo    = 50

    // MARK: - Config

    func loadConfig() -> MatchConfig? {
        guard let data = defaults.data(forKey: configKey) else { return nil }
        return try? decoder.decode(MatchConfig.self, from: data)
    }

    func saveConfig(_ config: MatchConfig) {
        defaults.set(try? encoder.encode(config), forKey: configKey)
    }

    // MARK: - State

    func loadState() -> BadmintonState? {
        guard let data = defaults.data(forKey: stateKey) else { return nil }
        return try? decoder.decode(BadmintonState.self, from: data)
    }

    func saveState(_ state: BadmintonState) {
        defaults.set(try? encoder.encode(state), forKey: stateKey)
    }

    func clearState() {
        defaults.removeObject(forKey: stateKey)
        defaults.removeObject(forKey: undoKey)
    }

    // MARK: - Undo stack

    func pushUndo(_ state: BadmintonState) {
        var stack = loadUndoStack()
        stack.append(state)
        if stack.count > maxUndo { stack.removeFirst() }
        defaults.set(try? encoder.encode(stack), forKey: undoKey)
    }

    func popUndo() -> BadmintonState? {
        var stack = loadUndoStack()
        guard !stack.isEmpty else { return nil }
        let top = stack.removeLast()
        defaults.set(try? encoder.encode(stack), forKey: undoKey)
        return top
    }

    func clearUndoStack() {
        defaults.removeObject(forKey: undoKey)
    }

    private func loadUndoStack() -> [BadmintonState] {
        guard let data = defaults.data(forKey: undoKey) else { return [] }
        return (try? decoder.decode([BadmintonState].self, from: data)) ?? []
    }

    // MARK: - Players

    func loadPlayers() -> [Player] {
        guard let data = defaults.data(forKey: playersKey) else { return [] }
        return (try? decoder.decode([Player].self, from: data)) ?? []
    }

    func savePlayers(_ players: [Player]) {
        defaults.set(try? encoder.encode(players), forKey: playersKey)
    }

    @discardableResult
    func addPlayer(name: String) -> Player {
        var players = loadPlayers()
        let player = Player(id: UUID().uuidString, name: name, createdAt: Date())
        players.append(player)
        savePlayers(players)
        return player
    }

    func deletePlayer(id: String) {
        var players = loadPlayers()
        players.removeAll { $0.id == id }
        savePlayers(players)
    }

    // MARK: - Teams

    func loadTeams() -> [Team] {
        guard let data = defaults.data(forKey: teamsKey) else { return [] }
        return (try? decoder.decode([Team].self, from: data)) ?? []
    }

    func saveTeams(_ teams: [Team]) {
        defaults.set(try? encoder.encode(teams), forKey: teamsKey)
    }

    @discardableResult
    func addTeam(name: String, playerIds: [String]) -> Team {
        var teams = loadTeams()
        let team = Team(id: UUID().uuidString, name: name, playerIds: playerIds, createdAt: Date())
        teams.append(team)
        saveTeams(teams)
        return team
    }

    func deleteTeam(id: String) {
        var teams = loadTeams()
        teams.removeAll { $0.id == id }
        saveTeams(teams)
    }

    // MARK: - Match history

    func loadHistory() -> [MatchRecord] {
        guard let data = defaults.data(forKey: historyKey) else { return [] }
        return (try? decoder.decode([MatchRecord].self, from: data)) ?? []
    }

    func appendMatch(_ record: MatchRecord) {
        var history = loadHistory()
        history.append(record)
        defaults.set(try? encoder.encode(history), forKey: historyKey)
    }

    func clearHistory() {
        defaults.removeObject(forKey: historyKey)
    }

    // MARK: - Export / Import

    func exportData() throws -> Data {
        let pkg = ExportPackage(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            version: 1,
            players: loadPlayers(),
            history: loadHistory()
        )
        return try encoder.encode(pkg)
    }

    func importData(_ data: Data) throws {
        let pkg = try decoder.decode(ExportPackage.self, from: data)

        var players = loadPlayers()
        let knownIds = Set(players.map(\.id))
        for p in pkg.players where !knownIds.contains(p.id) { players.append(p) }
        savePlayers(players)

        var history = loadHistory()
        let knownMatchIds = Set(history.map(\.id))
        for m in pkg.history where !knownMatchIds.contains(m.id) { history.append(m) }
        defaults.set(try? encoder.encode(history), forKey: historyKey)
    }

    struct ExportPackage: Codable {
        var exportedAt: String
        var version: Int
        var players: [Player]
        var history: [MatchRecord]
    }
}
