import Foundation
import SwiftData
import SwiftUI

// MARK: - Habit Category

enum HabitCategory: String, Codable, CaseIterable {
    case health = "health"
    case work = "work"
    case learning = "learning"
    case personal = "personal"
    case finance = "finance"
    case social = "social"
    case other = "other"

    var displayName: String {
        switch self {
        case .health: "Health"
        case .work: "Work"
        case .learning: "Learning"
        case .personal: "Personal"
        case .finance: "Finance"
        case .social: "Social"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .health: "heart.fill"
        case .work: "briefcase.fill"
        case .learning: "book.fill"
        case .personal: "person.fill"
        case .finance: "dollarsign.circle.fill"
        case .social: "person.2.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .health: .red
        case .work: .blue
        case .learning: .purple
        case .personal: .green
        case .finance: .yellow
        case .social: .orange
        case .other: .gray
        }
    }
}

// MARK: - Repeat Schedule

enum RepeatSchedule: String, Codable, CaseIterable {
    case never = "never"
    case hourly = "hourly"
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case semiannually = "semiannually"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .never: "Never"
        case .hourly: "Every X Hours"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 Weeks"
        case .monthly: "Monthly"
        case .quarterly: "Every 3 Months"
        case .semiannually: "Every 6 Months"
        case .yearly: "Yearly"
        }
    }
}

// MARK: - Habit Model

@Model
class Habit {
    var id: UUID
    var name: String
    var completedDates: [String] // "yyyy-MM-dd"
    var colorName: String
    var iconName: String
    var sortOrder: Int
    var isArchived: Bool = false
    var scheduleRaw: String = "daily"
    var scheduledTime: Date? = nil
    var hourlyInterval: Int = 2
    var scheduleEndTime: Date? = nil
    var categoryRaw: String = "other"

    init(name: String, colorName: String = "blue", iconName: String = "checkmark", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.completedDates = []
        self.colorName = colorName
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isArchived = false
        self.scheduleRaw = "daily"
        self.scheduledTime = nil
        self.hourlyInterval = 2
        self.scheduleEndTime = nil
        self.categoryRaw = "other"
    }

    var schedule: RepeatSchedule {
        get { RepeatSchedule(rawValue: scheduleRaw) ?? .daily }
        set { scheduleRaw = newValue.rawValue }
    }

    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
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

    // MARK: - Due Logic

