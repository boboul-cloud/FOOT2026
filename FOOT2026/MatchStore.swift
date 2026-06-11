// MatchStore.swift
// FOOT2026
// Observable store — persists scores in UserDefaults

import SwiftUI

@MainActor
@Observable
final class MatchStore {

    private let saveKey = "foot2026_matches"

    var matches: [Match] = []

    init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Match].self, from: data) {
            // Merge saved scores onto the canonical fixture list
            let dict = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
            matches = Match.allMatches.map { fixture in
                if let saved = dict[fixture.id] {
                    var m = fixture
                    m.homeScore = saved.homeScore
                    m.awayScore = saved.awayScore
                    return m
                }
                return fixture
            }
        } else {
            matches = Match.allMatches
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(matches) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    func updateScore(matchID: UUID, home: Int?, away: Int?) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].homeScore = home
        matches[idx].awayScore = away
        save()
    }

    func clearScore(matchID: UUID) {
        updateScore(matchID: matchID, home: nil, away: nil)
    }

    /// Auto-fills realistic random scores for all past matches that have no score yet.
    func autoFillPastMatches() {
        let now = Date()
        for idx in matches.indices where matches[idx].date < now && !matches[idx].hasScore {
            matches[idx].homeScore = randomGoals()
            matches[idx].awayScore = randomGoals()
        }
        save()
    }

    /// Clears every score in the store.
    func clearAllScores() {
        for idx in matches.indices {
            matches[idx].homeScore = nil
            matches[idx].awayScore = nil
        }
        save()
    }

    /// Realistic goal distribution: weighted toward low scores.
    private func randomGoals() -> Int {
        [0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 4].randomElement()!
    }

    // MARK: - Helpers

    var matchesByStage: [(stage: Stage, matches: [Match])] {
        let order: [Stage] = [.groupStage, .roundOf32, .roundOf16, .quarterFinal, .semiFinal, .thirdPlace, .final_]
        return order.compactMap { stage in
            let list = matches.filter { $0.stage == stage }
            return list.isEmpty ? nil : (stage, list)
        }
    }

    func matches(forGroup group: Group) -> [Match] {
        matches.filter { $0.group == group }.sorted { $0.date < $1.date }
    }
}
