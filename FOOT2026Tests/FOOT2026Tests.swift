// FOOT2026Tests.swift
// Unit tests for the tournament logic: group ranking (incl. head-to-head),
// the third-place dispatch table, and prediction scoring.

import XCTest
@testable import FOOT2026

// MARK: - Test data builders

private func makeStanding(_ team: String, won: Int, drawn: Int, lost: Int,
                          gf: Int, ga: Int) -> TeamStanding {
    TeamStanding(team: team, flag: "🏳️", group: .A,
                 played: won + drawn + lost, won: won, drawn: drawn, lost: lost,
                 goalsFor: gf, goalsAgainst: ga)
}

private func makeMatch(_ home: String, _ away: String,
                       _ homeScore: Int?, _ awayScore: Int?,
                       group: Group = .A, stage: Stage = .groupStage) -> Match {
    Match(id: UUID(), homeTeam: home, awayTeam: away,
          homeFlag: "🏳️", awayFlag: "🏳️", date: Date(),
          venue: "", city: "", stage: stage, group: group,
          homeScore: homeScore, awayScore: awayScore)
}

// MARK: - Group ranking

final class StandingsTests: XCTestCase {

    private let store = MatchStore()

    /// Teams level on points, goal difference and goals scored overall must be
    /// separated by the head-to-head result — not by alphabetical order.
    func testHeadToHeadBreaksTie() {
        let alpha = makeStanding("Alpha", won: 1, drawn: 1, lost: 1, gf: 3, ga: 3)
        let zeta  = makeStanding("Zeta",  won: 1, drawn: 1, lost: 1, gf: 3, ga: 3)
        let h2h = makeMatch("Zeta", "Alpha", 2, 1)   // Zeta won between them

        let ranked = store.rankGroup([alpha, zeta], matches: [h2h])

        XCTAssertEqual(ranked.map(\.team), ["Zeta", "Alpha"],
                       "Head-to-head winner should rank first despite alphabetical order")
    }

    /// Overall points (criterion 1) take precedence over head-to-head.
    func testOverallPointsBeatHeadToHead() {
        let beta  = makeStanding("Beta",  won: 2, drawn: 0, lost: 1, gf: 5, ga: 3) // 6 pts
        let gamma = makeStanding("Gamma", won: 1, drawn: 0, lost: 2, gf: 3, ga: 4) // 3 pts
        let h2h = makeMatch("Gamma", "Beta", 1, 0)   // Gamma won between them

        let ranked = store.rankGroup([beta, gamma], matches: [h2h])

        XCTAssertEqual(ranked.map(\.team), ["Beta", "Gamma"])
    }

    /// Goal difference (criterion 2) separates teams equal on points.
    func testGoalDifferenceOrders() {
        let x = makeStanding("X", won: 1, drawn: 0, lost: 0, gf: 4, ga: 0) // +4
        let y = makeStanding("Y", won: 1, drawn: 0, lost: 0, gf: 2, ga: 1) // +1
        let ranked = store.rankGroup([y, x], matches: [])
        XCTAssertEqual(ranked.map(\.team), ["X", "Y"])
    }
}

// MARK: - Third-place dispatch table

final class ThirdPlaceTableTests: XCTestCase {

    func testTableShape() {
        // 12 groups, 8 qualifying thirds → C(12,8) = 495 combinations.
        XCTAssertEqual(MatchStore.thirdPlaceTable.count, 495)
        for (key, slots) in MatchStore.thirdPlaceTable {
            XCTAssertEqual(key.count, 8, "Each key lists the 8 qualifying groups")
            XCTAssertEqual(slots.count, 8, "Each combination fills 8 slots")
        }
    }

    func testKeysAreSorted() {
        // Keys must be the sorted group letters so the lookup is order-independent.
        for key in MatchStore.thirdPlaceTable.keys {
            XCTAssertEqual(key, String(key.sorted()))
        }
    }
}

// MARK: - Prediction scoring

final class PredictionTests: XCTestCase {

    func testOutcomes() {
        XCTAssertEqual(
            PredictionStore.outcome(of: Prediction(home: 2, away: 1),
                                    against: makeMatch("A", "B", 2, 1)),
            .exact)
        XCTAssertEqual(
            PredictionStore.outcome(of: Prediction(home: 1, away: 0),
                                    against: makeMatch("A", "B", 3, 0)),
            .correct, "Right winner, wrong score")
        XCTAssertEqual(
            PredictionStore.outcome(of: Prediction(home: 2, away: 2),
                                    against: makeMatch("A", "B", 1, 1)),
            .correct, "Predicted a draw, match drawn")
        XCTAssertEqual(
            PredictionStore.outcome(of: Prediction(home: 1, away: 0),
                                    against: makeMatch("A", "B", 0, 2)),
            .wrong)
        XCTAssertEqual(
            PredictionStore.outcome(of: Prediction(home: 1, away: 1),
                                    against: makeMatch("A", "B", nil, nil)),
            .pending)
    }

    func testOutcomePoints() {
        XCTAssertEqual(PredictionOutcome.exact.points, 3)
        XCTAssertEqual(PredictionOutcome.correct.points, 1)
        XCTAssertEqual(PredictionOutcome.wrong.points, 0)
        XCTAssertEqual(PredictionOutcome.pending.points, 0)
    }

    func testSummaryAggregates() {
        let a = makeMatch("A", "B", 2, 1) // exact → 3
        let b = makeMatch("A", "B", 3, 0) // correct → 1
        let c = makeMatch("A", "B", 0, 2) // wrong → 0
        let preds: [UUID: Prediction] = [
            a.id: Prediction(home: 2, away: 1),
            b.id: Prediction(home: 1, away: 0),
            c.id: Prediction(home: 1, away: 0),
        ]

        let s = PredictionStore.summary(of: [a, b, c]) { preds[$0.id] }

        XCTAssertEqual(s, PredictionStore.Summary(
            points: 4, exact: 1, correct: 1, wrong: 1, pending: 0, total: 3))
    }
}
