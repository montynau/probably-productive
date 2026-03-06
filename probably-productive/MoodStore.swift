import Foundation
import SwiftData
import Observation

@Observable
class MoodStore {
    var entries: [MoodEntry] = []
    var appState: AppState

    private var modelContext: ModelContext

    private let thresholdRatios: [(ratio: Double, xp: Int)] = [
        (0.33, 20), (0.67, 75), (0.83, 150), (1.0, 250)
    ]

    init(modelContext: ModelContext, appState: AppState) {
        self.modelContext = modelContext
        self.appState = appState
        fetch()
    }

    var todayEntry: MoodEntry? {
        entries.first { $0.date == MoodEntry.dateString(for: .now) }
    }

    // Returns bonus XP earned and a message describing the milestone (xp: 0 if none)
    @discardableResult
    func logMood(_ mood: MoodLevel, note: String = "") -> (xp: Int, message: String) {
        let today = MoodEntry.dateString(for: .now)
        if let existing = entries.first(where: { $0.date == today }) {
            modelContext.delete(existing)
        }
        modelContext.insert(MoodEntry(date: today, mood: mood, note: note))
        save()
        return checkBonus()
    }

    func entry(for dateString: String) -> MoodEntry? {
        entries.first { $0.date == dateString }
    }

    func search(query: String) -> [MoodEntry] {
        guard !query.isEmpty else { return entries }
        let q = query.lowercased()
        return entries.filter {
            $0.note.lowercased().contains(q) || $0.mood.label.lowercased().contains(q)
        }
    }

    var daysLoggedThisMonth: Int {
        let key = currentMonthKey()
        return entries.filter { $0.date.hasPrefix(key) }.count
    }

    var nextThreshold: (days: Int, xp: Int)? {
        let count = daysLoggedThisMonth
        return thresholds(for: .now).first { $0.days > count }
    }

    // MARK: - Bonus logic

    private func thresholds(for month: Date) -> [(days: Int, xp: Int)] {
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 30
        return thresholdRatios.map { (Int((Double(daysInMonth) * $0.ratio).rounded()), $0.xp) }
    }

    private func checkBonus() -> (xp: Int, message: String) {
        let key = currentMonthKey()
        let count = daysLoggedThisMonth
        var paid = appState.paidBonuses[key] ?? []
        var bonusEarned = 0
        var lastMessage = ""

        for threshold in thresholds(for: .now) where count >= threshold.days && !paid.contains(threshold.days) {
            paid.append(threshold.days)
            bonusEarned += threshold.xp
            lastMessage = "\(threshold.days) days logged this month!"
        }

        if bonusEarned > 0 {
            appState.paidBonuses[key] = paid
            save()
        }
        return (bonusEarned, lastMessage)
    }

    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: .now)
    }

    // MARK: - Persistence

    private func fetch() {
        let descriptor = FetchDescriptor<MoodEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func save() {
        try? modelContext.save()
        fetch()
    }
}
