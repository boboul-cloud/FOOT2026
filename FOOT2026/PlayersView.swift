// PlayersView.swift
// FOOT2026
// Players list by team with photos

import SwiftUI

// MARK: - Position view-layer extension

extension Position {
    var color: Color {
        switch self {
        case .goalkeeper: return .orange
        case .defender:   return .blue
        case .midfielder: return .green
        case .forward:    return .red
        }
    }
}

// MARK: - Root view

struct PlayersView: View {
    @State private var searchText = ""

    private var teams: [(name: String, players: [Player])] {
        Player.allSquads
            .sorted { $0.key < $1.key }
            .map { (name: $0.key, players: $0.value) }
    }

    private var filtered: [(name: String, players: [Player])] {
        guard !searchText.isEmpty else { return teams }
        let q = searchText.lowercased()
        return teams.compactMap { team in
            if team.name.lowercased().contains(q) {
                return team                   // show full squad when team name matches
            }
            let matchingPlayers = team.players.filter { $0.name.lowercased().contains(q) }
            return matchingPlayers.isEmpty ? nil : (name: team.name, players: matchingPlayers)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.name) { team in
                NavigationLink {
                    TeamSquadView(team: team.name, players: team.players)
                } label: {
                    TeamRow(name: team.name, count: team.players.count)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Joueurs")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Équipe ou joueur…")
        }
    }
}

// MARK: - Team row

private struct TeamRow: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(teamFlags[name] ?? "🏳️")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text("\(count) joueurs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Team squad view

struct TeamSquadView: View {
    let team: String
    let players: [Player]
    @Environment(PlayerStore.self) private var playerStore
    @State private var editingPlayer: Player?

    private var duplicateNumbers: Set<Int> {
        let numbers = players.map { playerStore.number(for: $0) }
        var seen = Set<Int>()
        var dupes = Set<Int>()
        for n in numbers { if !seen.insert(n).inserted { dupes.insert(n) } }
        return dupes
    }

    private var missingNumbers: [Int] {
        let used = Set(players.map { playerStore.number(for: $0) })
        return (1...26).filter { !used.contains($0) }
    }

    private var grouped: [(Position, [Player])] {
        let byPos = Dictionary(grouping: players.sorted { $0.number < $1.number }) { playerStore.position(for: $0) }
        return Position.allCases.compactMap { pos in
            guard let list = byPos[pos], !list.isEmpty else { return nil }
            return (pos, list)
        }
    }

    var body: some View {
        List {
            if !missingNumbers.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Numéros manquants", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        FlowRow(numbers: missingNumbers)
                    }
                    .padding(.vertical, 4)
                }
            }
            ForEach(grouped, id: \.0) { position, list in
                Section(position.localizedName.uppercased()) {
                    ForEach(list) { player in
                        PlayerRow(player: player, isDuplicateNumber: duplicateNumbers.contains(playerStore.number(for: player)))
                            .contentShape(Rectangle())
                            .onTapGesture { editingPlayer = player }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(teamFlags[team] ?? "") \(team)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingPlayer) { player in
            PlayerEditSheet(player: player)
        }
    }
}

// MARK: - Player row

private struct PlayerRow: View {
    let player: Player
    var isDuplicateNumber: Bool = false
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.openURL) private var openURL

    private var googleSearchURL: URL? {
        let query = "\(playerStore.name(for: player)) footballeur"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.google.com/search?q=\(encoded)")
    }

    var body: some View {
        HStack(spacing: 14) {
            PlayerAvatarView(player: player, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(playerStore.name(for: player))
                    .font(.system(.body, weight: .medium))
                PositionBadge(position: playerStore.position(for: player))
            }
            Spacer()
            Text("#\(playerStore.number(for: player))")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(isDuplicateNumber ? Color.red : playerStore.position(for: player).color)
                .padding(.horizontal, isDuplicateNumber ? 6 : 0)
                .padding(.vertical, isDuplicateNumber ? 2 : 0)
                .background(isDuplicateNumber ? Color.red.opacity(0.12) : Color.clear, in: Capsule())
                .overlay(isDuplicateNumber ? Capsule().stroke(Color.red.opacity(0.5), lineWidth: 1) : nil)
            Button {
                if let url = googleSearchURL { openURL(url) }
            } label: {
                Image(systemName: "safari")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Player avatar

struct PlayerAvatarView: View {
    let player: Player
    let size: CGFloat
    @Environment(PlayerStore.self) private var playerStore

    var body: some View {
        ZStack {
            if let img = playerStore.photo(for: player) {
                // Manual photo always wins.
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                // Otherwise auto-load from Wikipedia, falling back to initials.
                RemotePlayerPhoto(player: player, size: size) {
                    ZStack {
                        Circle()
                            .fill(playerStore.position(for: player).color.gradient)
                        Text(initials)
                            .font(.system(size: size * 0.35, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        playerStore.name(for: player)
            .split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }
}

// MARK: - Player edit sheet

private struct PlayerEditSheet: View {
    let player: Player
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss
    @State private var nameText = ""
    @State private var numberText = ""
    @State private var selectedPosition: Position = .midfielder
    @State private var pasteMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Portrait") {
                    HStack {
                        Spacer()
                        PlayerAvatarView(player: player, size: 100)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                    Button {
                        pasteImage()
                    } label: {
                        Label("Coller depuis le presse-papiers", systemImage: "doc.on.clipboard")
                    }
                    if let msg = pasteMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(msg.hasPrefix("✓") ? Color.green : Color.orange)
                    }
                    if playerStore.photo(for: player) != nil {
                        Button("Effacer la photo", role: .destructive) {
                            playerStore.setPhoto(nil, for: player)
                            pasteMessage = nil
                        }
                    }
                }

                Section("Nom") {
                    TextField("Nom du joueur", text: $nameText)
                        .autocorrectionDisabled()
                }

                Section("Numéro") {
                    TextField("Numéro", text: $numberText)
                        .keyboardType(.numberPad)
                }

                Section("Poste") {
                    Picker("Poste", selection: $selectedPosition) {
                        ForEach(Position.allCases, id: \.self) { pos in
                            Text(pos.localizedName).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(playerStore.name(for: player))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear {
                nameText = playerStore.name(for: player)
                numberText = "\(playerStore.number(for: player))"
                selectedPosition = playerStore.position(for: player)
            }
        }
    }

    private func pasteImage() {
        if let img = UIPasteboard.general.image {
            playerStore.setPhoto(img, for: player)
            pasteMessage = "✓ Image collée"
        } else {
            pasteMessage = "Aucune image dans le presse-papiers"
        }
    }

    private func save() {
        playerStore.setName(nameText, for: player)
        if let n = Int(numberText), (1...99).contains(n) {
            playerStore.setNumber(n, for: player)
        }
        playerStore.setPosition(selectedPosition, for: player)
        dismiss()
    }
}

// MARK: - Missing numbers flow row

private struct FlowRow: View {
    let numbers: [Int]

    var body: some View {
        // Simple wrapping layout using LazyVGrid with adaptive columns
        let columns = [GridItem(.adaptive(minimum: 36), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(numbers, id: \.self) { n in
                Text("#\(n)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }
        }
    }
}

// MARK: - Position badge

private struct PositionBadge: View {
    let position: Position

    var body: some View {
        Text(position.localizedName)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(position.color.opacity(0.15), in: Capsule())
            .foregroundStyle(position.color)
    }
}

// MARK: - Preview

#Preview {
    PlayersView()
        .environment(PlayerStore())
}
