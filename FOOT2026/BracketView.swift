// BracketView.swift
// FOOT2026
// Knockout phase bracket — teams resolved live from group standings

import SwiftUI

// MARK: - Confederations

/// The six football confederations, used to break down qualified teams by continent.
enum Confederation: String, CaseIterable {
    case uefa     = "UEFA"
    case conmebol = "CONMEBOL"
    case caf      = "CAF"
    case afc      = "AFC"
    case concacaf = "CONCACAF"
    case ofc      = "OFC"

    /// Short French continent label.
    var label: String {
        switch self {
        case .uefa:     return "Europe"
        case .conmebol: return "Am. du Sud"
        case .caf:      return "Afrique"
        case .afc:      return "Asie"
        case .concacaf: return "Am. N./C."
        case .ofc:      return "Océanie"
        }
    }

    var color: Color {
        switch self {
        case .uefa:     return .blue
        case .conmebol: return .green
        case .caf:      return .orange
        case .afc:      return .red
        case .concacaf: return .purple
        case .ofc:      return .teal
        }
    }

    /// Full French name of the confederation.
    var fullName: String {
        switch self {
        case .uefa:     return "Union des associations européennes de football"
        case .conmebol: return "Confédération sud-américaine de football"
        case .caf:      return "Confédération africaine de football"
        case .afc:      return "Confédération asiatique de football"
        case .concacaf: return "Confédération d'Amérique du Nord, centrale et Caraïbe"
        case .ofc:      return "Confédération du football d'Océanie"
        }
    }

    /// French Wikipedia page explaining the confederation.
    var wikipediaURL: URL? {
        let page: String
        switch self {
        case .uefa:     page = "Union des associations européennes de football"
        case .conmebol: page = "Confédération sud-américaine de football"
        case .caf:      page = "Confédération africaine de football"
        case .afc:      page = "Confédération asiatique de football"
        case .concacaf: page = "CONCACAF"
        case .ofc:      page = "Confédération du football d'Océanie"
        }
        let encoded = page
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? page
        return URL(string: "https://fr.wikipedia.org/wiki/\(encoded)")
    }
}

/// Maps every team name used in the tournament to its confederation.
let teamConfederations: [String: Confederation] = [
    // UEFA
    "Espagne": .uefa, "France": .uefa, "Angleterre": .uefa, "Portugal": .uefa,
    "Pays-Bas": .uefa, "Belgique": .uefa, "Allemagne": .uefa, "Croatie": .uefa,
    "Italie": .uefa, "Suisse": .uefa, "Danemark": .uefa, "Turquie": .uefa,
    "Autriche": .uefa, "Norvège": .uefa, "Suède": .uefa, "Écosse": .uefa,
    "Tchéquie": .uefa, "Bosnie-Herzégovine": .uefa,
    // CONMEBOL
    "Argentine": .conmebol, "Brésil": .conmebol, "Colombie": .conmebol,
    "Uruguay": .conmebol, "Équateur": .conmebol, "Paraguay": .conmebol,
    // CAF
    "Maroc": .caf, "Sénégal": .caf, "Algérie": .caf, "Égypte": .caf,
    "Côte d'Ivoire": .caf, "Tunisie": .caf, "Afrique du Sud": .caf,
    "Ghana": .caf, "RD Congo": .caf, "Cap-Vert": .caf,
    // AFC
    "Japon": .afc, "Iran": .afc, "Corée du Sud": .afc, "Australie": .afc,
    "Qatar": .afc, "Arabie Saoudite": .afc, "Irak": .afc, "Jordanie": .afc,
    "Ouzbékistan": .afc,
    // CONCACAF
    "Mexique": .concacaf, "États-Unis": .concacaf, "Canada": .concacaf,
    "Panama": .concacaf, "Haïti": .concacaf, "Curaçao": .concacaf,
    // OFC
    "Nouvelle-Zélande": .ofc,
]

// MARK: - Root view

struct BracketView: View {
    @Environment(MatchStore.self) private var store
    @State private var selectedStage: Stage = .roundOf32
    @State private var matchToEdit: Match? = nil
    @State private var showConfederationInfo = false

