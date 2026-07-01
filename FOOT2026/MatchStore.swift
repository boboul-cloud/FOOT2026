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

    var matches: [Match] = []

    /// Transient (non-persisted) live status of in-progress matches, keyed by match id.
    var liveStatuses: [UUID: LiveStatus] = [:]

    struct LiveStatus: Equatable {
        var clock: String   // e.g. "62'", "HT"
        var detail: String  // e.g. "1ère mi-temps"
    }

    init() {
        load()
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
                    m.homePenalties = saved.homePenalties
                    m.awayPenalties = saved.awayPenalties
                    m.homeScorers = saved.homeScorers
                    m.awayScorers = saved.awayScorers
                    m.matchLink = saved.matchLink
                    m.sofascoreLink = saved.sofascoreLink
                    m.lineup = saved.lineup
                    m.customBroadcasters = saved.customBroadcasters
                    // Apply the corrected kickoff time onto the canonical date so the
                    // whole app (sorting, display) follows the user's correction.
                    m.customDate = saved.customDate
                    if let corrected = saved.customDate { m.date = corrected }
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
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].homeScore = nil
        matches[idx].awayScore = nil
        matches[idx].homePenalties = nil
        matches[idx].awayPenalties = nil
        matches[idx].homeScorers = []
        matches[idx].awayScorers = []
        save()
    }

    /// Sets (or clears, with nil) the penalty-shootout score for a knockout match.
    func updatePenalties(matchID: UUID, home: Int?, away: Int?) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].homePenalties = home
        matches[idx].awayPenalties = away
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

    /// Sets the broadcaster list for a match. Pass `nil` to restore the default schedule.
    func updateBroadcasters(matchID: UUID, broadcasters: [String]?) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].customBroadcasters = broadcasters
        save()
    }

    /// Overrides the kickoff date/time for a match. Pass `nil` to restore the
    /// official calendar time. The corrected time is applied onto `date` so the
    /// whole app (sorting, display) follows it immediately.
    func updateDate(matchID: UUID, date: Date?) {
        guard let idx = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[idx].customDate = date
        matches[idx].date = date ?? matches[idx].defaultDate
        save()
    }

    // MARK: - Top scorers aggregation

    struct ScorerStat: Identifiable {
        let id = UUID()
        let name: String
        let team: String
        let flag: String
        let goals: Int          // total, penalty-shootout conversions included
        let shootoutGoals: Int  // of which scored in a penalty shootout (t.a.b.)
        let isOwnGoal: Bool
    }

    var topScorers: [ScorerStat] {
        // Own goals are keyed separately so a csc never merges with a real goal.
        var dict: [String: (team: String, flag: String, goals: Int, shootoutGoals: Int, isOwnGoal: Bool)] = [:]
        func add(_ s: GoalScorer) {
            let key = "\(s.name)|\(s.team)|\(s.isOwnGoal)"
            var entry = dict[key] ?? (s.team, s.flag, 0, 0, s.isOwnGoal)
            entry.goals += s.goals
            entry.shootoutGoals += s.shootoutGoals
            dict[key] = entry
        }
        for match in matches {
            for s in match.homeScorers { add(s) }
            for s in match.awayScorers { add(s) }
        }
        return dict
            .map { key, val in
                let name = String(key.split(separator: "|", maxSplits: 2)[0])
                return ScorerStat(name: name, team: val.team, flag: val.flag,
                                  goals: val.goals, shootoutGoals: val.shootoutGoals,
                                  isOwnGoal: val.isOwnGoal)
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

    /// Result of a live refresh: how many scores and lineups were updated.
    struct FetchResult {
        var scores: Int = 0
        var lineups: Int = 0
    }

    /// Fetch real match scores and lineups from ESPN's public API (no API key required).
    /// Returns the number of scores and lineups updated, or throws on network/parsing failure.
    @discardableResult
    func fetchLiveScores() async throws -> FetchResult {
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
        // Matches whose lineup should be fetched from ESPN this pass.
        var lineupTargets: [(matchID: UUID, eventID: String, reversed: Bool)] = []

        // Process chronologically so group results are applied before the knockout
        // fixtures that resolve from them (e.g. "V.M73") in this same pass.
        let sortedEvents = board.events.sorted { ($0.date ?? "") < ($1.date ?? "") }
        for event in sortedEvents {
            guard let comp = event.competitions.first else { continue }
            let state = comp.status.type.state   // "pre" | "in" | "post"
            let isCompleted = comp.status.type.completed == true
            let isLive = state == "in"

            let home = comp.competitors.first { $0.homeAway == "home" }
            let away = comp.competitors.first { $0.homeAway == "away" }
            guard let h = home, let a = away else { continue }

            // Match by *resolved* team names so knockout fixtures (whose stored
            // teams are placeholders like "V.M73" or "1er Gr.A") are found too.
            // ESPN's home/away orientation may differ from ours, so remember when
            // it is reversed to map scores and scorers correctly.
            var matchInfo: (idx: Int, reversed: Bool)? = nil
            for (i, m) in matches.enumerated() {
                let ourHome = resolveTeam(m.homeTeam).name
                let ourAway = resolveTeam(m.awayTeam).name
                if Self.espnMatches(french: ourHome, espn: h.team.displayName),
                   Self.espnMatches(french: ourAway, espn: a.team.displayName) {
                    matchInfo = (i, false); break
                }
                if Self.espnMatches(french: ourHome, espn: a.team.displayName),
                   Self.espnMatches(french: ourAway, espn: h.team.displayName) {
                    matchInfo = (i, true); break
                }
            }
            guard let (idx, reversed) = matchInfo else { continue }
            let id = matches[idx].id

            // Lineups are published ~1h before kickoff. Queue a one-time fetch when
            // we're within 90 min of kickoff (or the match is live/finished) and no
            // lineup is stored yet. The manual Sofascore import stays as a fallback
            // if ESPN hasn't released the starting XI.
            let nearKickoff = Date() >= matches[idx].date.addingTimeInterval(-90 * 60)
            if (matches[idx].lineup?.isEmpty ?? true), isLive || isCompleted || nearKickoff {
                lineupTargets.append((id, event.id, reversed))
            }

            // Scores only exist once the match is live or completed.
            guard isCompleted || isLive,
                  let espnHomeScore = Int(h.score ?? ""),
                  let espnAwayScore = Int(a.score ?? "") else { continue }

            // Re-orient ESPN's scores onto our home/away.
            let hScore = reversed ? espnAwayScore : espnHomeScore
            let aScore = reversed ? espnHomeScore : espnAwayScore

            // Record live status (never persisted).
            if isLive {
                newLive[id] = LiveStatus(
                    clock: comp.status.displayClock ?? "",
                    detail: comp.status.type.shortDetail ?? "En direct"
                )
            }

            // ESPN is the source of truth: always overwrite, even a score
            // that was entered by hand.
            if matches[idx].homeScore != hScore || matches[idx].awayScore != aScore {
                matches[idx].homeScore = hScore
                matches[idx].awayScore = aScore
                updatedCount += 1
                anyChange = true
            }

            // Penalty-shootout score (only present when a shootout decided the tie),
            // re-oriented onto our home/away so the next round resolves its winner.
            let hPens = reversed ? Int(a.shootoutScore ?? "") : Int(h.shootoutScore ?? "")
            let aPens = reversed ? Int(h.shootoutScore ?? "") : Int(a.shootoutScore ?? "")
            if matches[idx].homePenalties != hPens || matches[idx].awayPenalties != aPens {
                matches[idx].homePenalties = hPens
                matches[idx].awayPenalties = aPens
                anyChange = true
            }

            // Parse goal scorers from competition details (keyed by ESPN side).
            if let details = comp.details {
                // Collect scoring plays in order per ESPN side. Own goals (csc) stay
                // flagged so they can be labelled as such.
                typealias Play = (name: String, isOwnGoal: Bool, hint: Bool)
                var homePlays: [Play] = []
                var awayPlays: [Play] = []
                for detail in details {
                    guard detail.scoringPlay == true,
                          let athlete = detail.athletesInvolved?.first,
                          let teamRef = detail.team else { continue }
                    let name = athlete.displayName
                    let typeText = detail.type.text.lowercased()
                    let isOwnGoal = detail.ownGoal == true || typeText.contains("own goal")
                    let hint = typeText.contains("shootout") || typeText.contains("shoot-out")
                    if teamRef.id == h.team.id {
                        homePlays.append((name, isOwnGoal, hint))
                    } else if teamRef.id == a.team.id {
                        awayPlays.append((name, isOwnGoal, hint))
                    }
                }

                // Classify which plays were penalty-shootout kicks. ESPN's shootoutScore
                // is the authority for how many; the kicks are the trailing scoring
                // plays (they happen after regulation + extra time). The play type text
                // is used as a hint but ESPN doesn't always label it.
                func aggregate(_ plays: [Play], shootoutTotal: Int)
                    -> [String: (count: Int, shootout: Int, isOwnGoal: Bool)] {
                    var isShootout = plays.map(\.hint)
                    let hinted = isShootout.filter { $0 }.count
                    if shootoutTotal > 0 && hinted != shootoutTotal {
                        isShootout = Array(repeating: false, count: plays.count)
                        let start = max(0, plays.count - shootoutTotal)
                        for i in start..<plays.count { isShootout[i] = true }
                    }
                    var dict: [String: (count: Int, shootout: Int, isOwnGoal: Bool)] = [:]
                    for (i, p) in plays.enumerated() {
                        var e = dict[p.name] ?? (0, 0, p.isOwnGoal)
                        e.count += 1
                        if isShootout[i] { e.shootout += 1 }
                        dict[p.name] = e
                    }
                    return dict
                }

                let espnHomeGoals = aggregate(homePlays, shootoutTotal: Int(h.shootoutScore ?? "") ?? 0)
                let espnAwayGoals = aggregate(awayPlays, shootoutTotal: Int(a.shootoutScore ?? "") ?? 0)
                if !espnHomeGoals.isEmpty || !espnAwayGoals.isEmpty {
                    // Re-orient onto our home/away and resolve real team names/flags
                    // (placeholders for knockout fixtures).
                    let ourHome = resolveTeam(matches[idx].homeTeam)
                    let ourAway = resolveTeam(matches[idx].awayTeam)
                    let homeGoals = reversed ? espnAwayGoals : espnHomeGoals
                    let awayGoals = reversed ? espnHomeGoals : espnAwayGoals
                    let newHome = homeGoals.map { name, val in
                        GoalScorer(name: name, team: ourHome.name,
                                   flag: ourHome.flag, goals: val.count,
                                   isOwnGoal: val.isOwnGoal, shootoutGoals: val.shootout)
                    }
                    let newAway = awayGoals.map { name, val in
                        GoalScorer(name: name, team: ourAway.name,
                                   flag: ourAway.flag, goals: val.count,
                                   isOwnGoal: val.isOwnGoal, shootoutGoals: val.shootout)
                    }
                    if matches[idx].homeScorers != newHome || matches[idx].awayScorers != newAway {
                        matches[idx].homeScorers = newHome
                        matches[idx].awayScorers = newAway
                        anyChange = true
                    }

                    // Fallback when ESPN exposes no explicit shootoutScore: derive the
                    // shootout result from the converted kicks listed in the details.
                    if matches[idx].homePenalties == nil, matches[idx].awayPenalties == nil {
                        let homePens = newHome.reduce(0) { $0 + $1.shootoutGoals }
                        let awayPens = newAway.reduce(0) { $0 + $1.shootoutGoals }
                        if homePens > 0 || awayPens > 0 {
                            matches[idx].homePenalties = homePens
                            matches[idx].awayPenalties = awayPens
                            anyChange = true
                        }
                    }
                }
            }
        }

        liveStatuses = newLive

        // Fetch lineups for the queued matches (one summary request each).
        var lineupCount = 0
        for target in lineupTargets {
            guard let fetched = try? await Self.fetchESPNLineup(eventID: target.eventID),
                  !fetched.isEmpty,
                  let idx = matches.firstIndex(where: { $0.id == target.matchID }),
                  matches[idx].lineup?.isEmpty ?? true else { continue }
            // Swap sides if ESPN's home/away orientation is reversed vs ours.
            let lineup = target.reversed
                ? LineupData(homeStarting: fetched.awayStarting,
                             homeBench:    fetched.awayBench,
                             homeCoach:    fetched.awayCoach,
                             awayStarting: fetched.homeStarting,
                             awayBench:    fetched.homeBench,
                             awayCoach:    fetched.homeCoach)
                : fetched
            matches[idx].lineup = lineup
            lineupCount += 1
            anyChange = true
        }

        if anyChange { save() }
        return FetchResult(scores: updatedCount, lineups: lineupCount)
    }

    /// Fetches a single match's lineup (starting XI + bench) from ESPN's summary
    /// endpoint and maps it to `LineupData`. Coach is left empty (ESPN rarely
    /// exposes it); it can still be filled via manual edit.
    private static func fetchESPNLineup(eventID: String) async throws -> LineupData {
        guard let url = URL(string:
            "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/summary?event=\(eventID)"
        ) else { throw FetchError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FetchError.httpError }

        let summary = try JSONDecoder().decode(ESPNSummary.self, from: data)
        let rosters = summary.rosters ?? []
        let home = rosters.first { $0.homeAway == "home" } ?? rosters.first
        let away = rosters.first { $0.homeAway == "away" } ?? (rosters.count > 1 ? rosters[1] : nil)

        func players(_ team: ESPNRoster?, starter: Bool) -> [LineupPlayer] {
            (team?.roster ?? [])
                .filter { ($0.starter ?? false) == starter }
                .map {
                    LineupPlayer(
                        name: $0.athlete.displayName,
                        number: Int($0.jersey ?? ""),
                        position: $0.position?.abbreviation
                    )
                }
        }

        return LineupData(
            homeStarting: players(home, starter: true),
            homeBench:    players(home, starter: false),
            homeCoach:    "",
            awayStarting: players(away, starter: true),
            awayBench:    players(away, starter: false),
            awayCoach:    ""
        )
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
            matches[idx].homePenalties = nil
            matches[idx].awayPenalties = nil
            matches[idx].homeScorers = []
            matches[idx].awayScorers = []
        }
        liveStatuses.removeAll()
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
    let id: String
    let date: String?
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
    let shootoutScore: String?   // penalty-shootout total, present only after a shootout
    let team: ESPNTeam

    enum CodingKeys: String, CodingKey {
        case homeAway, score, shootoutScore, team
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        homeAway = try c.decode(String.self, forKey: .homeAway)
        team = try c.decode(ESPNTeam.self, forKey: .team)
        // ESPN sends score / shootoutScore sometimes as a string, sometimes as a
        // number. Decode either shape so a shootout result never breaks the parse.
        score = ESPNCompetitor.flexibleString(c, .score)
        shootoutScore = ESPNCompetitor.flexibleString(c, .shootoutScore)
    }

    private static func flexibleString(_ c: KeyedDecodingContainer<CodingKeys>,
                                       _ key: CodingKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
        return nil
    }
}

private struct ESPNTeam: Decodable {
    let id: String
    let displayName: String
}

private struct ESPNDetail: Decodable {
    let type: ESPNDetailType
    let scoringPlay: Bool?
    let ownGoal: Bool?
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

// MARK: - ESPN Summary models (lineups, private, Decodable)

private struct ESPNSummary: Decodable {
    let rosters: [ESPNRoster]?
}

private struct ESPNRoster: Decodable {
    let homeAway: String?
    let roster: [ESPNRosterPlayer]?
}

private struct ESPNRosterPlayer: Decodable {
    let starter: Bool?
    let jersey: String?
    let athlete: ESPNRosterAthlete
    let position: ESPNRosterPosition?
}

private struct ESPNRosterAthlete: Decodable {
    let displayName: String
    let shortName: String?
}

private struct ESPNRosterPosition: Decodable {
    let abbreviation: String?
}
