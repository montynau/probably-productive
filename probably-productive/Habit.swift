import Foundation
import SwiftData

@Model
class Habit {
    var id: UUID
    var name: String
    var completedDates: [String] // "yyyy-MM-dd"

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.completedDates = []
    }

    func isCompletedToday() -> Bool {
        completedDates.contains(Self.dateString(for: .now))
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var date = Date.now

        if !completedDates.contains(Self.dateString(for: date)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }

        while completedDates.contains(Self.dateString(for: date)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }

        return streak
    }

    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
