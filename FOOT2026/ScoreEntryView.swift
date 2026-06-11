// ScoreEntryView.swift
// FOOT2026
// Sheet to enter / edit a match score

import SwiftUI

struct ScoreEntryView: View {
    let match: Match
    @Environment(MatchStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var homeText: String = ""
    @State private var awayText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {

                // Teams header
                HStack(spacing: 0) {
                    teamColumn(flag: match.homeFlag, name: match.homeTeam)
                    Text("VS")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 44)
                    teamColumn(flag: match.awayFlag, name: match.awayTeam)
                }
                .padding(.top, 8)

                // Score row
                HStack(spacing: 24) {
                    scoreField(text: $homeText)
                    Text("—")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.secondary)
                    scoreField(text: $awayText)
                }

                // Date/venue info
                VStack(spacing: 4) {
                    Text("\(match.parisDate)  ·  \(match.parisTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(match.venue), \(match.city)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
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
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .navigationTitle("Saisir le score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear {
                if let h = match.homeScore { homeText = "\(h)" }
                if let a = match.awayScore { awayText = "\(a)" }
            }
        }
    }

    // MARK: - Private

    private var isValid: Bool {
        Int(homeText) != nil && Int(awayText) != nil
    }

    private func saveScore() {
        guard let h = Int(homeText), let a = Int(awayText) else { return }
        store.updateScore(matchID: match.id, home: h, away: a)
        dismiss()
    }

    @ViewBuilder
    private func teamColumn(flag: String, name: String) -> some View {
        VStack(spacing: 6) {
            Text(flag).font(.system(size: 44))
            Text(name)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func scoreField(text: Binding<String>) -> some View {
        TextField("0", text: text)
            .keyboardType(.numberPad)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(width: 90, height: 70)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
