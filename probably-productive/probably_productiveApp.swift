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
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Habit.self, MoodEntry.self, AppState.self])
    }
}

// RootView has access to modelContext after modelContainer is set up,
// so it can fetch/create AppState and pass stores into the app environment.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let appState = fetchOrCreateAppState()
        ContentView(
            habitStore: HabitStore(modelContext: modelContext, appState: appState),
            moodStore: MoodStore(modelContext: modelContext, appState: appState)
        )
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
