import SwiftUI

struct SetupView: View {
    let onStart: (MatchConfig, BadmintonState) -> Void
    let onStats: () -> Void

    // Roster
    @State private var players: [Player] = []
    @State private var teams:   [Team]   = []

    // Singles selection
    @State private var selectedPlayerIds: [String?] = [nil, nil]
    @State private var playerNames:       [String]  = ["Player 1", "Player 2"]

    // Doubles selection
    @State private var selectedTeamIds: [String?] = [nil, nil]
    @State private var teamNames:       [String]  = ["Team 1", "Team 2"]   // custom team names

    // Match settings
    @State private var matchType:     MatchType = .singles
    @State private var targetScore:   Int  = 21
    @State private var initialServer: Int  = 0
    @State private var button1Key:    String = "ArrowLeft"
    @State private var button2Key:    String = "ArrowRight"

    @State private var developerMode = UserDefaults.standard.bool(forKey: "scoreboard.developerMode")

    // Sheets
    @State private var capturingIdx:  Int? = nil
    @State private var showAddPlayer  = false
    @State private var newPlayerName  = ""
    @State private var showAddTeam    = false
    @State private var newTeamName    = ""
    @State private var newTeamPlayerIds: [String?] = [nil, nil]
    @State private var showManageTeams = false

    private let storage = AppStorage.shared

