import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
class HabitStore {
    var habits: [Habit] = []
    var archivedHabits: [Habit] = []
    var appState: AppState

    var totalXP: Int {
        get { appState.totalXP }
        set { appState.totalXP = newValue }
    }

    var level: Int { totalXP / 100 + 1 }
    var xpInCurrentLevel: Int { totalXP % 100 }

    private var modelContext: ModelContext

    init(modelContext: ModelContext, appState: AppState) {
        self.modelContext = modelContext
        self.appState = appState
        fetch()
    }

    func fetch() {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        habits = (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchArchived() {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        archivedHabits = (try? modelContext.fetch(descriptor)) ?? []
    }

    func add(name: String, colorName: String = "blue", iconName: String = "checkmark") {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let habit = Habit(name: trimmed, colorName: colorName, iconName: iconName, sortOrder: habits.count)
        modelContext.insert(habit)
        save()
    }

    func update(_ habit: Habit, name: String, colorName: String, iconName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        habit.name = trimmed
        habit.colorName = colorName
        habit.iconName = iconName
        save()
    }

    func archive(_ habit: Habit) {
        habit.isArchived = true
        save()
    }

    func unarchive(_ habit: Habit) {
        habit.isArchived = false
        habit.sortOrder = habits.count
        save()
    }

    func delete(_ habit: Habit) {
        modelContext.delete(habit)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in habits.enumerated() {
            habit.sortOrder = index
        }
        save()
    }

    // Returns true if the habit was just completed (XP was earned)
    @discardableResult
    func toggle(_ habit: Habit) -> Bool {
        let today = Habit.dateString(for: .now)
        let completing = !habit.completedDates.contains(today)
        if completing {
            habit.completedDates.append(today)
            totalXP += 10
        } else {
            habit.completedDates.removeAll { $0 == today }
            totalXP = max(0, totalXP - 10)
        }
        save()
        return completing
    }

    func delete(at offsets: IndexSet) {
        offsets.forEach { modelContext.delete(habits[$0]) }
        save()
    }

    func addXP(_ amount: Int) {
        totalXP += amount
        save()
    }

    private func save() {
        try? modelContext.save()
        fetch()
        fetchArchived()
    }
}
