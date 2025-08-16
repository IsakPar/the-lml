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
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @State private var selectedTab: Int = 1
    @State private var keyboardVisible: Bool = false
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                StageKit.bgGradient.ignoresSafeArea()
                Group {
                    switch selectedTab {
                    case 0: TicketsView()
                        .environmentObject(appState)
                        .environmentObject(navigationCoordinator)
                    case 1: HomeView()
                        .environmentObject(appState)
                        .environmentObject(navigationCoordinator)
                    default: AccountView()
                        .environmentObject(appState)
                        .environmentObject(navigationCoordinator)
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
            // Handle NavigationCoordinator tab changes
            .onChange(of: navigationCoordinator.selectedTab) { newTab in
                switch newTab {
                case .shows: selectedTab = 1
                case .tickets: selectedTab = 0
                case .profile: selectedTab = 2
                }
            }
        }
    }
}
