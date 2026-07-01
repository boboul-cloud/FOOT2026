// HelpView.swift
// FOOT2026
// In-app help: explains each tab and the knockout-phase distribution rules.

import SwiftUI

struct HelpView: View {
    @State private var deepDiveExpanded = false

    var body: some View {
        List {
            introSection
            tabsSection
            knockoutSection
            thirdPlaceSection
            deepDiveSection
            tiebreakSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Aide")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Intro

    private var introSection: some View {
        Section {
            Text("Suivez le tournoi de football 2026 : 48 équipes, 12 groupes de 4, puis une phase finale à élimination directe de 32 équipes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tabs

    private var tabsSection: some View {
        Section("Les onglets de l'application") {
            helpRow(
                icon: "list.bullet", color: .blue,
                title: "Matchs",
                detail: "La liste de tous les matchs, par date. Touchez un match pour saisir le score et les buteurs. Les scores des rencontres terminées peuvent être récupérés automatiquement depuis ESPN, et les compositions importées depuis Sofascore."
            )
            helpRow(
                icon: "chart.bar.fill", color: .green,
                title: "Classement",
                detail: "Le classement en direct des 12 groupes, mis à jour à chaque score saisi. Affiche aussi le classement des meilleurs troisièmes, qui décide des 8 derniers qualifiés."
            )
            helpRow(
                icon: "soccerball", color: .primary,
                title: "Buteurs",
                detail: "Le classement des buteurs du tournoi, construit à partir des buteurs saisis sur chaque match."
            )
            helpRow(
                icon: "trophy.fill", color: .yellow,
                title: "Tableau",
                detail: "La phase finale, des 16es de finale (1/32) à la finale. Les équipes se remplissent automatiquement dès que les résultats le permettent. La barre en haut indique le nombre d'équipes encore en lice par confédération."
            )
            helpRow(
                icon: "person.2.fill", color: .indigo,
                title: "Joueurs",
                detail: "Les effectifs de chaque équipe. Les photos sont chargées automatiquement depuis Wikipédia ; vous pouvez coller votre propre photo et modifier le nom, le numéro et le poste d'un joueur."
            )
            helpRow(
                icon: "gearshape.fill", color: .gray,
                title: "Réglages",
                detail: "Exportez une sauvegarde complète (scores, buteurs, compositions, modifications) dans un fichier, ou restaurez-la sur un autre appareil."
            )
        }
    }

    // MARK: - Knockout distribution

    private var knockoutSection: some View {
        Section {
            Text("À l'issue des matchs de groupes, **32 équipes** se qualifient pour la phase à élimination directe :")
                .font(.subheadline)
            bullet("Les 12 premiers de chaque groupe (1ers).")
            bullet("Les 12 deuxièmes de chaque groupe (2es).")
            bullet("Les 8 meilleurs troisièmes parmi les 12 groupes.")
            Text("Soit 12 + 12 + 8 = 32 équipes pour les 16es de finale.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Label("Répartition de la phase finale", systemImage: "trophy.fill")
        }
    }

    private var thirdPlaceSection: some View {
        Section {
            Text("Les 12 troisièmes sont d'abord classés entre eux (mêmes critères que les groupes). Seuls les **8 meilleurs** sont retenus.")
                .font(.subheadline)
            Text("Leur place dans le tableau dépend ensuite des groupes d'où ils sortent : une table officielle détermine, selon la combinaison des 8 groupes qualifiés, à quel 16e de finale chaque troisième est affecté. L'application applique cette table automatiquement.")
                .font(.subheadline)
            Text("Tant qu'un résultat manque, l'équipe apparaît sous forme d'emplacement (ex. « 1er Gr.A », « 3e (A/B/C/D/F) », ou « Vainqueur M73 ») et se résout dès que possible.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Label("Les meilleurs troisièmes", systemImage: "3.circle.fill")
        }
    }

    // MARK: - Deep dive (dispatch table)

    /// The 8 Round-of-32 matches that receive a third-placed team, each with the
    /// set of groups eligible to fill it (official dispatch table).
    private let thirdPlaceSlots: [(match: String, groups: String)] = [
        ("M74", "A / B / C / D / F"),
        ("M77", "C / D / F / G / H"),
        ("M79", "C / E / F / H / I"),
        ("M80", "E / H / I / J / K"),
        ("M81", "B / E / F / I / J"),
        ("M82", "A / E / H / I / J"),
        ("M85", "E / F / G / I / J"),
        ("M87", "D / E / I / J / L"),
    ]

    private var deepDiveSection: some View {
        Section {
            DisclosureGroup(isExpanded: $deepDiveExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Le tableau est figé dès le tirage (pour le calendrier et la billetterie), mais on ignore à l'avance lesquels des 12 troisièmes finiront dans le top 8. Une table officielle couvre donc les **495 combinaisons** possibles de groupes qualifiés et affecte, pour chacune, chaque troisième à un match précis.")
                        .font(.caption)

                    Text("Seuls 8 des 32 matchs accueillent un troisième. Chacun n'accepte un troisième que d'un sous-ensemble de groupes — ce qui évite qu'une équipe retombe contre le 1er ou le 2e de son propre groupe :")
                        .font(.caption)

                    VStack(spacing: 0) {
                        ForEach(Array(thirdPlaceSlots.enumerated()), id: \.offset) { index, slot in
                            HStack {
                                Text(slot.match)
                                    .font(.caption.bold().monospaced())
                                    .frame(width: 48, alignment: .leading)
                                Text(slot.groups)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                            if index < thirdPlaceSlots.count - 1 { Divider() }
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))

                    Text("Exemple — si les 8 meilleurs troisièmes viennent des groupes A à H, la table envoie le 3e de C en M74, celui de A en M82, de F en M77, de B en M81, de H en M79, de E en M80, de G en M85 et de D en M87. Chacun tombe bien dans un match où son groupe est éligible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } label: {
                Label("Pour aller plus loin : la table de répartition", systemImage: "table")
                    .font(.subheadline.bold())
            }
        } footer: {
            Text("Note : le départage des égalités dans l'application s'arrête à l'ordre alphabétique. Le règlement officiel utilise en plus les confrontations directes, le fair-play puis un tirage au sort.")
        }
    }

    // MARK: - Tie-break rules

    private var tiebreakSection: some View {
        Section {
            numbered(1, "Plus grand nombre de points (victoire = 3, nul = 1).")
            numbered(2, "Meilleure différence de buts.")
            numbered(3, "Plus grand nombre de buts marqués.")
            numbered(4, "Ordre alphabétique (départage final dans l'application).")
        } header: {
            Label("Comment sont départagées les équipes", systemImage: "arrow.up.arrow.down")
        } footer: {
            Text("Ces critères servent à classer les équipes d'un groupe ainsi que les 12 troisièmes entre eux.")
        }
    }

    // MARK: - Row builders

    @ViewBuilder
    private func helpRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func numbered(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack { HelpView() }
}
