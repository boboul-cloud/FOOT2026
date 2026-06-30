// Standings.swift
// FOOT2026
// Team standing model and MatchStore standings / bracket-resolution logic

import Foundation

// MARK: - TeamStanding

struct TeamStanding: Identifiable {
    var id: String { group.rawValue + "_" + team }
    let team: String
    let flag: String
    let group: Group
    var played: Int = 0
    var won: Int = 0
    var drawn: Int = 0
    var lost: Int = 0
    var goalsFor: Int = 0
    var goalsAgainst: Int = 0

    var points: Int { won * 3 + drawn }
    var goalDifference: Int { goalsFor - goalsAgainst }
}

// MARK: - MatchStore extension

extension MatchStore {

    // MARK: Group standings

    func standings(forGroup group: Group) -> [TeamStanding] {
        let groupMatches = matches.filter { $0.group == group && $0.stage == .groupStage }

        var stats: [String: TeamStanding] = [:]
        for m in groupMatches {
            if stats[m.homeTeam] == nil {
                stats[m.homeTeam] = TeamStanding(team: m.homeTeam, flag: m.homeFlag, group: group)
            }
            if stats[m.awayTeam] == nil {
                stats[m.awayTeam] = TeamStanding(team: m.awayTeam, flag: m.awayFlag, group: group)
            }
        }

        for m in groupMatches where m.hasScore {
            let h = m.homeScore!, a = m.awayScore!
            stats[m.homeTeam]?.played += 1
            stats[m.homeTeam]?.goalsFor += h
            stats[m.homeTeam]?.goalsAgainst += a
            stats[m.awayTeam]?.played += 1
            stats[m.awayTeam]?.goalsFor += a
            stats[m.awayTeam]?.goalsAgainst += h
            if h > a {
                stats[m.homeTeam]?.won += 1
                stats[m.awayTeam]?.lost += 1
            } else if a > h {
                stats[m.awayTeam]?.won += 1
                stats[m.homeTeam]?.lost += 1
            } else {
                stats[m.homeTeam]?.drawn += 1
                stats[m.awayTeam]?.drawn += 1
            }
        }

        return rankGroup(Array(stats.values), matches: groupMatches)
    }

    /// Overall comparison predicate (FIFA criteria 1–3): Points > DB > BM,
    /// then alphabetical as a stable fallback.
    /// Used directly for cross-group rankings (e.g. the best third-placed teams,
    /// who never meet in the group stage so head-to-head doesn't apply).
    func standingsOrder(_ a: TeamStanding, _ b: TeamStanding) -> Bool {
        if a.points != b.points { return a.points > b.points }
        if a.goalDifference != b.goalDifference { return a.goalDifference > b.goalDifference }
        if a.goalsFor != b.goalsFor { return a.goalsFor > b.goalsFor }
        return a.team < b.team
    }

    /// FIFA World Cup group ranking:
    ///   1. points (all matches)  2. goal difference (all)  3. goals scored (all)
    /// then, between teams still level, the head-to-head sub-table among them:
    ///   4. points  5. goal difference  6. goals scored (matches between them only)
    /// then alphabetical. (Fair-play and drawing of lots aren't tracked.)
    func rankGroup(_ teams: [TeamStanding], matches: [Match]) -> [TeamStanding] {
        let overall = teams.sorted(by: standingsOrder)
        var result: [TeamStanding] = []
        var i = 0
        while i < overall.count {
            var j = i + 1
            while j < overall.count && levelOnOverall(overall[i], overall[j]) { j += 1 }
            if j - i > 1 {
                result.append(contentsOf: breakTie(Array(overall[i..<j]), matches: matches))
            } else {
                result.append(overall[i])
            }
            i = j
        }
        return result
    }

    /// True when two teams are equal on the three overall criteria.
    private func levelOnOverall(_ a: TeamStanding, _ b: TeamStanding) -> Bool {
        a.points == b.points
            && a.goalDifference == b.goalDifference
            && a.goalsFor == b.goalsFor
    }

    /// Re-orders teams tied on the overall criteria using only the matches
    /// played between them (the FIFA head-to-head sub-table).
    private func breakTie(_ tied: [TeamStanding], matches: [Match]) -> [TeamStanding] {
        let names = Set(tied.map(\.team))
        var pts = [String: Int](), gd = [String: Int](), gf = [String: Int]()
        for t in tied { pts[t.team] = 0; gd[t.team] = 0; gf[t.team] = 0 }

        for m in matches where m.hasScore
            && names.contains(m.homeTeam) && names.contains(m.awayTeam) {
            let h = m.homeScore!, a = m.awayScore!
            gf[m.homeTeam, default: 0] += h; gd[m.homeTeam, default: 0] += h - a
            gf[m.awayTeam, default: 0] += a; gd[m.awayTeam, default: 0] += a - h
            if h > a { pts[m.homeTeam, default: 0] += 3 }
            else if a > h { pts[m.awayTeam, default: 0] += 3 }
            else { pts[m.homeTeam, default: 0] += 1; pts[m.awayTeam, default: 0] += 1 }
        }

        return tied.sorted { x, y in
            if pts[x.team] != pts[y.team] { return pts[x.team]! > pts[y.team]! }
            if gd[x.team]  != gd[y.team]  { return gd[x.team]!  > gd[y.team]!  }
            if gf[x.team]  != gf[y.team]  { return gf[x.team]!  > gf[y.team]!  }
            return x.team < y.team
        }
    }

