import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Habit Notifications

    /// Reschedule all habit notifications. Pass all habits (including archived) so stale ones get cancelled.
    func rescheduleHabitNotifications(allHabits: [Habit]) {
        let allIDs = allHabits.flatMap { notificationIDs(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)

        guard UserDefaults.standard.bool(forKey: "habitsReminderEnabled") else { return }

        let fallbackSeconds = UserDefaults.standard.double(forKey: "habitsReminderSeconds")
        let fallbackDate = Calendar.current.startOfDay(for: .now)
            .addingTimeInterval(fallbackSeconds > 0 ? fallbackSeconds : 9 * 3600)
        let fc = Calendar.current.dateComponents([.hour, .minute], from: fallbackDate)
        let fallbackHour = fc.hour ?? 9
        let fallbackMinute = fc.minute ?? 0

        for habit in allHabits where !habit.isArchived && habit.schedule != .never {
            scheduleNotification(for: habit, fallbackHour: fallbackHour, fallbackMinute: fallbackMinute)
        }
    }

    private func notificationIDs(for habit: Habit) -> [String] {
        let base = "habit_\(habit.id.uuidString)"
        switch habit.schedule {
        case .weekdays: return (2...6).map { "\(base)_wd\($0)" }
        case .weekends: return [1, 7].map { "\(base)_wd\($0)" }
        default: return [base]
        }
    }

    private func scheduleNotification(for habit: Habit, fallbackHour: Int, fallbackMinute: Int) {
        let hour: Int
        let minute: Int
        if let t = habit.scheduledTime {
            let c = Calendar.current.dateComponents([.hour, .minute], from: t)
            hour = c.hour ?? fallbackHour
            minute = c.minute ?? fallbackMinute
        } else {
            hour = fallbackHour
            minute = fallbackMinute
        }

        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = notificationBody(for: habit)
        content.sound = .default

        let base = "habit_\(habit.id.uuidString)"

        switch habit.schedule {
        case .weekdays:
            for weekday in 2...6 {
                add(content: content, id: "\(base)_wd\(weekday)", hour: hour, minute: minute, weekday: weekday)
            }
        case .weekends:
            for weekday in [1, 7] {
                add(content: content, id: "\(base)_wd\(weekday)", hour: hour, minute: minute, weekday: weekday)
            }
        default:
            add(content: content, id: base, hour: hour, minute: minute, weekday: nil)
        }
    }

    private func add(content: UNMutableNotificationContent, id: String, hour: Int, minute: Int, weekday: Int?) {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        comps.weekday = weekday
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func notificationBody(for habit: Habit) -> String {
        let options = [
            "This won't do itself. Unfortunately.",
            "Your future self is begging you. Do it.",
            "Time to check this one off. You've got this. Probably.",
            "Tap to log it. Or ignore this. We'll know.",
        ]
        return options[abs(habit.name.hashValue) % options.count]
    }

    // MARK: - Mood Notification

    func scheduleMoodReminder(hour: Int, minute: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["mood_daily"])
        let content = UNMutableNotificationContent()
        content.title = "How's it going?"
        content.body = "Time to log your mood. Be honest, no one's watching."
        content.sound = .default
        add(content: content, id: "mood_daily", hour: hour, minute: minute, weekday: nil)
    }

    func cancelMoodReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["mood_daily"])
    }
}
