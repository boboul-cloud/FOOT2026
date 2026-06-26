// ScorersView.swift
// FOOT2026
// Top scorers leaderboard

import SwiftUI

struct ScorersView: View {
    @Environment(MatchStore.self) private var store

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if store.topScorers.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            HStack {
                                Text("⚽️ Total buts")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(store.topScorers.reduce(0) { $0 + $1.goals })")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.vertical, 2)
                        }
                        ForEach(Array(store.topScorers.enumerated()), id: \.element.id) { rank, scorer in
                            ScorersRow(rank: rank + 1, scorer: scorer)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Buteurs")
            .navigationBarTitleDisplayMode(.large)
        }
    }

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
}

// MARK: - Row

private struct ScorersRow: View {
    let rank: Int
    let scorer: MatchStore.ScorerStat
    @Environment(\.openURL) private var openURL

    private var googleSearchURL: URL? {
        let query = "\(scorer.name) footballeur"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.google.com/search?q=\(encoded)")
    }

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
                Text(scorer.name)
                    .font(.body.bold())
                Text(scorer.team)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            if let url = googleSearchURL {
                openURL(url)
            }
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

#Preview {
    ScorersView()
        .environment(MatchStore())
}
