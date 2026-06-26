// PlayerStore.swift
// FOOT2026
// Observable store — persists player photo and number overrides

import SwiftUI

@MainActor
@Observable
final class PlayerStore {

    private let saveKey = "foot2026_player_overrides"

    private struct Override: Codable {
        var photoData: Data?
        var number: Int?
        var name: String?
        var position: Position?
    }

    private var overrides: [String: Override] = [:]

    init() { load() }

    // MARK: - Stable key (name + team — UUID changes every launch)

    private func key(for player: Player) -> String {
        "\(player.team)|\(player.name)"
    }

    // MARK: - Accessors

    func photo(for player: Player) -> UIImage? {
        guard let data = overrides[key(for: player)]?.photoData else { return nil }
        return UIImage(data: data)
    }

    func number(for player: Player) -> Int {
        overrides[key(for: player)]?.number ?? player.number
    }

    func name(for player: Player) -> String {
        overrides[key(for: player)]?.name ?? player.name
    }

    func position(for player: Player) -> Position {
        overrides[key(for: player)]?.position ?? player.position
    }

    // MARK: - Mutations

    func setPhoto(_ image: UIImage?, for player: Player) {
        let k = key(for: player)
        if let image {
            overrides[k, default: Override()].photoData = image.jpegData(compressionQuality: 0.8)
        } else {
            overrides[k]?.photoData = nil
            if overrides[k]?.number == nil && overrides[k]?.name == nil {
                overrides.removeValue(forKey: k)
            }
        }
        save()
    }

    func setNumber(_ number: Int, for player: Player) {
        overrides[key(for: player), default: Override()].number = number
        save()
    }

    func setName(_ name: String, for player: Player) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        overrides[key(for: player), default: Override()].name = trimmed
        save()
    }

    func setPosition(_ position: Position, for player: Player) {
        overrides[key(for: player), default: Override()].position = position
        save()
    }

    // MARK: - Reconcile from imported compositions

    /// Re-derives each player's number and position from the imported match
    /// lineups (Sofascore/ESPN), which are the authoritative source. Manual
    /// photo and name overrides are preserved. Idempotent: only writes when a
    /// value actually changes, so it is safe to call on every appearance.
    /// - Returns: the number of players whose number was updated.
    @discardableResult
    func reconcile(from matches: [Match]) -> Int {
        var changed = 0
        for match in matches {
            guard let lineup = match.lineup, !lineup.isEmpty else { continue }
            changed += apply(lineup.homeStarting + lineup.homeBench, team: match.homeTeam)
            changed += apply(lineup.awayStarting + lineup.awayBench, team: match.awayTeam)
        }
        if changed > 0 { save() }
        return changed
    }

    private func apply(_ lineupPlayers: [LineupPlayer], team: String) -> Int {
        guard let squad = Player.allSquads[team] else { return 0 }
        var changed = 0
        for lp in lineupPlayers {
            guard let player = Self.match(lp.name, in: squad) else { continue }
            let k = key(for: player)
            if let importedNumber = lp.number, importedNumber > 0,
               number(for: player) != importedNumber {
                overrides[k, default: Override()].number = importedNumber
                changed += 1
            }
            if let pos = Self.parsePosition(lp.position), position(for: player) != pos {
                overrides[k, default: Override()].position = pos
            }
        }
        return changed
    }

    /// Maps a Sofascore/ESPN position abbreviation (e.g. "GK", "CB", "AM", "ST")
    /// to the app's coarse `Position`. Returns nil when unrecognised so the
    /// existing position is left untouched.
    private static func parsePosition(_ raw: String?) -> Position? {
        guard let raw = raw?.uppercased().trimmingCharacters(in: .whitespaces), !raw.isEmpty
        else { return nil }
        let keepers: Set<String>  = ["G", "GK", "GKP", "K"]
        let defs: Set<String>     = ["D", "DF", "CB", "LB", "RB", "LWB", "RWB", "WB", "SW", "RCB", "LCB"]
        let mids: Set<String>     = ["M", "MF", "MID", "CM", "DM", "AM", "LM", "RM", "CDM", "CAM", "DMF", "AMF"]
        let forwards: Set<String> = ["F", "FW", "ST", "CF", "SS", "LW", "RW", "LF", "RF"]
        if keepers.contains(raw)  { return .goalkeeper }
        if defs.contains(raw)     { return .defender }
        if mids.contains(raw)     { return .midfielder }
        if forwards.contains(raw) { return .forward }
        switch raw.first {
        case "G": return .goalkeeper
        case "D": return .defender
        case "M": return .midfielder
        case "F": return .forward
        default:  return nil
        }
    }

    /// Conservatively matches an imported lineup name to a squad player.
    /// Tries, in order: exact (accent-insensitive) full name, unique surname,
    /// then surname + first-initial. Returns nil when ambiguous to avoid
    /// assigning a number to the wrong player.
    private static func match(_ importedName: String, in squad: [Player]) -> Player? {
        let target = normalize(importedName)
        guard !target.isEmpty else { return nil }
        if let p = squad.first(where: { normalize($0.name) == target }) { return p }

        let targetTokens = target.split(separator: " ").map(String.init)
        guard let surname = targetTokens.last else { return nil }

        func surnameOf(_ player: Player) -> String {
            normalize(player.name).split(separator: " ").last.map(String.init) ?? ""
        }
        let bySurname = squad.filter { surnameOf($0) == surname }
        if bySurname.count == 1 { return bySurname.first }
        if bySurname.count > 1, let initial = targetTokens.first?.first {
            let byInitial = bySurname.filter {
                normalize($0.name).first == initial
            }
            if byInitial.count == 1 { return byInitial.first }
        }
        return nil
    }

    /// Lowercased, accent-folded, punctuation-stripped name for matching.
    private static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Persistence

    func reload() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([String: Override].self, from: data)
        else { return }
        overrides = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }
}
