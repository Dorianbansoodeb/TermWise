//
//  ContentView.swift
//  TermWise
//
//  Created by Dorian Bansoodeb on 2026-05-05.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var flow: AppFlow = .landing

    var body: some View {
        Group {
            switch flow {
            case .landing:
                LandingView(
                    onGetStarted: { flow = .onboarding },
                    onLogIn: { flow = .mainTabs }
                )
            case .onboarding:
                OnboardingView { onboardingData in
                    appState.apply(onboardingData: onboardingData)
                    flow = .mainTabs
                }
            case .mainTabs:
                MainTabView()
                    .environmentObject(appState)
            }
        }
        .animation(.easeInOut, value: flow)
    }
}

private enum AppFlow {
    case landing
    case onboarding
    case mainTabs
}

#Preview {
    ContentView()
}
