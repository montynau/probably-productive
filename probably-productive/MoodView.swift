import SwiftUI
import SwiftData
import Charts

// MARK: - Calendar Tab

enum CalendarTab: String, CaseIterable {
    case week = "Week"
    case month = "Month"
}

// MARK: - Mood View

struct MoodView: View {
    @Environment(MoodStore.self) private var store
    @Environment(HabitStore.self) private var habitStore
    @State private var calendarTab: CalendarTab = .week
    @State private var displayedMonth = Date.now
    @State private var searchText = ""
    @State private var showNoteField = false
    @State private var noteText = ""
    @State private var isEditing = false
    @State private var selectedMood: MoodLevel?
    @State private var showingBurst = false
    @State private var burstAmount = 0
    @State private var burstMessage = ""
    @State private var showingXPToast = false

    var filteredEntries: [MoodEntry] {
        store.search(query: searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                todaySection

                Section("This Week") {
                    MoodChartView(store: store)
                }

                Section {
                    Picker("", selection: $calendarTab) {
                        ForEach(CalendarTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if calendarTab == .week {
                    weekSection
                } else {
                    monthSection
                }

                journalSection
            }
            .navigationTitle("Mood")
            .searchable(text: $searchText, prompt: "Search journal")
        }
        .overlay { burstOverlay }
        .overlay(alignment: .top) { xpToastOverlay }
        .animation(.spring(duration: 0.4), value: showingXPToast)
    }

    @ViewBuilder
    private var burstOverlay: some View {
        if showingBurst {
            XPBurstView(amount: burstAmount, message: burstMessage) {
                showingBurst = false
            }
        }
    }

    @ViewBuilder
    private var xpToastOverlay: some View {
        if showingXPToast {
            let shape = RoundedRectangle(cornerRadius: 16)
            XPHeaderView(store: habitStore)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Material.regularMaterial, in: shape)
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func logMood(_ mood: MoodLevel, note: String = "") {
        let result = store.logMood(mood, note: note)
        if result.xp > 0 {
            burstAmount = result.xp
            burstMessage = result.message
            showingBurst = true
            withAnimation(.spring(duration: 0.4)) {
                showingXPToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                habitStore.addXP(result.xp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showingXPToast = false
                }
            }
        }
    }

    // MARK: - Today Section

    @ViewBuilder
    var todaySection: some View {
        Section("Today") {
            if let entry = store.todayEntry, !isEditing {
                todayEntryRow(entry: entry)
            } else {
                moodPickerRow
            }
        }
    }

    private func todayEntryRow(entry: MoodEntry) -> some View {
        HStack(spacing: 14) {
            Text(entry.mood.emoji)
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.mood.label)
                    .font(.headline)
                    .foregroundStyle(entry.mood.color)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button("Edit") {
                noteText = entry.note
                selectedMood = entry.mood
                showNoteField = true
                isEditing = true
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var moodPickerRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing ? "Change your mood:" : "How are you feeling?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            moodButtonRow

            if !isEditing {
                Button {
                    showNoteField.toggle()
                    if !showNoteField {
                        noteText = ""
                        selectedMood = nil
                    }
                } label: {
                    Label(
                        showNoteField ? "Hide note" : "Add a note (optional)",
                        systemImage: showNoteField ? "chevron.up" : "pencil.line"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if showNoteField || isEditing {
                noteAndSaveRow
            }
        }
        .padding(.vertical, 4)
    }

    private var moodButtonRow: some View {
        HStack(spacing: 0) {
            ForEach(MoodLevel.allCases) { mood in
                Button {
                    if showNoteField || isEditing {
                        selectedMood = mood
                    } else {
                        logMood(mood)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(mood.emoji)
                            .font(.system(size: 38))
                            .scaleEffect(selectedMood == mood ? 1.2 : 1.0)
                            .animation(.spring(duration: 0.2), value: selectedMood)
                        Text(mood.label)
                            .font(.system(size: 9))
                            .foregroundStyle(selectedMood == mood ? mood.color : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fontWeight(selectedMood == mood ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(selectedMood == nil || selectedMood == mood ? 1.0 : 0.3)
                    .animation(.spring(duration: 0.2), value: selectedMood)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noteAndSaveRow: some View {
        VStack(spacing: 8) {
            TextField("What affected your mood?", text: $noteText, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    noteText = ""
                    showNoteField = false
                    isEditing = false
                    selectedMood = nil
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(isEditing ? "Save note" : "Log mood") {
                    if let mood = selectedMood {
                        logMood(mood, note: noteText)
                    }
                    noteText = ""
                    showNoteField = false
                    isEditing = false
                    selectedMood = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedMood == nil)
            }
        }
    }

    // MARK: - Week Section

    var weekSection: some View {
        Section("This Week") {
            MoodWeekView(store: store)
        }
    }

    // MARK: - Month Section

    var monthSection: some View {
        Section {
            MoodMonthView(store: store, displayedMonth: $displayedMonth)
        }
    }

    // MARK: - Journal Section

    var historyHeader: some View {
        HStack {
            Text("History")
            Spacer()
            if let next = store.nextThreshold {
                Text("\(store.daysLoggedThisMonth)/\(next.days) days · +\(next.xp) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if store.daysLoggedThisMonth > 0 {
                Text("All bonuses earned this month!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var journalSection: some View {
        if !filteredEntries.isEmpty {
            Section(header: historyHeader) {
                ForEach(filteredEntries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Text(entry.mood.emoji)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.mood.label)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(entry.mood.color)
                                Spacer()
                                Text(entry.displayDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !entry.note.isEmpty {
                                Text(entry.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } else if !searchText.isEmpty {
            Section("History") {
                ContentUnavailableView.search(text: searchText)
            }
        } else {
            Section("History") {
                ContentUnavailableView(
                    "No entries yet",
                    systemImage: "face.smiling",
                    description: Text("How are you feeling? (Be honest, no one's watching)")
                )
            }
        }
    }
}

// MARK: - Week View

struct MoodWeekView: View {
    var store: MoodStore

    private var weekDays: [(label: String, dateString: String)] {
        let calendar = Calendar.current
        let today = Date.now
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return nil }
            return (label: formatter.string(from: day), dateString: MoodEntry.dateString(for: day))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.dateString) { day in
                let entry = store.entry(for: day.dateString)
                let isToday = day.dateString == MoodEntry.dateString(for: .now)

                VStack(spacing: 4) {
                    Text(day.label)
                        .font(.caption2)
                        .foregroundStyle(isToday ? .primary : .tertiary)
                        .fontWeight(isToday ? .bold : .regular)

                    ZStack {
                        Circle()
                            .fill(isToday ? Color.accentColor.opacity(0.12) : .clear)
                            .frame(width: 40, height: 40)

                        if let entry {
                            Text(entry.mood.emoji)
                                .font(.title3)
                        } else {
                            Circle()
                                .fill(.quaternary)
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Month View

struct MoodMonthView: View {
    var store: MoodStore
    @Binding var displayedMonth: Date
    @State private var selectedDate: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayHeaders = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var monthDays: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        // Monday-based offset: weekday 1=Sun→6, 2=Mon→0, 3=Tue→1 ...
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday - 2 + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in range {
            if let date = calendar.date(byAdding: .day, value: i - 1, to: firstDay) {
                days.append(date)
            }
        }
        let remainder = days.count % 7
        if remainder != 0 {
            days += Array(repeating: nil, count: 7 - remainder)
        }
        return days
    }

    @ViewBuilder
    private func gridCell(for date: Date?) -> some View {
        if let date {
            let ds = MoodEntry.dateString(for: date)
            let isSelected = selectedDate == ds
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDate = isSelected ? nil : ds
                }
            } label: {
                MoodDayCell(
                    date: date,
                    entry: store.entry(for: ds),
                    isToday: ds == MoodEntry.dateString(for: .now),
                    isSelected: isSelected
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 44)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
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

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(dayHeaders.indices, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    gridCell(for: date)
                }
            }

            // Selected day detail
            if let ds = selectedDate {
                Divider()
                if let entry = store.entry(for: ds) {
                    HStack(spacing: 12) {
                        Text(entry.mood.emoji)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.mood.label)
                                .font(.headline)
                                .foregroundStyle(entry.mood.color)
                            if !entry.note.isEmpty {
                                Text(entry.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("No entry for this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
    }
}

// MARK: - Month Day Cell

struct MoodDayCell: View {
    let date: Date
    let entry: MoodEntry?
    let isToday: Bool
    let isSelected: Bool

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    private var backgroundFill: Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        if isToday { return Color.accentColor.opacity(0.08) }
        return .clear
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.caption2)
                .foregroundStyle(isToday ? .primary : .secondary)
                .fontWeight(isToday ? .bold : .regular)

            if let entry {
                Text(entry.mood.emoji)
                    .font(.body)
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundFill)
        )
    }
}

// MARK: - Mood Chart

struct MoodChartView: View {
    var store: MoodStore

    private var last7Days: [(label: String, dateString: String, value: Int?)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: .now)!
            let ds = MoodEntry.dateString(for: date)
            let value = store.entry(for: ds).map { $0.mood.rawValue }
            return (label: formatter.string(from: date), dateString: ds, value: value)
        }
    }

    var body: some View {
        Chart {
            ForEach(last7Days, id: \.dateString) { day in
                if let value = day.value {
                    LineMark(
                        x: .value("Day", day.label),
                        y: .value("Mood", value)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", day.label),
                        y: .value("Mood", value)
                    )
                    .foregroundStyle(.green)
                }
            }
        }
        .chartYScale(domain: 1...5)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                AxisGridLine()
                AxisValueLabel {
                    let emojis = ["😣", "😕", "😐", "🙂", "😄"]
                    if let v = value.as(Int.self), v >= 1 && v <= 5 {
                        Text(emojis[v - 1]).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 140)
        .padding(.vertical, 4)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Habit.self, MoodEntry.self, AppState.self], inMemory: true)
}
