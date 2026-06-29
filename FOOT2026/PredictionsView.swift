// PredictionsView.swift
// FOOT2026
// Predictions leaderboard: total points and per-match breakdown.

import SwiftUI

struct PredictionsView: View {
    @Environment(MatchStore.self) private var store
    @Environment(PredictionStore.self) private var predictions

    private var predictedMatches: [Match] {
        store.matches
            .filter { predictions.prediction(for: $0.id) != nil }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        // `Group` is qualified because the app defines its own `enum Group`.
        SwiftUI.Group {
            if predictedMatches.isEmpty {
                ContentUnavailableView(
                    "Aucun pronostic",
                    systemImage: "target",
                    description: Text("Ouvrez un match et saisissez le score que vous prévoyez. Vous gagnez 3 points pour un score exact, 1 point pour le bon résultat.")
                )
            } else {
                List {
                    scoreSection
                    ForEach(predictedMatches) { match in
                        row(for: match)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Pronostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Total

    private var scoreSection: some View {
        let s = predictions.summary(for: store.matches)
        return Section {
            HStack(spacing: 10) {
                tile(value: "\(s.points)", label: s.points > 1 ? "points" : "point",
                     systemImage: "star.fill", color: .accentColor)
                tile(value: "\(s.exact)", label: "exacts",
                     systemImage: "scope", color: .green)
                tile(value: "\(s.correct)", label: "bons", // bon résultat
                     systemImage: "checkmark", color: .blue)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            HStack {
                Text("Pronostics évalués")
                    .font(.subheadline)
                Spacer()
                Text("\(s.exact + s.correct + s.wrong) / \(s.total)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Score")
        } footer: {
            Text("Score exact : 3 points · Bon résultat (vainqueur ou nul) : 1 point. Pour les matchs à élimination directe, le score retenu est celui avant les tirs au but (prolongation comprise).")
        }
    }

    @ViewBuilder
    private func tile(value: String, label: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage).font(.callout).foregroundStyle(color)
            Text(value).font(.system(.title3, design: .rounded, weight: .bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Match row

    @ViewBuilder
    private func row(for match: Match) -> some View {
        let home = store.resolveTeam(match.homeTeam)
        let away = store.resolveTeam(match.awayTeam)
        let p = predictions.prediction(for: match.id)
        let outcome = predictions.outcome(for: match)

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(home.flag) \(home.name) – \(away.name) \(away.flag)")
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let p {
                        Text("Prono : \(p.home)–\(p.away)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if match.hasScore {
                        Text("Résultat : \(match.homeScore!)–\(match.awayScore!)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            outcomeBadge(outcome)
        }
    }

    @ViewBuilder
    private func outcomeBadge(_ outcome: PredictionOutcome?) -> some View {
        switch outcome {
        case .exact:
            badge("+3", color: .green, icon: "scope")
        case .correct:
            badge("+1", color: .blue, icon: "checkmark")
        case .wrong:
            badge("0", color: .red, icon: "xmark")
        case .pending, .none:
            Text("à venir")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
    }

    @ViewBuilder
    private func badge(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption.bold().monospaced())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color, in: Capsule())
    }
}
