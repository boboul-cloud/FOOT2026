// StandingsView.swift
// FOOT2026
// Group standings tables + best 3rd-place finishers

import SwiftUI

// MARK: - Root view

struct StandingsView: View {
    @Environment(MatchStore.self) private var store
    var initialGroup: Group = .A
    @State private var selectedGroup: Group = .A

    init(initialGroup: Group = .A) {
        self.initialGroup = initialGroup
        self._selectedGroup = State(initialValue: initialGroup)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                groupPicker
                ScrollView {
                    VStack(spacing: 20) {
                        groupTable(for: selectedGroup)
                        bestThirdsCard
                        qualificationLegend
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Classement")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Group picker

    private var groupPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Group.allCases, id: \.self) { group in
                    Button {
                        withAnimation(.spring(duration: 0.2)) { selectedGroup = group }
                    } label: {
                        Text("Grp \(group.rawValue)")
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedGroup == group ? Color.accentColor : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedGroup == group ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Group standings table

    private func groupTable(for group: Group) -> some View {
        let rows = store.standings(forGroup: group)
        let groupMatches = store.matches.filter { $0.group == group && $0.stage == .groupStage }
        let playedCount = groupMatches.filter(\.hasScore).count

        return VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Groupe \(group.rawValue)")
                    .font(.headline.bold())
                Spacer()
                Text("\(playedCount) / 6 matchs joués")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Column header
            columnHeader

            // Team rows
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                standingRow(row, position: idx + 1)
                if idx < rows.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 24, alignment: .center)
            Text("Équipe")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
            Text("J").frame(width: 22, alignment: .center)
            Text("G").frame(width: 22, alignment: .center)
            Text("N").frame(width: 22, alignment: .center)
            Text("P").frame(width: 22, alignment: .center)
            Text("BM").frame(width: 26, alignment: .center)
            Text("BC").frame(width: 26, alignment: .center)
            Text("DB").frame(width: 30, alignment: .center)
            Text("Pts").frame(width: 30, alignment: .center)
        }
        .font(.caption2.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemGroupedBackground))
    }

    private func standingRow(_ s: TeamStanding, position: Int) -> some View {
        HStack(spacing: 0) {
            // Position badge
            positionBadge(position)
                .frame(width: 24)

            // Flag + name + FIFA rank
            HStack(spacing: 5) {
                Text(s.flag).font(.body)
                Text(s.team)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let rank = fifaRankings[s.team] {
                    Text("\(rank)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)

            // Stats
            narrowCell("\(s.played)")
            narrowCell("\(s.won)")
            narrowCell("\(s.drawn)")
            narrowCell("\(s.lost)")
            narrowCell("\(s.goalsFor)")
            narrowCell("\(s.goalsAgainst)")
            diffCell(s.goalDifference)
            Text("\(s.points)")
                .font(.subheadline.bold())
                .monospacedDigit()
                .frame(width: 30, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(rowBackground(position))
    }

    @ViewBuilder
    private func positionBadge(_ pos: Int) -> some View {
        ZStack {
            Circle()
                .fill(badgeColor(pos))
                .frame(width: 22, height: 22)
            Text("\(pos)")
                .font(.caption2.bold())
                .foregroundStyle(pos <= 3 ? .white : Color(.label))
        }
    }

    private func badgeColor(_ pos: Int) -> Color {
        switch pos {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        default: return Color(.systemGray4)
        }
    }

    private func rowBackground(_ pos: Int) -> Color {
        switch pos {
        case 1, 2: return Color.green.opacity(0.06)
        case 3:    return Color.orange.opacity(0.06)
        default:   return Color.clear
        }
    }

    private func statCell(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .monospacedDigit()
            .frame(width: 26, alignment: .center)
    }

    private func narrowCell(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .monospacedDigit()
            .frame(width: 22, alignment: .center)
    }

    private func diffCell(_ gd: Int) -> some View {
        Text(gd > 0 ? "+\(gd)" : "\(gd)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(gd > 0 ? Color.green : gd < 0 ? Color.red : Color.primary)
            .frame(width: 30, alignment: .center)
    }

    // MARK: - Best 3rd-place finishers

    private var bestThirdsCard: some View {
        let thirds = store.allThirdPlaceFinishers

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Meilleurs 3es", systemImage: "medal.fill")
                    .font(.headline.bold())
                Spacer()
                Text("Top 8 qualifiés")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Column header
            HStack(spacing: 0) {
                Text("#").frame(width: 28, alignment: .center)
                Text("Équipe")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                Text("Gr").frame(width: 28, alignment: .center)
                Text("J").frame(width: 26, alignment: .center)
                Text("DB").frame(width: 34, alignment: .center)
                Text("Pts").frame(width: 34, alignment: .center)
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))

            if thirds.isEmpty {
                Text("Aucun résultat de groupe disponible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                ForEach(Array(thirds.enumerated()), id: \.element.id) { idx, s in
                    let qualifies = idx < 8
                    HStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(qualifies ? Color.orange : Color(.systemGray4))
                                .frame(width: 22, height: 22)
                            Text("\(idx + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(qualifies ? .white : Color(.label))
                        }
                        .frame(width: 28)

                        HStack(spacing: 7) {
                            Text(s.flag).font(.body)
                            Text(s.team).font(.caption.bold()).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)

                        Text(s.group.rawValue)
                            .font(.caption.bold())
                            .frame(width: 28, alignment: .center)

                        narrowCell("\(s.played)")
                        diffCell(s.goalDifference)

                        Text("\(s.points)")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .frame(width: 34, alignment: .center)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(qualifies ? Color.orange.opacity(0.06) : Color.clear)

                    if idx == 7 {
                        Divider()
                            .overlay(Color.orange.opacity(0.5))
                            .padding(.horizontal, 14)
                    } else if idx < thirds.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Legend

    private var qualificationLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            legendRow(color: .green, text: "1er / 2e — Qualifié directement pour les 1/32 de finale")
            legendRow(color: .orange, text: "3e — Top 8 des 3es qualifié pour les 1/32 de finale")
            legendRow(color: Color(.systemGray4), text: "4e — Éliminé")
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}