    static func hourSlotKey(for date: Date = .now, interval: Int) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let slotHour = (hour / max(1, interval)) * max(1, interval)
        return "\(dateString(for: date)) \(String(format: "%02d", slotHour))"
    }

    func isDue(on date: Date = .now) -> Bool {
        let calendar = Calendar.current

        // Check scheduled time gate (not applied to hourly — it has its own range logic)
        if schedule != .hourly, let time = scheduledTime {
            let timeHour = calendar.component(.hour, from: time)
            let timeMin = calendar.component(.minute, from: time)
            let nowHour = calendar.component(.hour, from: date)
            let nowMin = calendar.component(.minute, from: date)
            if nowHour * 60 + nowMin < timeHour * 60 + timeMin { return false }
        }

        switch schedule {
        case .hourly:
            let nowHour = calendar.component(.hour, from: date)
            let nowMin = calendar.component(.minute, from: date)
            let nowTotal = nowHour * 60 + nowMin

            if let start = scheduledTime {
                let sh = calendar.component(.hour, from: start)
                let sm = calendar.component(.minute, from: start)
                if nowTotal < sh * 60 + sm { return false }
            }
            if let end = scheduleEndTime {
                let eh = calendar.component(.hour, from: end)
                let em = calendar.component(.minute, from: end)
                if nowTotal > eh * 60 + em { return false }
            }
            return !completedDates.contains(Self.hourSlotKey(for: date, interval: hourlyInterval))
        case .never:
            return completedDates.isEmpty
        case .daily:
            return !completedDates.contains(Self.dateString(for: date))
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            guard weekday >= 2 && weekday <= 6 else { return false }
            return !completedDates.contains(Self.dateString(for: date))
        case .weekends:
            let weekday = calendar.component(.weekday, from: date)
            guard weekday == 1 || weekday == 7 else { return false }
            return !completedDates.contains(Self.dateString(for: date))
        case .weekly:
            let week = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.yearForWeekOfYear, from: date)
            return !completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                return calendar.component(.weekOfYear, from: d) == week
                    && calendar.component(.yearForWeekOfYear, from: d) == year
            }
        case .biweekly:
            guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -13, to: date) else { return true }
            let start = Self.dateString(for: twoWeeksAgo)
            let end = Self.dateString(for: date)
            return !completedDates.contains { $0 >= start && $0 <= end }
        case .monthly:
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            return !completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                return calendar.component(.month, from: d) == month
                    && calendar.component(.year, from: d) == year
            }
        case .quarterly:
            let quarter = (calendar.component(.month, from: date) - 1) / 3
            let year = calendar.component(.year, from: date)
            return !completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                let dq = (calendar.component(.month, from: d) - 1) / 3
                return dq == quarter && calendar.component(.year, from: d) == year
            }
        case .semiannually:
            let half = (calendar.component(.month, from: date) - 1) / 6
            let year = calendar.component(.year, from: date)
            return !completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                let dh = (calendar.component(.month, from: d) - 1) / 6
                return dh == half && calendar.component(.year, from: d) == year
            }
        case .yearly:
            let year = calendar.component(.year, from: date)
            return !completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                return calendar.component(.year, from: d) == year
            }
        }
    }

    func isCompletedToday() -> Bool {
        switch schedule {
        case .hourly:
            return completedDates.contains(Self.hourSlotKey(for: .now, interval: hourlyInterval))
        case .daily, .weekdays, .weekends, .never:
            return completedDates.contains(Self.dateString(for: .now))
        case .weekly:
            let calendar = Calendar.current
            let week = calendar.component(.weekOfYear, from: .now)
            let year = calendar.component(.yearForWeekOfYear, from: .now)
            return completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                return calendar.component(.weekOfYear, from: d) == week
                    && calendar.component(.yearForWeekOfYear, from: d) == year
            }
        case .biweekly:
            let calendar = Calendar.current
            guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -13, to: .now) else { return false }
            let start = Self.dateString(for: twoWeeksAgo)
            let end = Self.dateString(for: .now)
            return completedDates.contains { $0 >= start && $0 <= end }
        case .monthly:
            let calendar = Calendar.current
            let month = calendar.component(.month, from: .now)
            let year = calendar.component(.year, from: .now)
            return completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                return calendar.component(.month, from: d) == month
                    && calendar.component(.year, from: d) == year
            }
        case .quarterly:
            let calendar = Calendar.current
            let quarter = (calendar.component(.month, from: .now) - 1) / 3
            let year = calendar.component(.year, from: .now)
            return completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                let dq = (calendar.component(.month, from: d) - 1) / 3
                return dq == quarter && calendar.component(.year, from: d) == year
            }
        case .semiannually:
            let calendar = Calendar.current
            let half = (calendar.component(.month, from: .now) - 1) / 6
            let year = calendar.component(.year, from: .now)
            return completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                let dh = (calendar.component(.month, from: d) - 1) / 6
                return dh == half && calendar.component(.year, from: d) == year
            }
        case .yearly:
            let calendar = Calendar.current
            let year = calendar.component(.year, from: .now)
            return completedDates.contains { ds in
                guard let d = Self.date(from: ds) else { return false }
                return calendar.component(.year, from: d) == year
            }
        }
    }

    // MARK: - Streak

    var currentStreak: Int {
        switch schedule {
        case .never:
            return completedDates.isEmpty ? 0 : 1
        case .hourly:
            return hourlyDailyStreak()
        case .daily:
            return dailyStreak(validDay: { _ in true })
        case .weekdays:
            return dailyStreak(validDay: { date in
                let w = Calendar.current.component(.weekday, from: date)
                return w >= 2 && w <= 6
            })
        case .weekends:
            return dailyStreak(validDay: { date in
                let w = Calendar.current.component(.weekday, from: date)
                return w == 1 || w == 7
            })
        case .weekly:
            return periodicStreak { d in
                let cal = Calendar.current
                return "\(cal.component(.yearForWeekOfYear, from: d))-W\(cal.component(.weekOfYear, from: d))"
            }
        case .biweekly:
            return biweeklyStreak()
        case .monthly:
            return periodicStreak { d in
                let cal = Calendar.current
                return "\(cal.component(.year, from: d))-\(cal.component(.month, from: d))"
            }
        case .quarterly:
            return periodicStreak { d in
                let cal = Calendar.current
                let q = (cal.component(.month, from: d) - 1) / 3
                return "\(cal.component(.year, from: d))-Q\(q)"
            }
        case .semiannually:
            return periodicStreak { d in
                let cal = Calendar.current
                let h = (cal.component(.month, from: d) - 1) / 6
                return "\(cal.component(.year, from: d))-H\(h)"
            }
        case .yearly:
            return periodicStreak { d in
                "\(Calendar.current.component(.year, from: d))"
            }
        }
    }

    var longestStreak: Int {
        switch schedule {
        case .never:
            return completedDates.isEmpty ? 0 : 1
        case .hourly:
            return longestHourlyDailyStreak()
        case .daily:
            return longestDailyStreak(validDay: { _ in true })
        case .weekdays:
            return longestDailyStreak(validDay: { date in
                let w = Calendar.current.component(.weekday, from: date)
                return w >= 2 && w <= 6
            })
        case .weekends:
            return longestDailyStreak(validDay: { date in
                let w = Calendar.current.component(.weekday, from: date)
                return w == 1 || w == 7
            })
        default:
            // For weekly+, longest streak = all unique periods completed
            return periodicStreak { d in
                let cal = Calendar.current
                switch schedule {
                case .weekly: return "\(cal.component(.yearForWeekOfYear, from: d))-W\(cal.component(.weekOfYear, from: d))"
                case .monthly: return "\(cal.component(.year, from: d))-\(cal.component(.month, from: d))"
                default: return Self.dateString(for: d)
                }
            }
        }
    }

    // MARK: - Private Streak Helpers

    private func dailyStreak(validDay: (Date) -> Bool) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var date = Date.now

        // If today (valid day) not completed, start from yesterday
        if validDay(date) && !completedDates.contains(Self.dateString(for: date)) {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = prev
        }

        while true {
            if !validDay(date) {
                // Skip non-valid days (weekends for weekday streak, etc.)
                guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
                continue
            }
            if completedDates.contains(Self.dateString(for: date)) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return streak
    }

    private func longestDailyStreak(validDay: (Date) -> Bool) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = completedDates.compactMap { formatter.date(from: $0) }
            .filter { validDay($0) }
            .sorted()
        guard !dates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var longest = 1
        var current = 1
        for i in 1..<dates.count {
            // Count only consecutive valid days
            var check = dates[i - 1]
            var gap = 0
            while let next = calendar.date(byAdding: .day, value: 1, to: check), next <= dates[i] {
                if validDay(next) { gap += 1 }
                if calendar.isDate(next, inSameDayAs: dates[i]) { break }
                check = next
            }
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private func periodicStreak(periodKey: (Date) -> String) -> Int {
        guard !completedDates.isEmpty else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = completedDates.compactMap { formatter.date(from: $0) }.sorted(by: >)
        guard !dates.isEmpty else { return 0 }

        var periods = Set<String>()
        for d in dates { periods.insert(periodKey(d)) }

        let currentPeriod = periodKey(Date.now)
        var streak = 0

        // Walk back from current period
        var checkDate = Date.now
        var lastPeriod: String? = nil

        for _ in 0..<(periods.count + 1) {
            let key = periodKey(checkDate)
            if key == lastPeriod {
                // move back more
                guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
                continue
            }
            lastPeriod = key
            if periods.contains(key) {
                streak += 1
            } else if key != currentPeriod {
                break
            }
            guard let prev = Calendar.current.date(byAdding: .day, value: -7, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    private func biweeklyStreak() -> Int {
        guard !completedDates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var periodEnd = Date.now
        var periodStart = calendar.date(byAdding: .day, value: -13, to: periodEnd) ?? periodEnd

        for _ in 0..<100 {
            let start = Self.dateString(for: periodStart)
            let end = Self.dateString(for: periodEnd)
            let hasCompletion = completedDates.contains { $0 >= start && $0 <= end }
            if hasCompletion {
                streak += 1
            } else if streak > 0 {
                break
            } else {
                break
            }
            periodEnd = calendar.date(byAdding: .day, value: -14, to: periodStart) ?? periodStart
            periodStart = calendar.date(byAdding: .day, value: -13, to: periodEnd) ?? periodEnd
        }
        return streak
    }

    // MARK: - Hourly Streak Helpers

    /// Current streak in days for hourly habits (at least one slot completed per day)
    private func hourlyDailyStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var date = Date.now

        func hasCompletionOn(_ d: Date) -> Bool {
            let prefix = Self.dateString(for: d)
            return completedDates.contains { $0.hasPrefix(prefix) }
        }

        if !hasCompletionOn(date) {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = prev
        }

        while true {
            if hasCompletionOn(date) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return streak
    }

    /// Longest streak in days for hourly habits (at least one slot completed per day)
    private func longestHourlyDailyStreak() -> Int {
        let dateKeys = Set(completedDates.compactMap { key -> String? in
            // Extract the date prefix "yyyy-MM-dd" from "yyyy-MM-dd HH"
            let parts = key.split(separator: " ")
            return parts.first.map(String.init)
        })
        guard !dateKeys.isEmpty else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = dateKeys.compactMap { formatter.date(from: $0) }.sorted()
        guard !dates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var longest = 1
        var current = 1
        for i in 1..<dates.count {
            let diff = calendar.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    // MARK: - Slot Helpers

    /// Number of slots in today's daily window for hourly habits
    var todaySlotCount: Int {
        guard schedule == .hourly else { return 1 }
        let calendar = Calendar.current
        let startHour: Int
        if let s = scheduledTime {
            startHour = calendar.component(.hour, from: s)
        } else { startHour = 0 }
        let endHour: Int
        if let e = scheduleEndTime {
            endHour = calendar.component(.hour, from: e)
        } else { endHour = 23 }
        let span = max(0, endHour - startHour)
        return span / max(1, hourlyInterval) + 1
    }

    /// Number of slots completed today for hourly habits
    var completedSlotsToday: Int {
        guard schedule == .hourly else { return 0 }
        let prefix = Self.dateString(for: .now)
        return completedDates.filter { $0.hasPrefix(prefix) }.count
    }

    /// How many more times this habit will become due today (only meaningful for hourly)
    var remainingTodayCount: Int {
        guard schedule == .hourly else { return 0 }
        let calendar = Calendar.current
        let nowHour = calendar.component(.hour, from: .now)
        let nextSlotHour = ((nowHour / max(1, hourlyInterval)) + 1) * max(1, hourlyInterval)
        let endHour: Int
        if let e = scheduleEndTime {
            endHour = calendar.component(.hour, from: e)
        } else { endHour = 23 }
        guard nextSlotHour <= endHour else { return 0 }
        return (endHour - nextSlotHour) / max(1, hourlyInterval) + 1
    }

    /// Date when this habit is next due (used for sorting "Later" section)
    var nextDueDate: Date {
        let calendar = Calendar.current
        let now = Date.now

        func todayAt(_ source: Date?) -> Date {
            guard let s = source else { return now }
            return calendar.date(bySettingHour: calendar.component(.hour, from: s),
                                 minute: calendar.component(.minute, from: s),
                                 second: 0, of: now) ?? now
        }
        func tomorrowAt(_ source: Date?) -> Date {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            guard let s = source else { return tomorrow }
            return calendar.date(bySettingHour: calendar.component(.hour, from: s),
                                 minute: calendar.component(.minute, from: s),
                                 second: 0, of: tomorrow) ?? tomorrow
        }

        switch schedule {
        case .hourly:
            let nowHour = calendar.component(.hour, from: now)
            let nextSlotHour = ((nowHour / max(1, hourlyInterval)) + 1) * max(1, hourlyInterval)
            return calendar.date(bySettingHour: nextSlotHour, minute: 0, second: 0, of: now) ?? now
        case .daily:
            return tomorrowAt(scheduledTime)
        case .weekdays:
            var next = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            for _ in 0..<7 {
                let wd = calendar.component(.weekday, from: next)
                if wd >= 2 && wd <= 6 { break }
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            return scheduledTime.map { calendar.date(bySettingHour: calendar.component(.hour, from: $0), minute: calendar.component(.minute, from: $0), second: 0, of: next) ?? next } ?? next
        case .weekends:
            var next = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            for _ in 0..<7 {
                let wd = calendar.component(.weekday, from: next)
                if wd == 1 || wd == 7 { break }
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            return scheduledTime.map { calendar.date(bySettingHour: calendar.component(.hour, from: $0), minute: calendar.component(.minute, from: $0), second: 0, of: next) ?? next } ?? next
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: now) ?? now
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: now) ?? now
        case .semiannually:
            return calendar.date(byAdding: .month, value: 6, to: now) ?? now
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: now) ?? now
        case .never:
            return Date.distantFuture
        }
    }

    /// Human-readable label for when this habit is next due (used in "Later" section)
    var nextDueLabel: String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        func timeString(_ date: Date) -> String {
            if let t = scheduledTime {
                return " at \(timeFormatter.string(from: t))"
            }
            return ""
        }

        switch schedule {
        case .hourly:
            let nowHour = calendar.component(.hour, from: .now)
            let nextSlotHour = ((nowHour / max(1, hourlyInterval)) + 1) * max(1, hourlyInterval)
            if let start = scheduledTime {
                let startHour = calendar.component(.hour, from: start)
                let actualHour = max(nextSlotHour, startHour)
                if let next = calendar.date(bySettingHour: actualHour, minute: 0, second: 0, of: .now) {
                    return "Next: \(timeFormatter.string(from: next))"
                }
            }
            if let next = calendar.date(bySettingHour: nextSlotHour, minute: 0, second: 0, of: .now) {
                return "Next: \(timeFormatter.string(from: next))"
            }
            return schedule.displayName
        case .daily:
            return "Tomorrow\(timeString(.now))"
        case .weekdays:
            // Find next weekday
            var next = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
            for _ in 0..<7 {
                let wd = calendar.component(.weekday, from: next)
                if wd >= 2 && wd <= 6 { break }
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            return "\(dayFormatter.string(from: next))\(timeString(next))"
        case .weekends:
            var next = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
            for _ in 0..<7 {
                let wd = calendar.component(.weekday, from: next)
                if wd == 1 || wd == 7 { break }
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            return "\(dayFormatter.string(from: next))\(timeString(next))"
        case .never:
            return "Done"
        case .weekly:
            return "Next week\(timeString(.now))"
        case .biweekly:
            return "In 2 weeks\(timeString(.now))"
        case .monthly:
            return "Next month\(timeString(.now))"
        case .quarterly:
            return "In 3 months\(timeString(.now))"
        case .semiannually:
            return "In 6 months\(timeString(.now))"
        case .yearly:
            return "Next year\(timeString(.now))"
        }
    }

    // MARK: - Helpers

    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
