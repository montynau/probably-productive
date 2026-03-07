import Foundation
import SwiftData
import SwiftUI

@Model
class Habit {
    var id: UUID
    var name: String
    var completedDates: [String] // "yyyy-MM-dd"
    var colorName: String
    var iconName: String
    var sortOrder: Int

    init(name: String, colorName: String = "blue", iconName: String = "checkmark", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.completedDates = []
        self.colorName = colorName
        self.iconName = iconName
        self.sortOrder = sortOrder
    }

    var color: Color {
        switch colorName {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "teal": .teal
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        default: .blue
        }
    }

    func isCompletedToday() -> Bool {
        completedDates.contains(Self.dateString(for: .now))
    }

    var longestStreak: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = completedDates.compactMap { formatter.date(from: $0) }.sorted()
        guard !dates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var longest = 1
        var current = 1
        for i in 1..<dates.count {
            let diff = calendar.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else if diff > 1 {
                current = 1
            }
        }
        return longest
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
