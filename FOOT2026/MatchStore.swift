// MatchStore.swift
// FOOT2026
// Observable store — persists scores in UserDefaults

import SwiftUI

// FIFA World Ranking – June 11, 2026 (official)
let fifaRankings: [String: Int] = [
    "Argentine":           1,
    "Espagne":             2,
    "France":              3,
    "Angleterre":          4,
    "Portugal":            5,
    "Brésil":              6,
    "Maroc":               7,
    "Pays-Bas":            8,
    "Belgique":            9,
    "Allemagne":          10,
    "Croatie":            11,
    "Italie":             12,
    "Colombie":           13,
    "Sénégal":            14,
    "Mexique":            15,
    "Uruguay":            16,
    "États-Unis":         17,
    "Japon":              18,
    "Suisse":             19,
    "Iran":               20,
    "Danemark":           21,
    "Turquie":            22,
    "Équateur":           23,
    "Autriche":           24,
    "Corée du Sud":       25,
    "Norvège":            26,
    "Australie":          27,
    "Algérie":            28,
    "Égypte":             29,
    "Canada":             30,
    "Côte d'Ivoire":      32,
    "Tunisie":            33,
    "Suède":              35,
    "Écosse":             38,
    "Tchéquie":           40,
    "Qatar":              42,
    "Paraguay":           44,
    "Arabie Saoudite":    48,
    "Afrique du Sud":     52,
    "Irak":               56,
    "Ghana":              60,
    "Panama":             62,
    "RD Congo":           66,
    "Jordanie":           68,
    "Bosnie-Herzégovine": 72,
    "Cap-Vert":           78,
    "Ouzbékistan":        82,
    "Nouvelle-Zélande":   94,
    "Haïti":             100,
    "Curaçao":           110,
]

@MainActor
@Observable
final class MatchStore {

    private let saveKey = "foot2026_matches"
    private let espnFilledKey = "foot2026_espn_filled"

    var matches: [Match] = []

    /// Transient (non-persisted) live status of in-progress matches, keyed by match id.
    var liveStatuses: [UUID: LiveStatus] = [:]

    /// IDs of matches whose score was filled automatically from ESPN.
    /// Used so the live fetch never overwrites a score the user typed by hand.
    private var espnFilled: Set<UUID> = []

    struct LiveStatus: Equatable {
        var clock: String   // e.g. "62'", "HT"
        var detail: String  // e.g. "1ère mi-temps"
    }

    init() {
        load()
        loadEspnFilled()
    }

    // MARK: - Persistence

    func reload() { load() }

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
                    m.homeScorers = saved.homeScorers
                    m.awayScorers = saved.awayScorers
                    m.matchLink = saved.matchLink
                    m.sofascoreLink = saved.sofascoreLink
                    m.lineup = saved.lineup
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

    private func loadEspnFilled() {
        if let arr = UserDefaults.standard.array(forKey: espnFilledKey) as? [String] {
            espnFilled = Set(arr.compactMap(UUID.init))
        }
    }

    private func saveEspnFilled() {
        UserDefaults.standard.set(espnFilled.map(\.uuidString), forKey: espnFilledKey)
    }

