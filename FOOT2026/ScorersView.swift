// ScorersView.swift
// FOOT2026
// Top scorers leaderboard + recap and per-team breakdown

import SwiftUI

struct ScorersView: View {
    @Environment(MatchStore.self) private var store
    @State private var mode: Mode = .ranking

    enum Mode: String, CaseIterable, Identifiable {
        case ranking = "Classement"
        case byTeam  = "Par équipe"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if store.topScorers.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        Picker("Affichage", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGroupedBackground))

                        List {
                            recapSection
                            distributionSection
                            switch mode {
                            case .ranking: rankingSection
                            case .byTeam:  byTeamSections
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Buteurs")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Recap

    private var recapSection: some View {
        Section("Récap") {
            HStack(spacing: 10) {
                statTile(value: "\(totalGoals)", label: "buts",
                         systemImage: "soccerball", color: .accentColor)
                statTile(value: "\(scorerCount)", label: scorerCount > 1 ? "buteurs" : "buteur",
                         systemImage: "person.fill", color: .green)
                statTile(value: "\(teamsScored)", label: teamsScored > 1 ? "équipes" : "équipe",
                         systemImage: "flag.fill", color: .orange)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

            if let top = byTeam.first {
                HStack(spacing: 10) {
                    Text(top.flag).font(.title2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Meilleure attaque")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(top.team).font(.subheadline.bold())
                    }
                    Spacer()
                    Text("\(top.total) ⚽️")
                        .font(.system(.body, design: .rounded, weight: .bold))
                }
            }
        }
    }

    @ViewBuilder
    private func statTile(value: String, label: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Goal distribution ("X joueurs à Y buts")

    private var distributionSection: some View {
        Section("Répartition des buts") {
            ForEach(goalDistribution, id: \.goals) { row in
                HStack {
                    Text("\(row.goals) but\(row.goals > 1 ? "s" : "")")
                        .font(.subheadline.bold())
                        .frame(minWidth: 60, alignment: .leading)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Text("\(row.players) joueur\(row.players > 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Ranking (global leaderboard)

    private var rankingSection: some View {
        Section("Classement") {
            ForEach(Array(store.topScorers.enumerated()), id: \.element.id) { rank, scorer in
                ScorersRow(rank: rank + 1, scorer: scorer)
            }
        }
    }

    // MARK: - By team

    private var byTeamSections: some View {
        ForEach(byTeam, id: \.team) { group in
            Section {
                ForEach(group.scorers) { scorer in
                    TeamScorerRow(scorer: scorer)
                }
            } header: {
                HStack {
                    Text(group.flag)
                    Text(group.team)
                    Spacer()
                    Text("\(group.total) ⚽️")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "soccerball")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Aucun buteur enregistré")
                .font(.title3.bold())
            Text("Saisissez les scores et les buteurs\ndepuis la liste des matchs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Derived stats

    private var totalGoals: Int { store.topScorers.reduce(0) { $0 + $1.goals } }
    private var scorerCount: Int { store.topScorers.count }
    private var teamsScored: Int { Set(store.topScorers.map(\.team)).count }

    /// [(goals, number of players with that many goals)] sorted by goals desc.
    private var goalDistribution: [(goals: Int, players: Int)] {
        var dict: [Int: Int] = [:]
        for s in store.topScorers { dict[s.goals, default: 0] += 1 }
        return dict.map { (goals: $0.key, players: $0.value) }
            .sorted { $0.goals > $1.goals }
    }

    /// Scorers grouped by team, sorted by team total (desc), then alphabetically.
    private var byTeam: [(team: String, flag: String, total: Int, scorers: [MatchStore.ScorerStat])] {
        Dictionary(grouping: store.topScorers, by: \.team)
            .map { team, scorers in
                (team: team,
                 flag: scorers.first?.flag ?? "🏳️",
                 total: scorers.reduce(0) { $0 + $1.goals },
                 scorers: scorers.sorted { $0.goals > $1.goals })
            }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.team < $1.team }
    }
}

// MARK: - "csc" (own goal) badge

private struct CscBadge: View {
    var body: some View {
        Text("csc")
            .font(.caption2.bold())
            .foregroundStyle(.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.orange.opacity(0.15), in: Capsule())
    }
}

// MARK: - Google search helper

private func googleSearchURL(for name: String) -> URL? {
    let query = "\(name) footballeur"
    guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
    return URL(string: "https://www.google.com/search?q=\(encoded)")
}

// MARK: - Ranking row

private struct ScorersRow: View {
    let rank: Int
    let scorer: MatchStore.ScorerStat
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                rankBackground
                    .frame(width: 36, height: 36)
                Text("\(rank)")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(rankForeground)
            }

            // Flag + name + team
            Text(scorer.flag)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(scorer.name)
                        .font(.body.bold())
                    if scorer.isOwnGoal { CscBadge() }
                }
                Text(scorer.team)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if scorer.shootoutGoals > 0 {
                    Text("dont \(scorer.shootoutGoals) t.a.b.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Goal count
            HStack(spacing: 4) {
                Text("⚽️")
                    .font(.subheadline)
                Text("\(scorer.goals)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(rank <= 3 ? Color.accentColor : .primary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = googleSearchURL(for: scorer.name) { openURL(url) }
        }
    }

    @ViewBuilder
    private var rankBackground: some View {
        switch rank {
        case 1:
            Circle().fill(Color.yellow.gradient)
        case 2:
            Circle().fill(Color.gray.opacity(0.6).gradient)
        case 3:
            Circle().fill(Color.brown.opacity(0.7).gradient)
        default:
            Circle().fill(Color(.systemGray5))
        }
    }

    private var rankForeground: Color {
        rank <= 3 ? .white : .secondary
    }
}

// MARK: - Per-team row (flag is in the section header, so omit it here)

private struct TeamScorerRow: View {
    let scorer: MatchStore.ScorerStat
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 6) {
            Text(scorer.name)
                .font(.body)
            if scorer.isOwnGoal { CscBadge() }
            if scorer.shootoutGoals > 0 {
                Text("dont \(scorer.shootoutGoals) t.a.b.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("\(scorer.goals)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                Text("⚽️")
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = googleSearchURL(for: scorer.name) { openURL(url) }
        }
    }
}

#Preview {
    ScorersView()
        .environment(MatchStore())
}
