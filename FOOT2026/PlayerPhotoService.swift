// PlayerPhotoService.swift
// FOOT2026
// Automatic player portraits fetched on demand from Wikipedia, cached to disk.
//
// Manual photos (pasted by the user) live in PlayerStore / UserDefaults and take
// priority. This service only fills the *missing* ones, and never bloats
// UserDefaults: images are written to the Caches directory and can be purged by
// the system at any time without data loss.

import SwiftUI

actor PlayerPhotoService {
    static let shared = PlayerPhotoService()

    private let cacheDir: URL
    private var memory: [String: UIImage] = [:]
    /// Keys we already tried and failed this session — avoids hammering the network.
    private var failed: Set<String> = []
    /// In-flight tasks, so concurrent requests for the same player coalesce.
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("PlayerPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// Stable, filesystem-safe filename for a player (team + name), independent of UUID.
    private func fileName(for key: String) -> String {
        // FNV-1a 64-bit — deterministic across launches.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16) + ".jpg"
    }

    /// Returns a cached or freshly-downloaded portrait, or nil if none could be found.
    func image(forTeam team: String, name: String) async -> UIImage? {
        let key = "\(team)|\(name)"

        if let img = memory[key] { return img }

        let file = cacheDir.appendingPathComponent(fileName(for: key))
        if let data = try? Data(contentsOf: file), let img = UIImage(data: data) {
            memory[key] = img
            return img
        }

        if failed.contains(key) { return nil }

        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            let img = await Self.fetchPortrait(team: team, name: name)
            if let img, let data = img.jpegData(compressionQuality: 0.85) {
                try? data.write(to: file)
            }
            await self.store(img, forKey: key)
            return img
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    /// Forces a fresh download (Sofascore → Wikipedia), overwriting any cached
    /// image. Used by the per-team "download photos" button so old Wikipedia
    /// portraits get replaced by the better Sofascore ones.
    func refresh(forTeam team: String, name: String) async -> UIImage? {
        let key = "\(team)|\(name)"
        let file = cacheDir.appendingPathComponent(fileName(for: key))

        // Drop every cached trace for this player.
        memory[key] = nil
        failed.remove(key)

        let img = await Self.fetchPortrait(team: team, name: name)
        if let img, let data = img.jpegData(compressionQuality: 0.85) {
            try? data.write(to: file)            // overwrite stale image
        } else {
            try? FileManager.default.removeItem(at: file)
        }
        store(img, forKey: key)
        return img
    }

    private func store(_ image: UIImage?, forKey key: String) {
        if let image {
            memory[key] = image
        } else {
            failed.insert(key)
        }
    }

    // MARK: - Portrait lookup (Sofascore first, Wikipedia fallback)

    /// Tries Sofascore (football-specific, matches the user's manual source),
    /// then falls back to Wikipedia.
    private static func fetchPortrait(team: String, name: String) async -> UIImage? {
        if let img = await fetchFromSofascore(team: team, name: name) { return img }
        return await fetchFromWikipedia(name: name)
    }

    // MARK: - Sofascore lookup

    /// Adds the browser-like headers Sofascore expects (same as lineup import).
    private static func sofascoreHeaders(_ request: inout URLRequest) {
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.sofascore.com", forHTTPHeaderField: "Referer")
    }

    /// Finds the player on Sofascore (preferring the right nationality) and
    /// returns their official headshot.
    private static func fetchFromSofascore(team: String, name: String) async -> UIImage? {
        guard let id = await sofascorePlayerID(name: name, alpha2: alpha2(forTeam: team)) else {
            return nil
        }
        guard let url = URL(string: "https://api.sofascore.com/api/v1/player/\(id)/image") else {
            return nil
        }
        var request = URLRequest(url: url)
        sofascoreHeaders(&request)
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              data.count > 800,                 // skip empty / placeholder blobs
              let img = UIImage(data: data) else { return nil }
        return img
    }

    /// Searches Sofascore for a player by name. Among the player results, prefers
    /// one whose nationality matches `alpha2`; otherwise takes the best match.
    private static func sofascorePlayerID(name: String, alpha2: String?) async -> Int? {
        var comps = URLComponents(string: "https://api.sofascore.com/api/v1/search/all")
        comps?.queryItems = [.init(name: "q", value: name)]
        guard let url = comps?.url else { return nil }
        var request = URLRequest(url: url)
        sofascoreHeaders(&request)
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(SofaSearch.self, from: data) else { return nil }

        let players = (decoded.results ?? [])
            .filter { $0.type == "player" }
            .compactMap(\.entity)
        if let alpha2,
           let match = players.first(where: { $0.country?.alpha2?.uppercased() == alpha2 }) {
            return match.id
        }
        return players.first?.id
    }

    /// ISO alpha-2 code derived from the team's flag emoji (two regional
    /// indicator symbols → "FR", "BR", …). Returns nil for non-standard flags
    /// (e.g. England's subdivision flag), in which case nationality isn't filtered.
    private static func alpha2(forTeam team: String) -> String? {
        guard let flag = teamFlags[team] else { return nil }
        let scalars = flag.unicodeScalars.filter { (0x1F1E6...0x1F1FF).contains($0.value) }
        guard scalars.count == 2 else { return nil }
        let letters = scalars.map { Character(UnicodeScalar($0.value - 0x1F1E6 + 0x41)!) }
        return String(letters)
    }

    // MARK: - Wikipedia lookup

    /// Searches Wikipedia for the player and returns the page's lead thumbnail.
    /// Tries the French Wikipedia first, then falls back to English.
    private static func fetchFromWikipedia(name: String) async -> UIImage? {
        for lang in ["fr", "en"] {
            if let img = await thumbnail(name: name, lang: lang) { return img }
        }
        return nil
    }

    private static func thumbnail(name: String, lang: String) async -> UIImage? {
        var comps = URLComponents(string: "https://\(lang).wikipedia.org/w/api.php")!
        comps.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "format", value: "json"),
            .init(name: "generator", value: "search"),
            .init(name: "gsrsearch", value: "\(name) football"),
            .init(name: "gsrlimit", value: "1"),
            .init(name: "prop", value: "pageimages"),
            .init(name: "piprop", value: "thumbnail"),
            .init(name: "pithumbsize", value: "240"),
            .init(name: "redirects", value: "1"),
        ]
        guard let url = comps.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("FOOT2026/1.0 (personal app)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            let decoded = try JSONDecoder().decode(WikiResponse.self, from: data)
            guard let pages = decoded.query?.pages else { return nil }
            // Pick the lowest "index" (best search match) that has a thumbnail.
            let best = pages.values
                .filter { $0.thumbnail != nil }
                .sorted { ($0.index ?? .max) < ($1.index ?? .max) }
                .first
            guard let src = best?.thumbnail?.source,
                  let imgURL = URL(string: src) else { return nil }

            let (imgData, imgResp) = try await URLSession.shared.data(from: imgURL)
            guard (imgResp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return UIImage(data: imgData)
        } catch {
            return nil
        }
    }

    // MARK: - Wikipedia response models

    private struct WikiResponse: Decodable {
        let query: WikiQuery?
    }
    private struct WikiQuery: Decodable {
        let pages: [String: WikiPage]?
    }
    private struct WikiPage: Decodable {
        let index: Int?
        let thumbnail: WikiThumb?
    }
    private struct WikiThumb: Decodable {
        let source: String
    }

    // MARK: - Sofascore search response models

    private struct SofaSearch: Decodable {
        let results: [Result]?
        struct Result: Decodable {
            let type: String?
            let entity: Entity?
        }
        struct Entity: Decodable {
            let id: Int?
            let country: Country?
        }
        struct Country: Decodable {
            let alpha2: String?
        }
    }
}

// MARK: - SwiftUI view

/// Shows the player's manual photo if any, otherwise auto-loads one from Wikipedia,
/// falling back to coloured initials while loading / if nothing is found.
struct RemotePlayerPhoto<Placeholder: View>: View {
    let player: Player
    let size: CGFloat
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        // Note: `Group` is qualified because the app defines its own `enum Group`
        // (World Cup groups A–L), which would otherwise shadow SwiftUI.Group.
        SwiftUI.Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: player.id) {
            guard image == nil else { return }
            image = await PlayerPhotoService.shared.image(forTeam: player.team, name: player.name)
        }
    }
}
