import SwiftUI

struct StatsView: View {
    let onBack: () -> Void

    @StateObject private var vm = StatsViewModel()
    @State private var selectedTab = 0
    @State private var h2hId1: String? = nil
    @State private var h2hId2: String? = nil
    @State private var showClearConfirm = false
    @State private var exportData: Data? = nil
    @State private var showExportSheet = false

    private let storage = AppStorage.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Standings").tag(0)
                    Text("History").tag(1)
                    Text("H2H").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case 0: standingsTab
                case 1: historyTab
                case 2: h2hTab
                default: EmptyView()
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Setup", action: onBack)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Export JSON…") { exportJSON() }
                        Button("Clear History", role: .destructive) { showClearConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Clear all match history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    storage.clearHistory()
                    vm.reload()
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let data = exportData {
                    ShareSheetView(data: data, filename: "scoreboard-export.json")
                }
            }
        }
        .onAppear { vm.reload() }
    }

    // MARK: - Standings tab

    private var standingsTab: some View {
        Group {
            if vm.standings.isEmpty {
                emptyState("No matches recorded yet")
            } else {
                List(vm.standings) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.headline)
                            Text("\(s.gamesPlayed) games · \(s.setsWon)W \(s.setsLost)L sets")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(s.gamesWon)/\(s.gamesPlayed)")
                                .font(.title3.bold())
                            Text(s.winPct)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - History tab

    private var historyTab: some View {
        Group {
            if vm.history.isEmpty {
                emptyState("No matches recorded yet")
            } else {
                List {
                    ForEach(vm.history) { match in
                        matchRow(match)
                    }
                    .onDelete { offsets in
                        offsets.forEach { i in vm.deleteMatch(id: vm.history[i].id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func matchRow(_ m: MatchRecord) -> some View {
        let winner = m.players[m.winner].name
        let loser  = m.players[1 - m.winner].name
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(winner).font(.headline).foregroundStyle(Color(hex: "#1a7a1a"))
                Text("def.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(loser).font(.subheadline)
                Spacer()
                Text(shortDate(m.date))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(Array(m.gamesHistory.enumerated()), id: \.offset) { _, g in
                    Text("\(g.points[m.winner])-\(g.points[1-m.winner])")
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                Text(formatDuration(m.durationSeconds))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - H2H tab

    private var h2hTab: some View {
        let allIds = Array(Set(vm.history.flatMap { $0.players.map(\.id) }))
        let names: [String: String] = vm.history.reduce(into: [:]) { acc, m in
            m.players.forEach { acc[$0.id] = $0.name }
        }

        return VStack(spacing: 16) {
            if allIds.count < 2 {
                emptyState("Need at least 2 players with recorded matches")
            } else {
                HStack {
                    playerPicker(label: "Player 1", ids: allIds, names: names, selection: $h2hId1)
                    Text("vs").foregroundStyle(.secondary)
                    playerPicker(label: "Player 2", ids: allIds, names: names, selection: $h2hId2)
                }
                .padding()

                if let id1 = h2hId1, let id2 = h2hId2, id1 != id2 {
                    let h2h = vm.headToHead(id1: id1, id2: id2)
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(h2h.wins1)").font(.system(size: 56, weight: .bold, design: .rounded))
                            Text(h2h.name1).font(.headline)
                        }
                        Text("–").font(.title).foregroundStyle(.secondary)
                        VStack {
                            Text("\(h2h.wins2)").font(.system(size: 56, weight: .bold, design: .rounded))
                            Text(h2h.name2).font(.headline)
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            let ids = allIds
            if h2hId1 == nil, ids.count >= 1 { h2hId1 = ids[0] }
            if h2hId2 == nil, ids.count >= 2 { h2hId2 = ids[1] }
        }
    }

    @ViewBuilder
    private func playerPicker(label: String, ids: [String], names: [String: String], selection: Binding<String?>) -> some View {
        Picker(label, selection: selection) {
            Text("—").tag(Optional<String>(nil))
            ForEach(ids, id: \.self) { id in
                Text(names[id] ?? id).tag(Optional(id))
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Export

    private func exportJSON() {
        exportData = try? storage.exportData()
        showExportSheet = exportData != nil
    }

    // MARK: - Helpers

    @ViewBuilder
    private func emptyState(_ msg: String) -> some View {
        VStack {
            Spacer()
            Text(msg).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f.string(from: d)
    }

    private func formatDuration(_ s: Int) -> String {
        "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}

// MARK: - Share sheet wrapper

struct ShareSheetView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
