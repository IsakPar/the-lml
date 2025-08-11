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
    @State private var selectedTab: Int = 1
    @State private var keyboardVisible: Bool = false
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                StageKit.bgGradient.ignoresSafeArea()
                Group {
                    switch selectedTab {
                    case 0: TicketsView().environmentObject(appState)
                    case 1: HomeView().environmentObject(appState)
                    default: AccountView().environmentObject(appState)
                    }
                }
                if !keyboardVisible {
                    StageTabBar(selected: $selectedTab)
                }
            }
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { keyboardVisible = false }
            }
        }
    }
}
