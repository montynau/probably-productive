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

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
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

    private var allActiveHabits: [Habit] {
        habitStore.habits + habitStore.notDueHabits
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthNavigation
                    dayHeaderRow
                    calendarGrid
                    if let ds = selectedDate {
                        dayDetail(for: ds)
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

            VStack(spacing: 2) {
                Text(monthTitle)
                    .font(.headline)
                if !isCurrentMonth {
                    Button("Today") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = .now
                            selectedDate = nil
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }

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
                    let done = allActiveHabits.filter { h in
                        if h.schedule == .hourly {
                            return h.completedDates.filter { $0.hasPrefix(ds + " ") }.count >= h.todaySlotCount
                        }
                        return h.completedDates.contains(ds)
                    }.count
                    let total = allActiveHabits.count

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = isSelected ? nil : ds
                        }
                    } label: {
                        CalendarDayCell(
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
                    Color.clear.frame(height: 62)
                }
            }
        }
    }

    // MARK: - Day Detail

    @ViewBuilder
    private func dayDetail(for ds: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate(ds))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            moodRow(for: ds)
            habitsRows(for: ds)
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: ds)
    }

    @ViewBuilder
    private func moodRow(for ds: String) -> some View {
        if let entry = moodStore.entry(for: ds) {
            HStack(spacing: 10) {
                Image(entry.mood.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.mood.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(entry.mood.color)
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "face.dashed")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                    .frame(width: 56, height: 56)
                Text("No mood logged")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func habitsRows(for ds: String) -> some View {
        if !allActiveHabits.isEmpty {
            VStack(spacing: 0) {
                ForEach(allActiveHabits.indices, id: \.self) { index in
                    let habit = allActiveHabits[index]
                    let completed: Bool = {
                        if habit.schedule == .hourly {
                            return habit.completedDates.filter { $0.hasPrefix(ds + " ") }.count >= habit.todaySlotCount
                        }
                        return habit.completedDates.contains(ds)
                    }()
                    let note = habit.notes.filter { $0.key == ds || $0.key.hasPrefix(ds + " ") }.values.first

                    HStack(spacing: 10) {
                        Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(completed ? habit.color : Color.secondary.opacity(0.3))
                            .frame(width: 24)

                        Image(systemName: habit.iconName)
                            .font(.caption)
                            .foregroundStyle(completed ? habit.color : .secondary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name)
                                .font(.subheadline)
                                .foregroundStyle(completed ? .primary : .secondary)
                            if let note, !note.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "note.text")
                                        .font(.caption2)
                                    Text(note)
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                                .italic()
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)

                    if index < allActiveHabits.count - 1 {
                        Divider()
                            .padding(.leading, 62)
                    }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ ds: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: ds) else { return ds }
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
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
        VStack(spacing: 3) {
            Text(dayNumber)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .green : .primary.opacity(0.7))

            if let entry = moodEntry {
                Text(entry.mood.label)
                    .font(.system(size: 8))
                    .foregroundStyle(entry.mood.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Color.clear.frame(height: 20)
            }

            if habitsTotal > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(habitsDone == habitsTotal && habitsTotal > 0 ? Color.green : Color.orange)
                            .frame(width: geo.size.width * (habitsTotal > 0 ? CGFloat(habitsDone) / CGFloat(habitsTotal) : 0))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 4)
            } else {
                Color.clear.frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.18)
                      : (isToday ? Color.green.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }
}
