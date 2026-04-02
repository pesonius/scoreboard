import Foundation

struct Team: Codable, Identifiable {
    var id: String
    var name: String
    var playerIds: [String]   // exactly 2
    var createdAt: Date
}
