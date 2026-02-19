// FretMasterApp.swift
// FretMaster — App Entry Point

import SwiftUI

@main
struct FretMasterApp: App {

    @StateObject private var container = AppContainer()
    @AppStorage(LocalUserPreferences.Key.colorScheme) private var colorSchemeRaw: String = LocalUserPreferences.Default.colorScheme

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // "system" — follow device setting
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container.modelContainer)
                .environment(\.appContainer, container)
                .preferredColorScheme(preferredColorScheme)
        }
    }
}
