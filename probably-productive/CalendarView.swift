import SwiftUI

// MARK: - Calendar View

struct CalendarView: View {
    @Environment(HabitStore.self) private var habitStore
    @Environment(MoodStore.self) private var moodStore

    @State private var displayedMonth = Date.now
    @State private var selectedDate: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayHeaders = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var monthDays: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday - 2 + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in range {
            if let date = calendar.date(byAdding: .day, value: i - 1, to: firstDay) {
                days.append(date)
            }
        }
        let remainder = days.count % 7
        if remainder != 0 { days += Array(repeating: nil, count: 7 - remainder) }
        return days
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthNavigation
                    dayHeaderRow
                    calendarGrid
                    if selectedDate != nil {
                        Divider()
                        dayDetail
                    }
                }
                .padding()
            }
            .navigationTitle("Calendar")
        }
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.bold())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.bold())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Day Headers

    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(dayHeaders.indices, id: \.self) { i in
                Text(dayHeaders[i])
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                if let date {
                    let ds = Habit.dateString(for: date)
                    let isSelected = selectedDate == ds
                    let isToday = ds == Habit.dateString(for: .now)
                    let moodEntry = moodStore.entry(for: ds)
                    let done = habitStore.habits.filter { $0.completedDates.contains(ds) }.count
                    let total = habitStore.habits.count

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = isSelected ? nil : ds
                        }
                    } label: {
                        UnifiedDayCell(
                            date: date,
                            moodEntry: moodEntry,
                            habitsDone: done,
                            habitsTotal: total,
                            isToday: isToday,
                            isSelected: isSelected
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 56)
                }
            }
        }
    }

    // MARK: - Day Detail

    @ViewBuilder
    private var dayDetail: some View {
        if let ds = selectedDate {
            VStack(alignment: .leading, spacing: 12) {
                if let entry = moodStore.entry(for: ds) {
                    HStack(spacing: 10) {
                        Text(entry.mood.emoji)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.mood.label)
                                .font(.subheadline.bold())
                                .foregroundStyle(entry.mood.color)
                            if !entry.note.isEmpty {
                                Text(entry.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                } else {
                    Label("No mood logged", systemImage: "face.dashed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                if !habitStore.habits.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(habitStore.habits) { habit in
                            let done = habit.completedDates.contains(ds)
                            HStack(spacing: 10) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? habit.color : .secondary)
                                Image(systemName: habit.iconName)
                                    .font(.caption)
                                    .foregroundStyle(habit.color)
                                    .frame(width: 16)
                                Text(habit.name)
                                    .font(.subheadline)
                                    .foregroundStyle(done ? .primary : .secondary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: selectedDate)
        }
    }
}

// MARK: - Unified Day Cell

struct UnifiedDayCell: View {
    let date: Date
    let moodEntry: MoodEntry?
    let habitsDone: Int
    let habitsTotal: Int
    let isToday: Bool
    let isSelected: Bool

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .primary : .secondary)

            if let entry = moodEntry {
                Text(entry.mood.emoji)
                    .font(.caption)
            } else {
                Color.clear.frame(height: 16)
            }

            if habitsTotal > 0 {
                Text("\(habitsDone)/\(habitsTotal)")
                    .font(.system(size: 9))
                    .foregroundStyle(habitsDone == habitsTotal && habitsTotal > 0 ? .green : .secondary)
            } else {
                Color.clear.frame(height: 11)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isToday ? Color.accentColor.opacity(0.08) : Color.clear))
        )
    }
}
