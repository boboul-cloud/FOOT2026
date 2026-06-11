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

    // MARK: - Live score fetch

    enum FetchError: LocalizedError {
        case invalidURL, httpError
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL invalide"
            case .httpError:  return "Erreur réseau ESPN"
            }
        }
    }

    /// Fetch real completed match scores from ESPN's public API (no API key required).
    /// Returns the number of matches updated, or throws on network/parsing failure.
    @discardableResult
    func fetchLiveScores() async throws -> Int {
        // The scoreboard endpoint returns completed events for a given date range.
        let dateRange = "20260611-20260719"
        guard let url = URL(string:
            "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=\(dateRange)"
        ) else { throw FetchError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FetchError.httpError }

        let board = try JSONDecoder().decode(ESPNScoreboard.self, from: data)
        var updatedCount = 0

        for event in board.events {
            guard let comp = event.competitions.first,
                  comp.status.type.completed == true else { continue }

            let home = comp.competitors.first { $0.homeAway == "home" }
            let away = comp.competitors.first { $0.homeAway == "away" }

            guard let h = home, let a = away,
                  let hScore = Int(h.score ?? ""),
                  let aScore = Int(a.score ?? "") else { continue }

            if let idx = matches.firstIndex(where: {
                Self.espnMatches(french: $0.homeTeam, espn: h.team.displayName) &&
                Self.espnMatches(french: $0.awayTeam, espn: a.team.displayName)
            }) {
                if matches[idx].homeScore != hScore || matches[idx].awayScore != aScore {
                    matches[idx].homeScore = hScore
                    matches[idx].awayScore = aScore
                    updatedCount += 1
                }
            }
        }

        if updatedCount > 0 { save() }
        return updatedCount
    }

    /// Returns true if the French team name in the app corresponds to an ESPN English display name.
    private static func espnMatches(french: String, espn: String) -> Bool {
        let normalized = espn.lowercased()
        if let variants = teamNameMap[french] {
            return variants.contains { normalized == $0.lowercased() }
        }
        return french.lowercased() == normalized
    }

    /// French team names → possible ESPN English names.
    private static let teamNameMap: [String: [String]] = [
        "Mexique":            ["Mexico"],
        "Afrique du Sud":     ["South Africa"],
        "Corée du Sud":       ["South Korea", "Korea Republic"],
        "Tchéquie":           ["Czech Republic", "Czechia"],
        "Canada":             ["Canada"],
        "Bosnie-Herzégovine": ["Bosnia and Herzegovina", "Bosnia & Herzegovina"],
        "Qatar":              ["Qatar"],
        "Suisse":             ["Switzerland"],
        "Brésil":             ["Brazil"],
        "Maroc":              ["Morocco"],
        "Haïti":              ["Haiti"],
        "Écosse":             ["Scotland"],
        "États-Unis":         ["United States", "USA", "US"],
        "Paraguay":           ["Paraguay"],
        "Australie":          ["Australia"],
        "Turquie":            ["Turkey", "Türkiye"],
        "Allemagne":          ["Germany"],
        "Curaçao":            ["Curacao", "Curaçao"],
        "Côte d'Ivoire":      ["Ivory Coast", "Côte d'Ivoire"],
        "Équateur":           ["Ecuador"],
        "Pays-Bas":           ["Netherlands", "Holland"],
        "Japon":              ["Japan"],
        "Suède":              ["Sweden"],
        "Tunisie":            ["Tunisia"],
        "Belgique":           ["Belgium"],
        "Égypte":             ["Egypt"],
        "Iran":               ["Iran"],
        "Nouvelle-Zélande":   ["New Zealand"],
        "Espagne":            ["Spain"],
        "Cap-Vert":           ["Cape Verde", "Cabo Verde"],
        "Arabie Saoudite":    ["Saudi Arabia"],
        "Uruguay":            ["Uruguay"],
        "France":             ["France"],
        "Sénégal":            ["Senegal"],
        "Irak":               ["Iraq"],
        "Norvège":            ["Norway"],
        "Argentine":          ["Argentina"],
        "Algérie":            ["Algeria"],
        "Autriche":           ["Austria"],
        "Jordanie":           ["Jordan"],
        "Portugal":           ["Portugal"],
        "RD Congo":           ["DR Congo", "Congo DR", "Democratic Republic of Congo"],
        "Ouzbékistan":        ["Uzbekistan"],
        "Colombie":           ["Colombia"],
        "Angleterre":         ["England"],
        "Croatie":            ["Croatia"],
        "Ghana":              ["Ghana"],
        "Panama":             ["Panama"],
    ]

    /// Clears every score in the store.
    func clearAllScores() {
        for idx in matches.indices {
            matches[idx].homeScore = nil
            matches[idx].awayScore = nil
        }
        save()
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

// MARK: - ESPN Scoreboard models (private, Decodable)

private struct ESPNScoreboard: Decodable {
    let events: [ESPNEvent]
}

private struct ESPNEvent: Decodable {
    let competitions: [ESPNCompetition]
}

private struct ESPNCompetition: Decodable {
    let status: ESPNStatus
    let competitors: [ESPNCompetitor]
}

private struct ESPNStatus: Decodable {
    let type: ESPNStatusType
}

private struct ESPNStatusType: Decodable {
    let completed: Bool
}

private struct ESPNCompetitor: Decodable {
    let homeAway: String
    let score: String?
    let team: ESPNTeam
}

private struct ESPNTeam: Decodable {
    let displayName: String
}
