import SwiftUI

struct SetupView: View {
    let onStart: (MatchConfig, BadmintonState) -> Void
    let onStats: () -> Void

    @State private var players:       [Player] = []
    @State private var selectedIds:   [String?] = [nil, nil]
    @State private var playerNames:   [String]  = ["Player 1", "Player 2"]
    @State private var bestOf:        Int  = 3
    @State private var sessionMode:   Bool = false
    @State private var targetScore:   Int  = 21
    @State private var initialServer: Int  = 0
    @State private var button1Key:    String = "ArrowLeft"
    @State private var button2Key:    String = "ArrowRight"
    @State private var capturingIdx:  Int? = nil
    @State private var showAddPlayer  = false
    @State private var newPlayerName  = ""

    private let storage = AppStorage.shared

    var body: some View {
        NavigationStack {
            Form {
                playersSection
                matchSection
                keymapSection
            }
            .navigationTitle("Scoreboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stats", action: onStats)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { startMatch() }
                        .buttonStyle(.borderedProminent)
                        .disabled(playerNames[0].trimmingCharacters(in: .whitespaces).isEmpty ||
                                  playerNames[1].trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showAddPlayer) { addPlayerSheet }
        .onAppear(perform: loadSaved)
    }

    // MARK: - Players section

    private var playersSection: some View {
        Section("Players") {
            playerRow(0)
            playerRow(1)
            Button("Add to Roster…") { showAddPlayer = true }
                .foregroundStyle(.tint)
        }
    }

    @ViewBuilder
    private func playerRow(_ i: Int) -> some View {
        HStack {
            Text("Player \(i + 1)")
                .frame(width: 72, alignment: .leading)

            if players.isEmpty {
                TextField("Name", text: $playerNames[i])
            } else {
                Picker("", selection: $selectedIds[i]) {
                    Text("Custom").tag(Optional<String>(nil))
                    ForEach(players) { p in
                        Text(p.name).tag(Optional(p.id))
                    }
                }
                .onChange(of: selectedIds[i]) { _, id in
                    if let id, let p = players.first(where: { $0.id == id }) {
                        playerNames[i] = p.name
                    }
                }
                if selectedIds[i] == nil {
                    TextField("Name", text: $playerNames[i])
                }
            }
        }
    }

    // MARK: - Match section

    private var matchSection: some View {
        Section("Match") {
            Toggle("Session Mode (unlimited games)", isOn: $sessionMode)

            if !sessionMode {
                HStack {
                    Text("Best Of")
                    Spacer()
                    Picker("", selection: $bestOf) {
                        Text("1").tag(1)
                        Text("3").tag(3)
                        Text("5").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 160)
                }
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
                    Text(playerNames[0].isEmpty ? "P1" : playerNames[0]).tag(0)
                    Text(playerNames[1].isEmpty ? "P2" : playerNames[1]).tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
        }
    }

    // MARK: - Keymap section

    private var keymapSection: some View {
        Section {
            keymapRow(label: "Player 1 button", key: $button1Key, idx: 0)
            keymapRow(label: "Player 2 button", key: $button2Key, idx: 1)
            Text("Tap the row, then press the clicker button you want to assign. Long-press (≥0.8 s) either button = Undo.")
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

    // MARK: - Add player sheet

    private var addPlayerSheet: some View {
        NavigationStack {
            Form {
                TextField("Player name", text: $newPlayerName)
            }
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

    // MARK: - Actions

    private func loadSaved() {
        players = storage.loadPlayers()
        guard let c = storage.loadConfig() else { return }
        bestOf        = c.bestOf
        sessionMode   = c.sessionMode
        targetScore   = c.targetScore
        initialServer = c.initialServer
        button1Key    = c.keymap.button1
        button2Key    = c.keymap.button2
        playerNames   = c.playerNames
        for i in 0..<2 {
            selectedIds[i] = players.first(where: { $0.name == playerNames[i] })?.id
        }
    }

    private func startMatch() {
        let ids = (0..<2).map { i in selectedIds[i] ?? UUID().uuidString }
        let config = MatchConfig(
            playerIds: ids,
            playerNames: playerNames,
            bestOf: bestOf,
            sessionMode: sessionMode,
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
