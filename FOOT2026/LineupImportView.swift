// LineupImportView.swift
// FOOT2026
// Import team lineup from Sofascore API (event ID extracted from URL)

import SwiftUI

// MARK: - Sofascore API

private struct SofascoreLineups: Decodable {
    let home: SofascoreTeam
    let away: SofascoreTeam

    struct SofascoreTeam: Decodable {
        let players: [SofascorePlayer]
        let supportStaff: [SofascoreStaff]?
    }

    struct SofascorePlayer: Decodable {
        let player: PlayerInfo
        let jerseyNumber: String?
        let substitute: Bool
        let position: String?

        struct PlayerInfo: Decodable {
            let name: String
            let shortName: String?
        }
    }

    struct SofascoreStaff: Decodable {
        let staff: StaffInfo
        let role: String?

        struct StaffInfo: Decodable {
            let name: String
            let shortName: String?
        }
    }
}

@MainActor
@Observable
final class LineupFetcher {
    enum State {
        case idle, loading, success(LineupData), error(String)
    }
    var state: State = .idle

    /// Accept:
    /// - Full Sofascore URL with #id:XXXXXXXX
    /// - Any URL containing a long numeric segment (≥6 digits)
    /// - A bare numeric event ID
    static func eventID(from urlString: String) -> String? {
        let s = urlString.trimmingCharacters(in: .whitespaces)
        // Bare number
        if s.allSatisfy(\.isNumber), s.count >= 5 { return s }
        // #id: fragment
        if let range = s.range(of: #"[#&?/]id[:/=](\d{5,})"#, options: .regularExpression) {
            let match = String(s[range])
            if let numRange = match.range(of: #"\d{5,}"#, options: .regularExpression) {
                return String(match[numRange])
            }
        }
        // Any path/query segment that is a long number (≥6 digits)
        let tokens = s
            .components(separatedBy: CharacterSet(charactersIn: "/#?&="))
            .filter { $0.allSatisfy(\.isNumber) && $0.count >= 6 }
        return tokens.last
    }

    func fetch(eventID: String) async {
        state = .loading
        let urlString = "https://api.sofascore.com/api/v1/event/\(eventID)/lineups"
        guard let url = URL(string: urlString) else {
            state = .error("URL invalide")
            return
        }
        var request = URLRequest(url: url)
        // Sofascore requires a basic browser user-agent
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://www.sofascore.com", forHTTPHeaderField: "Referer")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                state = .error("Erreur HTTP \(http.statusCode)")
                return
            }
            let decoded = try JSONDecoder().decode(SofascoreLineups.self, from: data)
            state = .success(buildLineup(from: decoded))
        } catch {
            state = .error("Impossible de charger : \(error.localizedDescription)")
        }
    }

    private func buildLineup(from raw: SofascoreLineups) -> LineupData {
        func players(_ list: [SofascoreLineups.SofascorePlayer], substitute: Bool) -> [LineupPlayer] {
            list.filter { $0.substitute == substitute }.map {
                LineupPlayer(
                    name: $0.player.shortName ?? $0.player.name,
                    number: Int($0.jerseyNumber ?? ""),
                    position: $0.position
                )
            }
        }
        func coach(_ team: SofascoreLineups.SofascoreTeam) -> String {
            team.supportStaff?
                .first { $0.role?.lowercased().contains("coach") == true || $0.role?.lowercased().contains("manager") == true }
                .map { $0.staff.shortName ?? $0.staff.name } ?? ""
        }

        return LineupData(
            homeStarting: players(raw.home.players, substitute: false),
            homeBench:    players(raw.home.players, substitute: true),
            homeCoach:    coach(raw.home),
            awayStarting: players(raw.away.players, substitute: false),
            awayBench:    players(raw.away.players, substitute: true),
            awayCoach:    coach(raw.away)
        )
    }
}

// MARK: - Import entry sheet

struct LineupImportSheet: View {
    let match: Match
    let onImport: (LineupData) -> Void

    @State private var fetcher = LineupFetcher()
    @State private var eventIDText: String = ""
    @State private var reviewData: LineupData? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(MatchStore.self) private var store

