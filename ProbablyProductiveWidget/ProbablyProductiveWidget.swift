import WidgetKit
import SwiftUI

// MARK: - Shared Data Model (mirrors WidgetDataProvider in app)

struct WidgetHabit: Codable {
    let name: String
    let colorName: String
    let iconName: String
    let isDone: Bool

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
}

struct WidgetData: Codable {
    let habitsDone: Int
    let habitsTotal: Int
    let level: Int
    let xpInLevel: Int
    let habits: [WidgetHabit]

    static var placeholder: WidgetData {
        WidgetData(
            habitsDone: 2,
            habitsTotal: 5,
            level: 3,
            xpInLevel: 65,
            habits: [
                WidgetHabit(name: "Morning run", colorName: "green", iconName: "figure.walk", isDone: true),
                WidgetHabit(name: "Read 20 min", colorName: "blue", iconName: "book.fill", isDone: true),
                WidgetHabit(name: "Drink water", colorName: "teal", iconName: "drop.fill", isDone: false),
                WidgetHabit(name: "Meditate", colorName: "purple", iconName: "brain.head.profile", isDone: false),
            ]
        )
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    static let suiteName = "group.montynauorg.probably-productive"
    static let key = "widgetData"

    func load() -> WidgetData {
        guard let raw = UserDefaults(suiteName: Self.suiteName)?.data(forKey: Self.key),
              let data = try? JSONDecoder().decode(WidgetData.self, from: raw) else {
            return .placeholder
        }
        return data
    }

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        completion(WidgetEntry(date: .now, data: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let entry = WidgetEntry(date: .now, data: load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - XP Bar

struct WidgetXPBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.green)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let data: WidgetData

    var allDone: Bool { data.habitsTotal > 0 && data.habitsDone == data.habitsTotal }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Lvl \(data.level)")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            Spacer()

            Text("\(data.habitsDone)/\(data.habitsTotal)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(allDone ? .green : .primary)

            Text("done today")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            WidgetXPBar(progress: Double(data.xpInLevel) / 100)
        }
        .padding(14)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let data: WidgetData

    var allDone: Bool { data.habitsTotal > 0 && data.habitsDone == data.habitsTotal }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                Text("\(data.habitsDone)/\(data.habitsTotal)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(allDone ? .green : .primary)

                Text("habits done")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Lvl \(data.level)")
                    .font(.caption.bold())
                    .foregroundStyle(.green)

                WidgetXPBar(progress: Double(data.xpInLevel) / 100)
            }
            .frame(maxHeight: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(data.habits.prefix(4), id: \.name) { habit in
                    HStack(spacing: 6) {
                        Image(systemName: habit.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(habit.isDone ? habit.color : .secondary)
                        Text(habit.name)
                            .font(.caption)
                            .foregroundStyle(habit.isDone ? .primary : .secondary)
                            .lineLimit(1)
                    }
                }
                if data.habits.isEmpty {
                    Text("No habits yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxHeight: .infinity)
        }
        .padding(14)
    }
}

// MARK: - Entry View

struct ProbablyProductiveWidgetEntryView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Widget

struct ProbablyProductiveWidget: Widget {
    let kind: String = "ProbablyProductiveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ProbablyProductiveWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Probably Productive")
        .description("Track your habits from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    ProbablyProductiveWidget()
} timeline: {
    WidgetEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    ProbablyProductiveWidget()
} timeline: {
    WidgetEntry(date: .now, data: .placeholder)
}
