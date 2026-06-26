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

        return stats.values.sorted(by: standingsOrder)
    }

    /// Comparison predicate: Points > DB > BM > alphabetical
    func standingsOrder(_ a: TeamStanding, _ b: TeamStanding) -> Bool {
        if a.points != b.points { return a.points > b.points }
        if a.goalDifference != b.goalDifference { return a.goalDifference > b.goalDifference }
        if a.goalsFor != b.goalsFor { return a.goalsFor > b.goalsFor }
        return a.team < b.team
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
                if let h = m.homeScore, let a = m.awayScore {
                    if isWinner {
                        if h > a { return resolveTeam(m.homeTeam, depth: depth + 1) }
                        if a > h { return resolveTeam(m.awayTeam, depth: depth + 1) }
                    } else {
                        if h < a { return resolveTeam(m.homeTeam, depth: depth + 1) }
                        if a < h { return resolveTeam(m.awayTeam, depth: depth + 1) }
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
