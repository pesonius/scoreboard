import Foundation

enum MatchType: String, Codable {
    case singles, doubles
}

struct MatchConfig: Codable {
    var matchType: MatchType
    var playerIds: [String]
    var playerNames: [String]    // 2 entries — one name per side
    var partnerNames: [String]   // 2 entries — empty string for singles
    var targetScore: Int
    var initialServer: Int
    var keymap: KeyMap

    struct KeyMap: Codable {
        var button1: String
        var button2: String
    }

    // Custom decoder for backward compatibility with old configs
    // that had bestOf/sessionMode instead of matchType/partnerNames.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchType    = (try? c.decode(MatchType.self,  forKey: .matchType))    ?? .singles
        playerIds    = try c.decode([String].self,     forKey: .playerIds)
        playerNames  = try c.decode([String].self,     forKey: .playerNames)
        partnerNames = (try? c.decode([String].self,   forKey: .partnerNames)) ?? ["", ""]
        targetScore  = try c.decode(Int.self,          forKey: .targetScore)
        initialServer = try c.decode(Int.self,         forKey: .initialServer)
        keymap       = try c.decode(KeyMap.self,       forKey: .keymap)
    }

    init(matchType: MatchType, playerIds: [String], playerNames: [String],
         partnerNames: [String], targetScore: Int, initialServer: Int, keymap: KeyMap) {
        self.matchType    = matchType
        self.playerIds    = playerIds
        self.playerNames  = playerNames
        self.partnerNames = partnerNames
        self.targetScore  = targetScore
        self.initialServer = initialServer
        self.keymap       = keymap
    }

    static func makeDefault() -> MatchConfig {
        MatchConfig(
            matchType: .singles,
            playerIds: [UUID().uuidString, UUID().uuidString],
            playerNames: ["Player 1", "Player 2"],
            partnerNames: ["", ""],
            targetScore: 21,
            initialServer: 0,
            keymap: KeyMap(button1: "ArrowLeft", button2: "ArrowRight")
        )
    }
}