    private let knockoutStages: [Stage] = [
        .roundOf32, .roundOf16, .quarterFinal, .semiFinal, .thirdPlace, .final_
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stagePicker
                if !continentStats.isEmpty {
                    continentBar
                }
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(stageMatches) { match in
                            BracketMatchCard(match: match) {
                                // Resolve team names so ScoreEntryView shows real names
                                var display = match
                                let home = store.resolveTeam(match.homeTeam)
                                let away = store.resolveTeam(match.awayTeam)
                                display.homeTeam = home.name
                                display.homeFlag = home.flag
                                display.awayTeam = away.name
                                display.awayFlag = away.flag
                                matchToEdit = display
                            }
                        }
                        if stageMatches.isEmpty {
                            ContentUnavailableView(
                                "Aucun match",
                                systemImage: "sportscourt",
                                description: Text("Cette phase n'a pas encore de matchs.")
                            )
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tableau")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $matchToEdit) { match in
                ScoreEntryView(match: match)
                    .environment(store)
            }
            .sheet(isPresented: $showConfederationInfo) {
                ConfederationInfoView()
            }
        }
    }

    // MARK: - Stage picker

    private var stagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(knockoutStages, id: \.self) { stage in
                    Button {
                        withAnimation(.spring(duration: 0.2)) { selectedStage = stage }
                    } label: {
                        Text(stageShortName(stage))
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedStage == stage ? Color.accentColor : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedStage == stage ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Continent stats

    /// Number of teams per confederation at kickoff (group stage participants).
    private var startingTeamsByConf: [Confederation: Int] {
        var teams: [Confederation: Set<String>] = [:]
        for match in store.matches where match.stage == .groupStage {
            for name in [match.homeTeam, match.awayTeam] {
                if let conf = teamConfederations[name] {
                    teams[conf, default: []].insert(name)
                }
            }
        }
        return teams.mapValues(\.count)
    }

    /// Distinct qualified teams in the selected stage, counted per confederation
    /// alongside the starting total, sorted most-represented first.
    /// Unresolved placeholders are ignored.
    private var continentStats: [(conf: Confederation, count: Int, total: Int)] {
        let starting = startingTeamsByConf
        var teamsByConf: [Confederation: Set<String>] = [:]
        for match in stageMatches {
            for placeholder in [match.homeTeam, match.awayTeam] {
                let resolved = store.resolveTeam(placeholder)
                guard resolved.flag != "🏳️",
                      let conf = teamConfederations[resolved.name] else { continue }
                teamsByConf[conf, default: []].insert(resolved.name)
            }
        }
        return Confederation.allCases.compactMap { conf in
            let n = teamsByConf[conf]?.count ?? 0
            return n > 0 ? (conf, n, starting[conf] ?? n) : nil
        }
        .sorted { $0.count > $1.count }
    }

    private var continentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(continentStats, id: \.conf) { stat in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(stat.conf.color)
                            .frame(width: 7, height: 7)
                        Text(stat.conf.rawValue)
                            .font(.caption2.bold())
                        Text("\(stat.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(stat.conf.color)
                        Text("/ \(stat.total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                Button {
                    showConfederationInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func stageShortName(_ stage: Stage) -> String {
        switch stage {
        case .roundOf32:    return "1/32"
        case .roundOf16:    return "1/16"
        case .quarterFinal: return "1/4"
        case .semiFinal:    return "1/2"
        case .thirdPlace:   return "3e place"
        case .final_:       return "Finale"
        case .groupStage:   return "Groupes"
        }
    }

    // MARK: - Filtered matches

    private var stageMatches: [Match] {
        store.matches
            .filter { $0.stage == selectedStage }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Bracket match card

struct BracketMatchCard: View {
    let match: Match
    let onTap: () -> Void
    @Environment(MatchStore.self) private var store

    var body: some View {
        let home = store.resolveTeam(match.homeTeam)
        let away = store.resolveTeam(match.awayTeam)

        VStack(spacing: 0) {
            // ── Header bar ──
            HStack {
                Label(match.parisDate, systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .font(.caption2)
                    Text(match.city)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 7)

            Divider()

            // ── Teams + score ──
            HStack(spacing: 0) {
                // Home team
                teamColumn(flag: home.flag, name: home.name,
                           isWinner: matchWinner == .home)

                // Score / vs + time
                VStack(spacing: 5) {
                    if match.hasScore {
                        Text(match.scoreText)
                            .font(.title2.bold())
                            .monospacedDigit()
                    } else {
                        Text("vs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(match.parisTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .frame(width: 84)

                // Away team
                teamColumn(flag: away.flag, name: away.name,
                           isWinner: matchWinner == .away)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { onTap() }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func teamColumn(flag: String, name: String, isWinner: Bool) -> some View {
        VStack(spacing: 4) {
            Text(flag)
                .font(.system(size: 36))

            Text(name)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Color.primary)

            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(
            isWinner
                ? Color.green.opacity(0.08)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    // MARK: - Helpers

    private enum TeamSide { case home, away }

    private var matchWinner: TeamSide? {
        guard let h = match.homeScore, let a = match.awayScore else { return nil }
        if h > a { return .home }
        if a > h { return .away }
        return nil
    }

    private var cardBackground: Color {
        guard match.hasScore else { return Color(.secondarySystemGroupedBackground) }
        return Color(.secondarySystemGroupedBackground)
    }
}

// MARK: - Confederation info sheet

/// Explains each confederation acronym with its full name and a Wikipedia link.
struct ConfederationInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Confederation.allCases, id: \.self) { conf in
                        row(for: conf)
                    }
                } footer: {
                    Text("Les confédérations regroupent les fédérations nationales par continent. Touchez une ligne pour ouvrir sa page Wikipédia.")
                }
            }
            .navigationTitle("Confédérations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for conf: Confederation) -> some View {
        let content = HStack(spacing: 12) {
            Circle()
                .fill(conf.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(conf.rawValue)
                        .font(.subheadline.bold())
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(conf.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(conf.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if conf.wikipediaURL != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }

        if let url = conf.wikipediaURL {
            Link(destination: url) { content }
                .tint(.primary)
        } else {
            content
        }
    }
}