    var body: some View {
        NavigationStack {
            Form {
                matchSection
                playersSection
                if developerMode { keymapSection }
                developerSection
            }
            .navigationTitle("Scoreboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stats", action: onStats)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { startMatch() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canStart)
                }
            }
        }
        .sheet(isPresented: $showAddPlayer) { addPlayerSheet }
        .sheet(isPresented: $showAddTeam)   { addTeamSheet }
        .sheet(isPresented: $showManageTeams) { manageTeamsSheet }
        .onAppear(perform: loadSaved)
    }

    private var canStart: Bool {
        if matchType == .singles {
            return !playerNames[0].trimmingCharacters(in: .whitespaces).isEmpty &&
                   !playerNames[1].trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return !resolvedTeamName(0).trimmingCharacters(in: .whitespaces).isEmpty &&
                   !resolvedTeamName(1).trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Match section

    private var matchSection: some View {
        Section("Match") {
            HStack {
                Text("Type")
                Spacer()
                Picker("", selection: $matchType) {
                    Text("Singles").tag(MatchType.singles)
                    Text("Doubles").tag(MatchType.doubles)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            HStack {
                Text("Target Score")
                Spacer()
                Picker("", selection: $targetScore) {
                    Text("11").tag(11)
                    Text("21").tag(21)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 120)
            }

            HStack {
                Text("First Server")
                Spacer()
                Picker("", selection: $initialServer) {
                    Text(sideName(0)).tag(0)
                    Text(sideName(1)).tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
        }
    }

    // MARK: - Players / Teams section

    @ViewBuilder
    private var playersSection: some View {
        if matchType == .singles {
            Section("Players") {
                playerRow(0)
                playerRow(1)
                Button("Add to Roster…") { showAddPlayer = true }
                    .foregroundStyle(.tint)
            }
        } else {
            Section("Teams") {
                teamRow(0)
                teamRow(1)
                HStack(spacing: 16) {
                    Button("Add Team…") {
                        newTeamName = ""; newTeamPlayerIds = [nil, nil]
                        showAddTeam = true
                    }
                    .foregroundStyle(.tint)
                    if !teams.isEmpty {
                        Button("Manage Teams…") { showManageTeams = true }
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    // Singles player row
    @ViewBuilder
    private func playerRow(_ i: Int) -> some View {
        HStack {
            Text("Player \(i + 1)").frame(width: 72, alignment: .leading)
            if players.isEmpty {
                TextField("Name", text: $playerNames[i])
            } else {
                Picker("", selection: $selectedPlayerIds[i]) {
                    Text("Custom").tag(Optional<String>(nil))
                    ForEach(players) { p in
                        Text(p.name).tag(Optional(p.id))
                    }
                }
                .onChange(of: selectedPlayerIds[i]) { _, id in
                    if let id, let p = players.first(where: { $0.id == id }) {
                        playerNames[i] = p.name
                    }
                }
                if selectedPlayerIds[i] == nil {
                    TextField("Name", text: $playerNames[i])
                }
            }
        }
    }

    // Doubles team row
    @ViewBuilder
    private func teamRow(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Side \(i + 1)").frame(width: 60, alignment: .leading)
                if teams.isEmpty {
                    TextField("Team name", text: $teamNames[i])
                } else {
                    Picker("", selection: $selectedTeamIds[i]) {
                        Text("Custom").tag(Optional<String>(nil))
                        ForEach(teams) { t in
                            Text(t.name).tag(Optional(t.id))
                        }
                    }
                    if selectedTeamIds[i] == nil {
                        TextField("Team name", text: $teamNames[i])
                    }
                }
            }
            // Show team players as subtitle when a saved team is selected
            if let id = selectedTeamIds[i],
               let team = teams.first(where: { $0.id == id }) {
                Text(teamPlayerNames(team))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 68)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Keymap section

    private var keymapSection: some View {
        Section {
            keymapRow(label: "Button 1", key: $button1Key, idx: 0)
            keymapRow(label: "Button 2", key: $button2Key, idx: 1)
            Text("Tap the row, then press the clicker button you want to assign. Long-press (≥0.8 s) = Undo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("BLE Clicker Mapping")
        }
    }

    @ViewBuilder
    private func keymapRow(label: String, key: Binding<String>, idx: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            if capturingIdx == idx {
                Text("Press button…")
                    .foregroundStyle(.blue)
                    .overlay(
                        KeyCaptureView { captured in
                            key.wrappedValue = captured
                            capturingIdx = nil
                        }
                        .frame(width: 1, height: 1).opacity(0.01)
                    )
            } else {
                Button(friendlyKey(key.wrappedValue)) { capturingIdx = idx }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Developer section

    private var developerSection: some View {
        Section {
            Toggle("Developer Mode", isOn: $developerMode)
                .onChange(of: developerMode) { _, v in
                    UserDefaults.standard.set(v, forKey: "scoreboard.developerMode")
                }
        } footer: {
            Text("Shows BLE clicker mapping and debug console.")
        }
    }

    // MARK: - Add player sheet

    private var addPlayerSheet: some View {
        NavigationStack {
            Form { TextField("Player name", text: $newPlayerName) }
            .navigationTitle("New Player")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddPlayer = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        storage.addPlayer(name: newPlayerName)
                        players = storage.loadPlayers()
                        newPlayerName = ""
                        showAddPlayer = false
                    }
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Add team sheet

    private var addTeamSheet: some View {
        NavigationStack {
            Form {
                Section("Team name") {
                    TextField("e.g. Mikael / Jari", text: $newTeamName)
                }
                Section("Players") {
                    playerPickerRow(label: "Player 1", selection: $newTeamPlayerIds[0])
                    playerPickerRow(label: "Player 2", selection: $newTeamPlayerIds[1])
                    Button("Add player to roster…") { showAddPlayer = true }
                        .foregroundStyle(.tint)
                }
            }
            .navigationTitle("New Team")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTeam = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let ids = newTeamPlayerIds.compactMap { $0 }
                        storage.addTeam(name: newTeamName, playerIds: ids)
                        teams = storage.loadTeams()
                        showAddTeam = false
                    }
                    .disabled(!canSaveTeam)
                }
            }
        }
    }

    @ViewBuilder
    private func playerPickerRow(label: String, selection: Binding<String?>) -> some View {
        HStack {
            Text(label).frame(width: 72, alignment: .leading)
            Picker("", selection: selection) {
                Text("—").tag(Optional<String>(nil))
                ForEach(players) { p in
                    Text(p.name).tag(Optional(p.id))
                }
            }
        }
    }

    private var canSaveTeam: Bool {
        !newTeamName.trimmingCharacters(in: .whitespaces).isEmpty &&
        newTeamPlayerIds[0] != nil && newTeamPlayerIds[1] != nil &&
        newTeamPlayerIds[0] != newTeamPlayerIds[1]
    }

    // MARK: - Manage teams sheet

    private var manageTeamsSheet: some View {
        NavigationStack {
            List {
                ForEach(teams) { team in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name).font(.body)
                        Text(teamPlayerNames(team))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    offsets.forEach { storage.deleteTeam(id: teams[$0].id) }
                    teams = storage.loadTeams()
                    // Clear selection if deleted team was selected
                    for i in 0..<2 {
                        if let id = selectedTeamIds[i],
                           !teams.contains(where: { $0.id == id }) {
                            selectedTeamIds[i] = nil
                        }
                    }
                }
            }
            .navigationTitle("Teams")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showManageTeams = false }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
    }

    // MARK: - Helpers

    private func sideName(_ i: Int) -> String {
        if matchType == .doubles {
            return resolvedTeamName(i).isEmpty ? "Side \(i+1)" : resolvedTeamName(i)
        }
        return playerNames[i].isEmpty ? "Player \(i+1)" : playerNames[i]
    }

    private func resolvedTeamName(_ i: Int) -> String {
        if let id = selectedTeamIds[i], let team = teams.first(where: { $0.id == id }) {
            return team.name
        }
        return teamNames[i]
    }

    private func teamPlayerNames(_ team: Team) -> String {
        team.playerIds
            .compactMap { id in players.first(where: { $0.id == id })?.name }
            .joined(separator: " / ")
    }

    // MARK: - Actions

    private func loadSaved() {
        players = storage.loadPlayers()
        teams   = storage.loadTeams()
        guard let c = storage.loadConfig() else { return }
        matchType     = c.matchType
        targetScore   = c.targetScore
        initialServer = c.initialServer
        button1Key    = c.keymap.button1
        button2Key    = c.keymap.button2

        if matchType == .singles {
            playerNames = c.playerNames
            for i in 0..<2 {
                selectedPlayerIds[i] = players.first(where: { $0.name == playerNames[i] })?.id
            }
        } else {
            for i in 0..<2 {
                if let team = teams.first(where: { $0.id == c.playerIds[i] }) {
                    selectedTeamIds[i] = team.id
                } else {
                    teamNames[i]      = c.playerNames[i]
                }
            }
        }
    }

    private func startMatch() {
        var ids          = [String]()
        var matchNames   = [String]()
        var matchPartners = [String]()

        for i in 0..<2 {
            if matchType == .singles {
                let id = selectedPlayerIds[i] ?? UUID().uuidString
                ids.append(id)
                matchNames.append(playerNames[i])
                matchPartners.append("")
            } else {
                if let teamId = selectedTeamIds[i],
                   let team = teams.first(where: { $0.id == teamId }) {
                    let individualNames = team.playerIds
                        .compactMap { id in players.first(where: { $0.id == id })?.name }
                    ids.append(team.id)
                    matchNames.append(individualNames.first ?? team.name)
                    matchPartners.append(individualNames.count > 1 ? individualNames[1] : "")
                } else {
                    ids.append(UUID().uuidString)
                    matchNames.append(teamNames[i])
                    matchPartners.append("")
                }
            }
        }

        let config = MatchConfig(
            matchType: matchType,
            playerIds: ids,
            playerNames: matchNames,
            partnerNames: matchPartners,
            targetScore: targetScore,
            initialServer: initialServer,
            keymap: .init(button1: button1Key, button2: button2Key)
        )
        storage.saveConfig(config)
        storage.clearState()
        let state = BadmintonEngine.initState(config: config)
        storage.saveState(state)
        onStart(config, state)
    }

    private func friendlyKey(_ key: String) -> String {
        switch key {
        case "ArrowLeft":  return "← Left"
        case "ArrowRight": return "→ Right"
        case "ArrowUp":    return "↑ Up"
        case "ArrowDown":  return "↓ Down"
        case "Space":      return "Space"
        case "Enter":      return "Enter"
        default:           return key
        }
    }
}
