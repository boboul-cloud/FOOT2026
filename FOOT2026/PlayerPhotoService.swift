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
            let img = await Self.fetchFromWikipedia(name: name)
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

    private func store(_ image: UIImage?, forKey key: String) {
        if let image {
            memory[key] = image
        } else {
            failed.insert(key)
        }
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
