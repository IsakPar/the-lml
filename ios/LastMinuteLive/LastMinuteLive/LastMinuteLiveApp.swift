//
//  LastMinuteLiveApp.swift
//  LastMinuteLive
//
//  Created by Isak Parild on 10/08/2025.
//

import SwiftUI

@main
struct LastMinuteLiveApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
