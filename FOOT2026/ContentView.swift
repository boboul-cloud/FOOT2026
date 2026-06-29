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
                MatchesView().pinchToZoom()
            }
            Tab("Classement", systemImage: "chart.bar.fill") {
                StandingsView().pinchToZoom()
            }
            Tab("Buteurs", systemImage: "soccerball") {
                ScorersView().pinchToZoom()
            }
            Tab("Tableau", systemImage: "trophy.fill") {
                BracketView().pinchToZoom()
            }
            Tab("Joueurs", systemImage: "person.2.fill") {
                PlayersView().pinchToZoom()
            }
            Tab("Réglages", systemImage: "gearshape.fill") {
                BackupView().pinchToZoom()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(MatchStore())
}
