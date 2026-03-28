import Foundation

struct MatchRecord: Codable, Identifiable {
    var id: String
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
}
