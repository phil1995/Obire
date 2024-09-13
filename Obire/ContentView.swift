//
//  ContentView.swift
//  Obire
//
//  Created by Philipp Schmid on 08.09.24.
//

import SwiftUI

struct ContentView: View {
    let appState: AppState
    var body: some View {
        VStack {
            GeneralSettings(appState: appState)
            FullSizeDebugView(appState: appState)
        }
        .padding()
    }
}

#Preview {
    ContentView(appState: .init(modelContext: .preview))
        .frame(width: 400, height: 400)
}