    private var detectedID: String? {
        LineupFetcher.eventID(from: eventIDText.trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Colle le lien Sofascore du match", systemImage: "link")
                            .font(.subheadline.bold())
                        TextField("URL Sofascore ou ID numérique", text: $eventIDText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let eid = detectedID {
                            Label("ID détecté : \(eid)", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else if !eventIDText.isEmpty {
                            Label("Lien non reconnu", systemImage: "xmark.circle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Ouvre le match sur sofascore.com dans Safari → Partage → Copie le lien. Ou tape directement l'ID numérique (ex: 13013580).")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Lien Sofascore")
                } footer: {
                    Text("Colle une URL Sofascore, ou entre directement l'ID du match (ex : 13013580) visible dans l'URL de la page.")
                        .font(.caption2)
                }

                Section {
                    switch fetcher.state {
                    case .idle:
                        Button {
                            guard let eid = detectedID else { return }
                            Task { await fetcher.fetch(eventID: eid) }
                        } label: {
                            Label("Importer la composition", systemImage: "person.3.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(detectedID == nil)

                    case .loading:
                        HStack {
                            ProgressView()
                            Text("Chargement depuis Sofascore…")
                                .foregroundStyle(.secondary)
                        }

                    case .success(let data):
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Composition chargée !", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline.bold())
                            Text("\(match.homeFlag) \(match.homeTeam) : \(data.homeStarting.count) titulaires · \(data.homeBench.count) remplaçants")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(match.awayFlag) \(match.awayTeam) : \(data.awayStarting.count) titulaires · \(data.awayBench.count) remplaçants")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        Button("Vérifier et importer →") { reviewData = data }
                            .tint(.indigo)

                    case .error(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                        Button("Réessayer") { fetcher.state = .idle }
                            .tint(.red)
                    }
                }
            }
            .navigationTitle("Importer la composition")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if eventIDText.isEmpty, let saved = match.sofascoreLink {
                    eventIDText = saved
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { reviewData.map { IdentifiableLineup(data: $0) } },
                set: { reviewData = $0?.data }
            )) { wrapper in
                LineupReviewSheet(
                    match: match,
                    data: Binding(
                        get: { wrapper.data },
                        set: { reviewData = $0 }
                    )
                ) { confirmed in
                    store.updateSofascoreLink(matchID: match.id, link: eventIDText)
                    onImport(confirmed)
                    dismiss()
                }
            }
        }
    }
}

// Helper for .sheet(item:)
private struct IdentifiableLineup: Identifiable {
    let id = UUID()
    var data: LineupData
}

// MARK: - Review / edit sheet

struct LineupReviewSheet: View {
    let match: Match
    @Binding var data: LineupData
    let onConfirm: (LineupData) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                teamBlock(flag: match.homeFlag, team: match.homeTeam,
                          starting: $data.homeStarting, bench: $data.homeBench, coach: $data.homeCoach)
                teamBlock(flag: match.awayFlag, team: match.awayTeam,
                          starting: $data.awayStarting, bench: $data.awayBench, coach: $data.awayCoach)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Vérifier la composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importer") { onConfirm(data) }.fontWeight(.bold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retour") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func teamBlock(
        flag: String, team: String,
        starting: Binding<[LineupPlayer]>,
        bench: Binding<[LineupPlayer]>,
        coach: Binding<String>
    ) -> some View {
        Section {
            ForEach(starting.indices, id: \.self) { i in
                playerRow(player: starting[i])
            }
            .onDelete { starting.wrappedValue.remove(atOffsets: $0) }
            Button {
                starting.wrappedValue.append(LineupPlayer(name: "", number: nil, position: nil))
            } label: {
                Label("Ajouter", systemImage: "plus.circle")
            }.tint(.blue)
        } header: {
            Text("\(flag) \(team) – Titulaires (\(starting.wrappedValue.count)/11)")
        }

        Section {
            ForEach(bench.indices, id: \.self) { i in
                playerRow(player: bench[i])
            }
            .onDelete { bench.wrappedValue.remove(atOffsets: $0) }
            Button {
                bench.wrappedValue.append(LineupPlayer(name: "", number: nil, position: nil))
            } label: {
                Label("Ajouter", systemImage: "plus.circle")
            }.tint(.blue)
        } header: {
            Text("\(flag) \(team) – Remplaçants (\(bench.wrappedValue.count))")
        }

        Section {
            TextField("Entraîneur", text: coach).autocorrectionDisabled()
        } header: {
            Text("\(flag) \(team) – Entraîneur")
        }
    }

    @ViewBuilder
    private func playerRow(player: Binding<LineupPlayer>) -> some View {
        HStack(spacing: 10) {
            if let num = player.wrappedValue.number {
                Text("#\(num)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
            TextField("Nom", text: player.name).autocorrectionDisabled()
        }
    }
}

// MARK: - Lineup detail / edit sheet (for already-imported lineups)

struct LineupDetailSheet: View {
    let match: Match
    let onSave: (LineupData) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerStore.self) private var playerStore
    @State private var data: LineupData
    @State private var selectedPlayer: Player?


    init(match: Match, onSave: @escaping (LineupData) -> Void) {
        self.match  = match
        self.onSave = onSave
        _data = State(initialValue: match.lineup ?? LineupData())
    }

    var body: some View {
        NavigationStack {
            List {
                teamBlock(flag: match.homeFlag, team: match.homeTeam,
                          starting: $data.homeStarting, bench: $data.homeBench, coach: $data.homeCoach)
                teamBlock(flag: match.awayFlag, team: match.awayTeam,
                          starting: $data.awayStarting, bench: $data.awayBench, coach: $data.awayCoach)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(data)
                    }
                    .fontWeight(.bold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $selectedPlayer) { player in
                PlayerCardSheet(player: player)
                    .environment(playerStore)
            }
        }
    }

    @ViewBuilder
    private func teamBlock(
        flag: String, team: String,
        starting: Binding<[LineupPlayer]>,
        bench: Binding<[LineupPlayer]>,
        coach: Binding<String>
    ) -> some View {
        Section {
            ForEach(starting.indices, id: \.self) { i in
                playerRow(player: starting[i], team: team)
            }
            .onDelete { starting.wrappedValue.remove(atOffsets: $0) }
            Button { starting.wrappedValue.append(LineupPlayer(name: "", number: nil, position: nil)) }
                label: { Label("Ajouter", systemImage: "plus.circle") }
                .tint(.blue)
        } header: {
            Text("\(flag) \(team) – Titulaires (\(starting.wrappedValue.count))")
        }

        Section {
            ForEach(bench.indices, id: \.self) { i in
                playerRow(player: bench[i], team: team)
            }
            .onDelete { bench.wrappedValue.remove(atOffsets: $0) }
            Button { bench.wrappedValue.append(LineupPlayer(name: "", number: nil, position: nil)) }
                label: { Label("Ajouter", systemImage: "plus.circle") }
                .tint(.blue)
        } header: {
            Text("\(flag) \(team) – Remplaçants (\(bench.wrappedValue.count))")
        }

        Section {
            TextField("Entraîneur", text: coach).autocorrectionDisabled()
        } header: {
            Text("\(flag) \(team) – Entraîneur")
        }
    }

    // Look up the Player object matching a lineup entry: number first, then name fallback
    private func squadPlayer(number: Int?, name: String, team: String) -> Player? {
        guard let squad = Player.allSquads[team] else { return nil }
        if let num = number,
           let byNumber = squad.first(where: { playerStore.number(for: $0) == num }) {
            return byNumber
        }
        guard !name.isEmpty else { return nil }
        return squad.first { playerStore.name(for: $0).lowercased() == name.lowercased() }
            ?? squad.first { $0.name.lowercased() == name.lowercased() }
    }

    @ViewBuilder
    private func playerRow(player: Binding<LineupPlayer>, team: String) -> some View {
        HStack(spacing: 10) {
            if let found = squadPlayer(number: player.wrappedValue.number, name: player.wrappedValue.name, team: team) {
                PlayerAvatarView(player: found, size: 36)
                    .onTapGesture { selectedPlayer = found }
            } else {
                ZStack {
                    Circle().fill(Color.secondary.opacity(0.15))
                    if let num = player.wrappedValue.number {
                        Text("\(num)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "person")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 36, height: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                TextField("Nom", text: player.name).autocorrectionDisabled()
                if let num = player.wrappedValue.number {
                    Text("#\(num)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Player card sheet (read-only, portrait agrandi)

struct PlayerCardSheet: View {
    let player: Player
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PlayerAvatarView(player: player, size: 140)
                    .shadow(radius: 8)

                VStack(spacing: 6) {
                    Text(playerStore.name(for: player))
                        .font(.title2.bold())
                    HStack(spacing: 10) {
                        Text("#\(playerStore.number(for: player))")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(playerStore.position(for: player).color)
                        Text(playerStore.position(for: player).localizedName)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(playerStore.position(for: player).color, in: Capsule())
                    }
                    Text("\(teamFlags[player.team] ?? "") \(player.team)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
