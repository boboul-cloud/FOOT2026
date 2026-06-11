//
//  ContentView.swift
//  FOOT2026
//
//  Created by Robert Oulhen on 11/06/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MatchesView()
    }
}

#Preview {
    ContentView()
        .environment(MatchStore())
}
