//
//  probably_productiveApp.swift
//  probably-productive
//
//  Created by Monty on 06/03/2026.
//

import SwiftUI
import SwiftData

@main
struct probably_productiveApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: Habit.self, MoodEntry.self, AppState.self,
                migrationPlan: AppMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

// RootView has access to modelContext after modelContainer is set up,
// so it can fetch/create AppState and pass stores into the app environment.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("colorSchemeRaw") private var colorSchemeRaw: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        let appState = fetchOrCreateAppState()
        ContentView(
            habitStore: HabitStore(modelContext: modelContext, appState: appState),
            moodStore: MoodStore(modelContext: modelContext, appState: appState)
        )
        .preferredColorScheme(preferredColorScheme)
        .fullScreenCover(isPresented: .constant(!hasSeenOnboarding)) {
            OnboardingView()
        }
    }

    private func fetchOrCreateAppState() -> AppState {
        let descriptor = FetchDescriptor<AppState>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let state = AppState()
        modelContext.insert(state)
        try? modelContext.save()
        return state
    }
}
