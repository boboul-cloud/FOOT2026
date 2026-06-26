//
//  ContentView.swift
//  FOOT2026
//
//  Created by Robert Oulhen on 11/06/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Matchs", systemImage: "list.bullet") {
                MatchesView()
            }
            Tab("Classement", systemImage: "chart.bar.fill") {
                StandingsView()
            }
            Tab("Buteurs", systemImage: "soccerball") {
                ScorersView()
            }
            Tab("Tableau", systemImage: "trophy.fill") {
                BracketView()
            }
            Tab("Joueurs", systemImage: "person.2.fill") {
                PlayersView()
            }
            Tab("Réglages", systemImage: "gearshape.fill") {
                BackupView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(MatchStore())
}