    func updateScore(matchID: UUID, home: Int?, away: Int?) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].homeScore = home
        matches[idx].awayScore = away
        // A hand-entered score is no longer "owned" by ESPN, so protect it from
        // being overwritten on the next live fetch.
        espnFilled.remove(matchID)
        saveEspnFilled()
        save()
    }

    func clearScore(matchID: UUID) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].homeScore = nil
        matches[idx].awayScore = nil
        matches[idx].homeScorers = []
        matches[idx].awayScorers = []
        espnFilled.remove(matchID)
        saveEspnFilled()
        save()
    }

    func updateScorers(matchID: UUID, homeScorers: [GoalScorer], awayScorers: [GoalScorer]) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].homeScorers = homeScorers
        matches[idx].awayScorers = awayScorers
        save()
    }

    func updateMatchLink(matchID: UUID, link: String?) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        let trimmed = link?.trimmingCharacters(in: .whitespacesAndNewlines)
        matches[idx].matchLink = (trimmed?.isEmpty == false) ? trimmed : nil
        save()
    }

    func updateSofascoreLink(matchID: UUID, link: String?) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        let trimmed = link?.trimmingCharacters(in: .whitespacesAndNewlines)
        matches[idx].sofascoreLink = (trimmed?.isEmpty == false) ? trimmed : nil
        save()
    }

    func updateLineup(_ lineup: LineupData, matchID: UUID) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].lineup = lineup
        save()
    }

    // MARK: - Top scorers aggregation

    struct ScorerStat: Identifiable {
        let id = UUID()
        let name: String
        let team: String
        let flag: String
        let goals: Int
    }

    var topScorers: [ScorerStat] {
        var dict: [String: (team: String, flag: String, goals: Int)] = [:]
        for match in matches {
            for s in match.homeScorers {
                let key = "\(s.name)|\(s.team)"
                dict[key, default: (s.team, s.flag, 0)].goals += s.goals
            }
            for s in match.awayScorers {
                let key = "\(s.name)|\(s.team)"
                dict[key, default: (s.team, s.flag, 0)].goals += s.goals
            }
        }
        return dict
            .map { key, val in
                let parts = key.split(separator: "|", maxSplits: 1)
                let name = String(parts[0])
                return ScorerStat(name: name, team: val.team, flag: val.flag, goals: val.goals)
            }
            .filter { $0.goals > 0 }
            .sorted { $0.goals > $1.goals }
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

        var anyChange = false
        var newLive: [UUID: LiveStatus] = [:]

        for event in board.events {
            guard let comp = event.competitions.first else { continue }
            let state = comp.status.type.state   // "pre" | "in" | "post"
            let isCompleted = comp.status.type.completed == true
            let isLive = state == "in"
            guard isCompleted || isLive else { continue }

            let home = comp.competitors.first { $0.homeAway == "home" }
            let away = comp.competitors.first { $0.homeAway == "away" }

            guard let h = home, let a = away,
                  let hScore = Int(h.score ?? ""),
                  let aScore = Int(a.score ?? "") else { continue }

            if let idx = matches.firstIndex(where: {
                Self.espnMatches(french: $0.homeTeam, espn: h.team.displayName) &&
                Self.espnMatches(french: $0.awayTeam, espn: a.team.displayName)
            }) {
                let id = matches[idx].id

                // Record live status (never persisted).
                if isLive {
                    newLive[id] = LiveStatus(
                        clock: comp.status.displayClock ?? "",
                        detail: comp.status.type.shortDetail ?? "En direct"
                    )
                }

                // Protect a hand-entered score: only fill matches that are still
                // empty or that ESPN itself filled previously.
                let isManual = matches[idx].hasScore && !espnFilled.contains(id)
                guard !isManual else { continue }

                if matches[idx].homeScore != hScore || matches[idx].awayScore != aScore {
                    matches[idx].homeScore = hScore
                    matches[idx].awayScore = aScore
                    espnFilled.insert(id)
                    updatedCount += 1
                    anyChange = true
                }

                // Parse goal scorers from competition details
                if let details = comp.details {
                    var homeGoals: [String: Int] = [:]
                    var awayGoals: [String: Int] = [:]
                    for detail in details {
                        guard detail.scoringPlay == true,
                              let athlete = detail.athletesInvolved?.first,
                              let teamRef = detail.team else { continue }
                        let name = athlete.displayName
                        if teamRef.id == h.team.id {
                            homeGoals[name, default: 0] += 1
                        } else if teamRef.id == a.team.id {
                            awayGoals[name, default: 0] += 1
                        }
                    }
                    if !homeGoals.isEmpty || !awayGoals.isEmpty {
                        let newHome = homeGoals.map { name, count in
                            GoalScorer(name: name, team: matches[idx].homeTeam,
                                       flag: matches[idx].homeFlag, goals: count)
                        }
                        let newAway = awayGoals.map { name, count in
                            GoalScorer(name: name, team: matches[idx].awayTeam,
                                       flag: matches[idx].awayFlag, goals: count)
                        }
                        if matches[idx].homeScorers != newHome || matches[idx].awayScorers != newAway {
                            matches[idx].homeScorers = newHome
                            matches[idx].awayScorers = newAway
                            anyChange = true
                        }
                    }
                }
            }
        }

        liveStatuses = newLive
        if anyChange {
            saveEspnFilled()
            save()
        }
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
        "Bosnie-Herzégovine": ["Bosnia and Herzegovina", "Bosnia & Herzegovina", "Bosnia-Herzegovina"],
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

    /// Clears every score and scorer list in the store.
    func clearAllScores() {
        for idx in matches.indices {
            matches[idx].homeScore = nil
            matches[idx].awayScore = nil
            matches[idx].homeScorers = []
            matches[idx].awayScorers = []
        }
        espnFilled.removeAll()
        liveStatuses.removeAll()
        saveEspnFilled()
        save()
    }

    // MARK: - Today / live helpers

    /// Matches kicking off today (Europe/Paris), sorted chronologically.
    var todayMatches: [Match] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        let today = cal.startOfDay(for: Date())
        return matches
            .filter { cal.isDate($0.date, inSameDayAs: today) }
            .sorted { $0.date < $1.date }
    }

    func isLive(_ match: Match) -> Bool { liveStatuses[match.id] != nil }

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
    let details: [ESPNDetail]?
}

private struct ESPNStatus: Decodable {
    let type: ESPNStatusType
    let displayClock: String?
}

private struct ESPNStatusType: Decodable {
    let completed: Bool
    let state: String?
    let shortDetail: String?
}

private struct ESPNCompetitor: Decodable {
    let homeAway: String
    let score: String?
    let team: ESPNTeam
}

private struct ESPNTeam: Decodable {
    let id: String
    let displayName: String
}

private struct ESPNDetail: Decodable {
    let type: ESPNDetailType
    let scoringPlay: Bool?
    let athletesInvolved: [ESPNAthlete]?
    let team: ESPNTeamRef?
}

private struct ESPNDetailType: Decodable {
    let text: String
}

private struct ESPNAthlete: Decodable {
    let displayName: String
}

private struct ESPNTeamRef: Decodable {
    let id: String
}
