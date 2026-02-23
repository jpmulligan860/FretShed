// FretShedApp.swift
// FretShed — App Entry Point

import SwiftUI

@main
struct FretShedApp: App {

    @State private var container: AppContainer?
    @AppStorage(LocalUserPreferences.Key.colorScheme) private var colorSchemeRaw: String = LocalUserPreferences.Default.colorScheme
    @AppStorage(LocalUserPreferences.Key.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = LocalUserPreferences.Default.hasCompletedOnboarding

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // "system" — follow device setting
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView()
                        .modelContainer(container.modelContainer)
                        .environment(\.appContainer, container)
                        .preferredColorScheme(preferredColorScheme)
                        .fullScreenCover(isPresented: Binding(
                            get: { !hasCompletedOnboarding },
                            set: { _ in }
                        )) {
                            OnboardingView()
                        }
                } else {
                    launchScreen
                }
            }
            .task {
                if container == nil {
                    container = await AppContainer.create()
                }
            }
        }
    }

    // MARK: - Launch Screen

    private var launchScreen: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "guitars.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignSystem.Colors.primary)
                Text("FretShed")
                    .font(.largeTitle.bold())
                ProgressView()
                    .controlSize(.regular)
            }
        }
    }
}
