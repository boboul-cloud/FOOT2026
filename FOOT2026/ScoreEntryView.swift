// ScoreEntryView.swift
// FOOT2026
// Sheet to enter / edit a match score and goal scorers

import SwiftUI

struct ScoreEntryView: View {
    let match: Match
    @Environment(MatchStore.self) private var store
    @Environment(PredictionStore.self) private var predictions
    @Environment(\.dismiss) private var dismiss

    @State private var homeText: String = ""
    @State private var awayText: String = ""
    @State private var predHomeText: String = ""
    @State private var predAwayText: String = ""
    @State private var homeScorers: [GoalScorer] = []
    @State private var awayScorers: [GoalScorer] = []
    @State private var matchLink: String = ""
    @State private var showStandings    = false
    @State private var showLineupImport = false
    @State private var showLineupDetail = false

    private var currentMatch: Match? {
        store.matches.first { $0.id == match.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Teams + score
                Section {
                    HStack(spacing: 0) {
                        teamColumn(flag: match.homeFlag, name: match.homeTeam)
                        VStack(spacing: 4) {
                            HStack(spacing: 12) {
                                scoreField(text: $homeText)
                                Text("—")
                                    .font(.title.bold())
                                    .foregroundStyle(.secondary)
                                scoreField(text: $awayText)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        teamColumn(flag: match.awayFlag, name: match.awayTeam)
                    }
                    .padding(.vertical, 4)

                    VStack(spacing: 2) {
                        Text("\(match.parisDate)  ·  \(match.parisTime)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(match.venue), \(match.city)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // My prediction
                predictionSection

                // Home scorers
                scorersSection(
                    team: match.homeTeam,
                    flag: match.homeFlag,
                    scorers: $homeScorers
                )

                // Away scorers
                scorersSection(
                    team: match.awayTeam,
                    flag: match.awayFlag,
                    scorers: $awayScorers
                )

                // Match link
                Section {
                    if let liveURL = match.googleLiveURL {
                        Link(destination: liveURL) {
                            Label("Suivre le match en direct", systemImage: "dot.radiowaves.left.and.right")
                                .font(.subheadline.bold())
                        }
                        .tint(.red)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        TextField("Coller un lien (replay, stats…)", text: $matchLink)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !matchLink.isEmpty {
                            Button {
                                matchLink = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let url = URL(string: matchLink), !matchLink.isEmpty,
                       UIApplication.shared.canOpenURL(url) {
                        Link(destination: url) {
                            Label("Ouvrir le lien", systemImage: "arrow.up.right.square")
                                .font(.footnote)
                        }
                    }
                } header: {
                    Text("Lien")
                }

                // Composition
                Section {
                    if let lineup = currentMatch?.lineup, !lineup.isEmpty {
                        Button {
                            showLineupDetail = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Composition importée", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline.bold()).foregroundStyle(.indigo)
                                    Text("\(match.homeFlag) \(match.homeTeam) : \(lineup.homeStarting.count) tit. · \(lineup.homeBench.count) rempl.")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("\(match.awayFlag) \(match.awayTeam) : \(lineup.awayStarting.count) tit. · \(lineup.awayBench.count) rempl.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        Button("Réimporter depuis Sofascore") { showLineupImport = true }
                            .font(.footnote)
                            .tint(.secondary)
                    } else {
                        Button {
                            showLineupImport = true
                        } label: {
                            Label("Importer la composition Sofascore…", systemImage: "person.3.fill")
                        }
                        .tint(.indigo)
                    }
                } header: {
                    Text("Composition")
                }

                Section {
                    Button {
                        saveScore()
                    } label: {
                        Label("Enregistrer", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!isValid)

                    if match.hasScore {
                        Button(role: .destructive) {
                            store.clearScore(matchID: match.id)
                            dismiss()
                        } label: {
                            Label("Effacer le score", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }

                    if match.stage == .groupStage, let group = match.group {
                        Button {
                            showStandings = true
                        } label: {
                            Label("Classement Groupe \(group.rawValue)", systemImage: "list.number")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.blue)
                        .sheet(isPresented: $showStandings) {
                            StandingsView(initialGroup: group)
                                .environment(store)
                        }
                    }
                }
            }
            .navigationTitle("Saisir le score")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLineupImport) {
                LineupImportSheet(match: currentMatch ?? match) { lineup in
                    store.updateLineup(lineup, matchID: match.id)
                }
            }
            .sheet(isPresented: $showLineupDetail) {
                LineupDetailSheet(match: currentMatch ?? match) { updated in
                    store.updateLineup(updated, matchID: match.id)
                    showLineupDetail = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear {
                if let h = match.homeScore { homeText = "\(h)" }
                if let a = match.awayScore { awayText = "\(a)" }
                homeScorers = match.homeScorers
                awayScorers = match.awayScorers
                matchLink = match.matchLink ?? ""
                if let p = predictions.prediction(for: match.id) {
                    predHomeText = "\(p.home)"
                    predAwayText = "\(p.away)"
                }
            }
        }
    }

    // MARK: - Prediction section

    @ViewBuilder
    private var predictionSection: some View {
        Section {
            HStack(spacing: 12) {
                Text(match.homeFlag)
                scoreField(text: $predHomeText)
                Text("—").font(.title3.bold()).foregroundStyle(.secondary)
                scoreField(text: $predAwayText)
                Text(match.awayFlag)
                Spacer()
                if hasPrediction {
                    Button {
                        predictions.clear(matchID: match.id)
                        predHomeText = ""; predAwayText = ""
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let ph = Int(predHomeText), let pa = Int(predAwayText) {
                Button {
                    predictions.setPrediction(home: ph, away: pa, for: match.id)
                } label: {
                    Label(hasPrediction ? "Mettre à jour le pronostic" : "Enregistrer le pronostic",
                          systemImage: "target")
                        .font(.subheadline)
                }
                .tint(.purple)
            }

            if let outcome = predictions.outcome(for: currentMatch ?? match),
               outcome != .pending {
                HStack {
                    Text(outcomeLabel(outcome))
                        .font(.subheadline.bold())
                        .foregroundStyle(outcomeColor(outcome))
                    Spacer()
                    Text("+\(outcome.points) pt\(outcome.points > 1 ? "s" : "")")
                        .font(.subheadline.bold().monospaced())
                        .foregroundStyle(outcomeColor(outcome))
                }
            }
        } header: {
            Text("Mon pronostic")
        } footer: {
            Text("Score exact : 3 points · Bon résultat : 1 point.")
        }
    }

    private var hasPrediction: Bool {
        predictions.prediction(for: match.id) != nil
    }

    private func outcomeLabel(_ o: PredictionOutcome) -> String {
        switch o {
        case .exact:   return "Score exact 🎯"
        case .correct: return "Bon résultat ✅"
        case .wrong:   return "Raté ❌"
        case .pending: return ""
        }
    }

    private func outcomeColor(_ o: PredictionOutcome) -> Color {
        switch o {
        case .exact:   return .green
        case .correct: return .blue
        case .wrong:   return .red
        case .pending: return .secondary
        }
    }

    // MARK: - Scorers section

    @ViewBuilder
    private func scorersSection(
        team: String,
        flag: String,
        scorers: Binding<[GoalScorer]>
    ) -> some View {
        Section {
            ForEach(scorers.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Text("⚽️")
                    TextField("Nom du joueur", text: scorers[i].name)
                        .frame(maxWidth: .infinity)
                    Stepper(
                        "\(scorers[i].goals.wrappedValue)",
                        value: scorers[i].goals,
                        in: 1...20
                    )
                    .labelsHidden()
                    .frame(width: 80)
                    Text("\(scorers[i].goals.wrappedValue) but\(scorers[i].goals.wrappedValue > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .onDelete { offsets in
                scorers.wrappedValue.remove(atOffsets: offsets)
            }

            Button {
                scorers.wrappedValue.append(
                    GoalScorer(name: "", team: team, flag: flag, goals: 1)
                )
            } label: {
                Label("Ajouter un buteur", systemImage: "plus.circle.fill")
            }
            .tint(.orange)
        } header: {
            Text("\(flag) \(team)")
        }
    }

    // MARK: - Helpers

    private var isValid: Bool {
        Int(homeText) != nil && Int(awayText) != nil
    }

    private func saveScore() {
        guard let h = Int(homeText), let a = Int(awayText) else { return }
        store.updateScore(matchID: match.id, home: h, away: a)
        let cleanHome = homeScorers.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let cleanAway = awayScorers.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        store.updateScorers(matchID: match.id, homeScorers: cleanHome, awayScorers: cleanAway)
        store.updateMatchLink(matchID: match.id, link: matchLink)
        dismiss()
    }

    @ViewBuilder
    private func teamColumn(flag: String, name: String) -> some View {
        VStack(spacing: 4) {
            Text(flag).font(.system(size: 36))
            Text(name)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 80)
    }

    @ViewBuilder
    private func scoreField(text: Binding<String>) -> some View {
        TextField("0", text: text)
            .keyboardType(.numberPad)
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(width: 60, height: 54)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