    var allGroupStandings: [(group: Group, standings: [TeamStanding])] {
        Group.allCases.map { ($0, standings(forGroup: $0)) }
    }

    /// All 3rd-place finishers across 12 groups, sorted best-first.
    /// Top 8 qualify for the Round of 32.
    var allThirdPlaceFinishers: [TeamStanding] {
        Group.allCases.compactMap { g -> TeamStanding? in
            let s = standings(forGroup: g)
            return s.count >= 3 ? s[2] : nil
        }.sorted(by: standingsOrder)
    }

    // MARK: Bracket resolution

    /// Resolve a team placeholder (e.g. "1er Gr.A", "V.M73") to a display (name, flag).
    /// Returns (placeholder, "🏳️") if resolution is not yet possible.
    func resolveTeam(_ placeholder: String, depth: Int = 0) -> (name: String, flag: String) {
        guard depth < 6 else { return ("?", "🏳️") }

        // Already a real team name — just look up the flag
        guard isTeamPlaceholder(placeholder) else {
            return (placeholder, teamFlag(for: placeholder))
        }

        // ── "1er Gr.X" ──
        if placeholder.hasPrefix("1er Gr."),
           let g = Group(rawValue: String(placeholder.suffix(1))) {
            let s = standings(forGroup: g)
            return s.isEmpty ? ("Gr.\(g.rawValue) 1er", "🏳️") : (s[0].team, s[0].flag)
        }

        // ── "2e Gr.X" ──
        if placeholder.hasPrefix("2e Gr."),
           let g = Group(rawValue: String(placeholder.suffix(1))) {
            let s = standings(forGroup: g)
            return s.count < 2 ? ("Gr.\(g.rawValue) 2e", "🏳️") : (s[1].team, s[1].flag)
        }

        // ── "3e (A/B/C/...)" ──
        if placeholder.hasPrefix("3e (") {
            let inner = String(placeholder.dropFirst(4).dropLast(1))
            let top8 = Array(allThirdPlaceFinishers.prefix(8))
            guard top8.count == 8 else { return ("3e (\(inner))", "🏳️") }
            let key = top8.map(\.group.rawValue).sorted().joined()
            if let slotGroups = MatchStore.thirdPlaceTable[key],
               let assignedGroup = slotGroups[inner],
               let ts = top8.first(where: { $0.group.rawValue == assignedGroup }) {
                return (ts.team, ts.flag)
            }
            // Fallback: first qualifier among the slot's eligible groups
            let subGroups = Set(inner.split(separator: "/").map(String.init))
            let candidate = top8.first { subGroups.contains($0.group.rawValue) }
            return candidate.map { ($0.team, $0.flag) } ?? ("3e (\(inner))", "🏳️")
        }

        // ── "V.Mxx" (winner) / "P.Mxx" (loser) ──
        let isWinner = placeholder.hasPrefix("V.M")
        let isLoser  = placeholder.hasPrefix("P.M")
        if (isWinner || isLoser), let n = Int(placeholder.dropFirst(3)) {
            let uid = String(format: "00000000-0000-4000-8000-%012d", n).lowercased()
            if let m = matches.first(where: { $0.id.uuidString.lowercased() == uid }) {
                if m.hasScore {
                    // winnerSide breaks a draw after extra time using the shootout score.
                    if let side = m.winnerSide {
                        let winnerIsHome = side == .home
                        let pickHome = isWinner ? winnerIsHome : !winnerIsHome
                        return resolveTeam(pickHome ? m.homeTeam : m.awayTeam, depth: depth + 1)
                    }
                    return ("?", "🏳️") // draw without shootout info
                }
                // Match not played: show who will face off
                let (hn, _) = resolveTeam(m.homeTeam, depth: depth + 1)
                let (an, _) = resolveTeam(m.awayTeam, depth: depth + 1)
                return ("\(hn) / \(an)", "🏳️")
            }
        }

        return (placeholder, "🏳️")
    }

    /// Returns true when `s` is a bracket placeholder rather than a real team name.
    func isTeamPlaceholder(_ s: String) -> Bool {
        s.hasPrefix("1er") || s.hasPrefix("2e ") || s.hasPrefix("3e (")
            || s.hasPrefix("V.M") || s.hasPrefix("P.M")
    }

    // MARK: Helpers

    private func teamFlag(for name: String) -> String {
        for m in matches where m.stage == .groupStage {
            if m.homeTeam == name { return m.homeFlag }
            if m.awayTeam == name { return m.awayFlag }
        }
        return "🏳️"
    }
}
