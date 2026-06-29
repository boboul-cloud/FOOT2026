// PredictionStore.swift
// FOOT2026
// Observable store — persists the user's score predictions per match and scores
// them against the real results (exact score = 3 pts, right outcome = 1 pt).

import SwiftUI

struct Prediction: Codable, Equatable {
    var home: Int
    var away: Int
}

/// Outcome of comparing a prediction to the actual result.
enum PredictionOutcome: Equatable {
    case exact      // 3 pts — perfect score
    case correct    // 1 pt  — right winner / draw, wrong score
    case wrong      // 0 pt
    case pending    // match not played yet

    var points: Int {
        switch self {
        case .exact:   return 3
        case .correct: return 1
        case .wrong, .pending: return 0
        }
    }
}

@MainActor
@Observable
final class PredictionStore {

    private let saveKey = "foot2026_predictions"

    /// Keyed by match id (UUID string — stable across launches).
    private var predictions: [String: Prediction] = [:]

    init() { load() }

    // MARK: - Accessors

    func prediction(for matchID: UUID) -> Prediction? {
        predictions[matchID.uuidString]
    }

    var count: Int { predictions.count }

    // MARK: - Mutations

    func setPrediction(home: Int, away: Int, for matchID: UUID) {
        predictions[matchID.uuidString] = Prediction(home: home, away: away)
        save()
    }

    func clear(matchID: UUID) {
        predictions.removeValue(forKey: matchID.uuidString)
        save()
    }

    // MARK: - Scoring (pure, so it's directly unit-testable)

    /// Compares a prediction to a match result. Pure — no stored state.
    nonisolated static func outcome(of p: Prediction, against match: Match) -> PredictionOutcome {
        guard let h = match.homeScore, let a = match.awayScore else { return .pending }
        if p.home == h && p.away == a { return .exact }
        return sameSign(p.home - p.away, h - a) ? .correct : .wrong
    }

    /// Aggregate stats over the matches that have a prediction.
    struct Summary: Equatable {
        var points = 0
        var exact = 0
        var correct = 0
        var wrong = 0
        var pending = 0
        var total = 0   // matches with a prediction
    }

    /// Pure aggregation: counts every match for which `lookup` returns a prediction.
    nonisolated static func summary(
        of matches: [Match],
        lookup: (Match) -> Prediction?
    ) -> Summary {
        var s = Summary()
        for match in matches {
            guard let p = lookup(match) else { continue }
            let outcome = outcome(of: p, against: match)
            s.total += 1
            s.points += outcome.points
            switch outcome {
            case .exact:   s.exact += 1
            case .correct: s.correct += 1
            case .wrong:   s.wrong += 1
            case .pending: s.pending += 1
            }
        }
        return s
    }

    private nonisolated static func sameSign(_ x: Int, _ y: Int) -> Bool {
        (x > 0 && y > 0) || (x < 0 && y < 0) || (x == 0 && y == 0)
    }

    // MARK: - Instance convenience (used by the views)

    /// Compares the stored prediction (if any) to a match's actual result.
    func outcome(for match: Match) -> PredictionOutcome? {
        guard let p = prediction(for: match.id) else { return nil }
        return Self.outcome(of: p, against: match)
    }

    func summary(for matches: [Match]) -> Summary {
        Self.summary(of: matches) { prediction(for: $0.id) }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([String: Prediction].self, from: data)
        else { return }
        predictions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(predictions) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }
}
