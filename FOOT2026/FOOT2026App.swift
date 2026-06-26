//
//  FOOT2026App.swift
//  FOOT2026
//
//  Created by Robert Oulhen on 11/06/2026.
//

import SwiftUI

@main
struct FOOT2026App: App {
    @State private var store = MatchStore()
    @State private var playerStore = PlayerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(playerStore)
        }
    }
}
