// BackupView.swift
// FOOT2026
// Export / import a full app backup (scores + player overrides)

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup envelope

private struct AppBackup: Codable {
    let version: Int
    let date: Date
    let matchesData: Data
    let playerOverridesData: Data
}

// MARK: - Transferable wrapper for ShareLink

private struct BackupDocument: FileDocument {
    static let backupType = UTType(filenameExtension: "f26backup", conformingTo: .data)!
    static var readableContentTypes: [UTType] { [backupType] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Main view

struct BackupView: View {
    @Environment(MatchStore.self) private var matchStore
    @Environment(PlayerStore.self) private var playerStore

    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var exportFilename = "FOOT2026.json"

    @State private var showImporter = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Predictions & Help
                Section {
                    NavigationLink {
                        PredictionsView()
                    } label: {
                        Label("Mes pronostics", systemImage: "target")
                    }
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Aide & règles", systemImage: "questionmark.circle")
                    }
                } footer: {
                    Text("Pronostiquez les scores depuis chaque match. L'aide explique les fonctions et la répartition de la phase finale.")
                }

                // MARK: Export
                Section {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Exporter la sauvegarde", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Sauvegarde")
                } footer: {
                    Text("Crée un fichier JSON contenant tous les scores, buteurs, compositions et modifications de joueurs.")
                }

                // MARK: Import
                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Importer une sauvegarde", systemImage: "square.and.arrow.down")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Restauration")
                } footer: {
                    Text("Remplace toutes les données actuelles par celles de la sauvegarde sélectionnée.")
                }

                // MARK: À propos & mentions légales
                Section {
                    externalLink("Site web", systemImage: "globe",
                                 path: "")
                    externalLink("À propos", systemImage: "info.circle",
                                 path: "about.html")
                    externalLink("Politique de confidentialité", systemImage: "hand.raised",
                                 path: "privacy.html")
                    externalLink("Conditions d'utilisation", systemImage: "doc.text",
                                 path: "terms.html")
                    externalLink("Support & contact", systemImage: "envelope",
                                 path: "support.html")
                } header: {
                    Text("À propos")
                } footer: {
                    Text("FOOT2026 v\(appVersion) — application indépendante et non officielle. Données fournies à titre informatif.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.large)

            // Export sheet
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: BackupDocument.backupType,
                defaultFilename: exportFilename
            ) { result in
                switch result {
                case .success:
                    showAlert(title: "Sauvegarde exportée", message: "Le fichier a été enregistré avec succès.")
                case .failure(let error):
                    showAlert(title: "Erreur", message: error.localizedDescription)
                }
            }

            // Import picker
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [BackupDocument.backupType, .json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }

            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Export

    private func prepareExport() {
        // Encode directly from in-memory state so all fields (links, lineups…)
        // are guaranteed to be present regardless of any UserDefaults version drift.
        guard let matchesData = try? JSONEncoder().encode(matchStore.matches) else { return }
        let playerData = UserDefaults.standard.data(forKey: "foot2026_player_overrides") ?? Data()

        let backup = AppBackup(
            version: 1,
            date: Date(),
            matchesData: matchesData,
            playerOverridesData: playerData
        )

        guard let encoded = try? JSONEncoder().encode(backup) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        exportFilename = "FOOT2026_\(formatter.string(from: Date())).f26backup"
        exportDocument = BackupDocument(data: encoded)
        showExporter = true
    }

    // MARK: - Import

    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                showAlert(title: "Erreur", message: "Accès refusé au fichier.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            let backup = try JSONDecoder().decode(AppBackup.self, from: data)

            guard backup.version == 1 else {
                showAlert(title: "Incompatible", message: "Ce fichier provient d'une version incompatible de l'application.")
                return
            }

            UserDefaults.standard.set(backup.matchesData, forKey: "foot2026_matches")
            UserDefaults.standard.set(backup.playerOverridesData, forKey: "foot2026_player_overrides")

            matchStore.reload()
            playerStore.reload()

            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "fr_FR")
            showAlert(title: "Restauration réussie", message: "Sauvegarde du \(formatter.string(from: backup.date)) chargée.")

        } catch {
            showAlert(title: "Erreur d'importation", message: error.localizedDescription)
        }
    }

    // MARK: - About / legal

    /// Base URL of the public website (GitHub Pages).
    private static let siteBaseURL = "https://boboul-cloud.github.io/FOOT2026/"

    /// App version + build, e.g. "1.0 (1)".
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Row opening a page of the public website in the browser.
    @ViewBuilder
    private func externalLink(_ title: String, systemImage: String, path: String) -> some View {
        if let url = URL(string: Self.siteBaseURL + path) {
            Link(destination: url) {
                HStack {
                    Label(title, systemImage: systemImage)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(.primary)
        }
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Preview

#Preview {
    BackupView()
        .environment(MatchStore())
        .environment(PlayerStore())
}
