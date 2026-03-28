import Foundation

struct Player: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var createdAt: Date
}
