// MatchesView.swift
// FOOT2026
// Full fixture list grouped by stage, with score entry

import SwiftUI

// MARK: - Main list view

struct MatchesView: View {

    @Environment(MatchStore.self) private var store
    @State private var selectedStage: Stage? = .groupStage
    @State private var selectedGroup: Group? = nil
    @State private var matchToEdit: Match? = nil
    @State private var searchText = ""

    private var stages: [Stage] {
        store.matchesByStage.map(\.stage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stage picker
                stagePicker

                // Group filter (only visible in group stage)
                if selectedStage == .groupStage {
                    groupPicker
                }

                // Match list
                List {
                    ForEach(filteredMatches) { match in
                        MatchRowView(match: match)
                            .contentShape(Rectangle())
                            .onTapGesture { matchToEdit = match }
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .animation(.default, value: filteredMatches.map(\.id))
            }
            .navigationTitle("Coupe du Monde 2026")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Chercher une équipe…")
            .sheet(item: $matchToEdit) { match in
                ScoreEntryView(match: match)
                    .environment(store)
            }
        }
    }

    // MARK: - Pickers

    private var stagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stages, id: \.self) { stage in
                    Button {
                        withAnimation { selectedStage = stage; selectedGroup = nil }
                    } label: {
                        Text(stage.localizedName)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedStage == stage ? Color.accentColor : Color(.systemGray5),
                                        in: Capsule())
                            .foregroundStyle(selectedStage == stage ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var groupPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation { selectedGroup = nil }
                } label: {
                    Text("Tous")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedGroup == nil ? Color.orange : Color(.systemGray5),
                                    in: Capsule())
                        .foregroundStyle(selectedGroup == nil ? .white : .primary)
                }
                .buttonStyle(.plain)

                ForEach(Group.allCases, id: \.self) { group in
                    Button {
                        withAnimation { selectedGroup = group }
                    } label: {
                        Text("Gr. \(group.rawValue)")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedGroup == group ? Color.orange : Color(.systemGray5),
                                        in: Capsule())
                            .foregroundStyle(selectedGroup == group ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Filtered matches

    private var filteredMatches: [Match] {
        var list = store.matches

        // Stage filter
        if let stage = selectedStage {
            list = list.filter { $0.stage == stage }
        }

        // Group filter
        if selectedStage == .groupStage, let group = selectedGroup {
            list = list.filter { $0.group == group }
        }

        // Search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.homeTeam.lowercased().contains(q) ||
                $0.awayTeam.lowercased().contains(q) ||
                $0.city.lowercased().contains(q)
            }
        }

        return list.sorted { $0.date < $1.date }
    }
}

// MARK: - Match row card

struct MatchRowView: View {
    let match: Match

    var body: some View {
        HStack(spacing: 0) {
            // Date column
            VStack(alignment: .center, spacing: 2) {
                Text(dayNumber)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(monthAbbr)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(match.parisTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .frame(width: 44)

            Divider()
                .padding(.horizontal, 10)

            // Home team
            VStack(spacing: 2) {
                Text(match.homeFlag).font(.title2)
                Text(match.homeTeam)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)

            // Score / vs
            VStack(spacing: 2) {
                if match.hasScore {
                    Text(match.scoreText)
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } else {
                    Text("vs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                groupBadge
            }
            .frame(width: 70)

            // Away team
            VStack(spacing: 2) {
                Text(match.awayFlag).font(.title2)
                Text(match.awayTeam)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)

            // Edit indicator
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.quaternary)
                .font(.title3)
                .padding(.leading, 6)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var dayNumber: String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: TimeZone(identifier: "Europe/Paris")!, from: match.date)
        return comps.day.map { "\($0)" } ?? ""
    }

    private var monthAbbr: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "MMM"
        fmt.timeZone = TimeZone(identifier: "Europe/Paris")
        return fmt.string(from: match.date).uppercased()
    }

    @ViewBuilder
    private var groupBadge: some View {
        if let g = match.group {
            Text("Gr.\(g.rawValue)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.accentColor)
        }
    }
}
