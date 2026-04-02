import Foundation

struct MatchRecord: Codable, Identifiable {
    var id: String
    var sessionId: String      // groups games played in one sitting; "" for old records
    var date: Date
    var sport: String
    var sessionMode: Bool
    var bestOf: Int?
    var players: [MatchPlayer]
    var winner: Int
    var setsWon: [Int]
    var gamesHistory: [GameHistory]
    var durationSeconds: Int
    var pointDurations: [Int]

    struct MatchPlayer: Codable {
        var id: String
        var name: String
    }

    struct GameHistory: Codable {
        var points: [Int]
    }

    // Backward-compatible decoder: old records without sessionId get ""
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try  c.decode(String.self,        forKey: .id)
        sessionId       = (try? c.decode(String.self,       forKey: .sessionId)) ?? ""
        date            = try  c.decode(Date.self,          forKey: .date)
        sport           = try  c.decode(String.self,        forKey: .sport)
        sessionMode     = try  c.decode(Bool.self,          forKey: .sessionMode)
        bestOf          = try? c.decode(Int.self,           forKey: .bestOf)
        players         = try  c.decode([MatchPlayer].self, forKey: .players)
        winner          = try  c.decode(Int.self,           forKey: .winner)
        setsWon         = try  c.decode([Int].self,         forKey: .setsWon)
        gamesHistory    = try  c.decode([GameHistory].self, forKey: .gamesHistory)
        durationSeconds = try  c.decode(Int.self,           forKey: .durationSeconds)
        pointDurations  = (try? c.decode([Int].self,        forKey: .pointDurations)) ?? []
    }

    init(id: String, sessionId: String, date: Date, sport: String, sessionMode: Bool,
         bestOf: Int?, players: [MatchPlayer], winner: Int, setsWon: [Int],
         gamesHistory: [GameHistory], durationSeconds: Int, pointDurations: [Int]) {
        self.id              = id
        self.sessionId       = sessionId
        self.date            = date
        self.sport           = sport
        self.sessionMode     = sessionMode
        self.bestOf          = bestOf
        self.players         = players
        self.winner          = winner
        self.setsWon         = setsWon
        self.gamesHistory    = gamesHistory
        self.durationSeconds = durationSeconds
        self.pointDurations  = pointDurations
    }
}
