import Foundation
import WidgetKit

struct WidgetHabit: Codable {
    let name: String
    let colorName: String
    let iconName: String
    let isDone: Bool
}

struct WidgetData: Codable {
    let habitsDone: Int
    let habitsTotal: Int
    let level: Int
    let xpInLevel: Int
    let habits: [WidgetHabit]
}

enum WidgetDataProvider {
    static let suiteName = "group.montynauorg.probably-productive"
    static let key = "widgetData"

    static func write(from store: HabitStore) {
        let allHabits = store.habits + store.notDueHabits
        let done = allHabits.filter { $0.isCompletedToday() }.count
        let widgetHabits = allHabits.prefix(4).map {
            WidgetHabit(name: $0.name, colorName: $0.colorName, iconName: $0.iconName, isDone: $0.isCompletedToday())
        }
        let data = WidgetData(
            habitsDone: done,
            habitsTotal: allHabits.count,
            level: store.level,
            xpInLevel: store.xpInCurrentLevel,
            habits: Array(widgetHabits)
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults(suiteName: suiteName)?.set(encoded, forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
