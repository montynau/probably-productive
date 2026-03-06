import Foundation
import SwiftData
import Observation

@Observable
class HabitStore {
    var habits: [Habit] = []
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
        let descriptor = FetchDescriptor<Habit>()
        habits = (try? modelContext.fetch(descriptor)) ?? []
    }

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Habit(name: trimmed))
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
    }
}
