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
