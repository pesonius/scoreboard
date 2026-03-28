import Foundation

struct MatchConfig: Codable {
    var playerIds: [String]
    var playerNames: [String]
    var bestOf: Int
    var sessionMode: Bool
    var targetScore: Int
    var initialServer: Int
    var keymap: KeyMap

    struct KeyMap: Codable {
        var button1: String  // key string for player 0
        var button2: String  // key string for player 1
    }

    static func makeDefault() -> MatchConfig {
        MatchConfig(
            playerIds: [UUID().uuidString, UUID().uuidString],
            playerNames: ["Player 1", "Player 2"],
            bestOf: 3,
            sessionMode: false,
            targetScore: 21,
            initialServer: 0,
            keymap: KeyMap(button1: "ArrowLeft", button2: "ArrowRight")
        )
    }
}
