import Foundation
import Combine

struct Standings: Identifiable {
    var id: String
    var name: String
    var gamesPlayed: Int
    var gamesWon: Int
    var setsWon: Int
    var setsLost: Int
    var pointsWon: Int
    var pointsLost: Int

    var winRate: Double { gamesPlayed > 0 ? Double(gamesWon) / Double(gamesPlayed) : 0 }
    var winPct: String  { "\(Int(winRate * 100))%" }
}

struct HeadToHead {
    var name1: String
    var name2: String
    var wins1: Int
    var wins2: Int
}

final class StatsViewModel: ObservableObject {
    @Published var standings: [Standings] = []
    @Published var history:   [MatchRecord] = []

    private let storage = AppStorage.shared

    func reload() {
        history  = storage.loadHistory().sorted { $0.date > $1.date }
        standings = computeStandings()
    }

    func headToHead(id1: String, id2: String) -> HeadToHead {
        var w1 = 0, w2 = 0, n1 = "", n2 = ""
        for m in history {
            let ids = m.players.map(\.id)
            guard let i1 = ids.firstIndex(of: id1),
                  let i2 = ids.firstIndex(of: id2) else { continue }
            n1 = m.players[i1].name
            n2 = m.players[i2].name
            if m.winner == i1 { w1 += 1 }
            if m.winner == i2 { w2 += 1 }
        }
        return HeadToHead(name1: n1, name2: n2, wins1: w1, wins2: w2)
    }

    func deleteMatch(id: String) {
        var h = storage.loadHistory()
        h.removeAll { $0.id == id }
        storage.clearHistory()
        h.forEach { storage.appendMatch($0) }
        reload()
    }

    // MARK: - Private

    private func computeStandings() -> [Standings] {
        var map: [String: Standings] = [:]
        for match in history {
            for (i, player) in match.players.enumerated() {
                if map[player.id] == nil {
                    map[player.id] = Standings(
                        id: player.id, name: player.name,
                        gamesPlayed: 0, gamesWon: 0,
                        setsWon: 0, setsLost: 0,
                        pointsWon: 0, pointsLost: 0
                    )
                }
                let opp = 1 - i
                map[player.id]!.gamesPlayed += 1
                if match.winner == i { map[player.id]!.gamesWon += 1 }
                map[player.id]!.setsWon   += match.setsWon[i]
                map[player.id]!.setsLost  += match.setsWon[opp]
                for game in match.gamesHistory {
                    map[player.id]!.pointsWon  += game.points[i]
                    map[player.id]!.pointsLost += game.points[opp]
                }
            }
        }
        return map.values.sorted { $0.winRate > $1.winRate }
    }
}
