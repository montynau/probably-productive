import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
class HabitStore {
    var habits: [Habit] = []
    var archivedHabits: [Habit] = []
    var notDueHabits: [Habit] = []
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
        fetchArchived()
    }

    func fetch() {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        habits = all.filter { $0.isDue() }
        notDueHabits = all.filter { !$0.isDue() }.sorted { $0.nextDueDate < $1.nextDueDate }
    }

    func fetchArchived() {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        archivedHabits = (try? modelContext.fetch(descriptor)) ?? []
    }

    func add(name: String, colorName: String = "blue", iconName: String = "checkmark", schedule: RepeatSchedule = .daily, scheduledTime: Date? = nil, scheduleEndTime: Date? = nil, hourlyInterval: Int = 2) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let habit = Habit(name: trimmed, colorName: colorName, iconName: iconName, sortOrder: habits.count + notDueHabits.count)
        habit.schedule = schedule
        habit.scheduledTime = scheduledTime
        habit.scheduleEndTime = scheduleEndTime
        habit.hourlyInterval = hourlyInterval
        modelContext.insert(habit)
        save()
    }

    func update(_ habit: Habit, name: String, colorName: String, iconName: String, schedule: RepeatSchedule, scheduledTime: Date?, scheduleEndTime: Date?, hourlyInterval: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        habit.name = trimmed
        habit.colorName = colorName
        habit.iconName = iconName
        habit.schedule = schedule
        habit.scheduledTime = scheduledTime
        habit.scheduleEndTime = scheduleEndTime
        habit.hourlyInterval = hourlyInterval
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
        let key: String
        if habit.schedule == .hourly {
            key = Habit.hourSlotKey(for: .now, interval: habit.hourlyInterval)
        } else {
            key = Habit.dateString(for: .now)
        }
        let completing = !habit.completedDates.contains(key)
        if completing {
            habit.completedDates.append(key)
            totalXP += 10
        } else {
            habit.completedDates.removeAll { $0 == key }
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
        NotificationManager.shared.rescheduleHabitNotifications(allHabits: habits + notDueHabits + archivedHabits)
    }
}
