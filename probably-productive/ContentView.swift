import SwiftUI
import SwiftData

// MARK: - Main View

struct ContentView: View {
    var habitStore: HabitStore
    var moodStore: MoodStore

    var body: some View {
        TabView {
            HabitsView()
                .tabItem { Label("Habits", systemImage: "checkmark.circle") }
            MoodView()
                .tabItem { Label("Mood", systemImage: "face.smiling") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
        }
        .environment(habitStore)
        .environment(moodStore)
    }
}

// MARK: - Habits View

struct HabitsView: View {
    @Environment(HabitStore.self) private var store
    @State private var showingAddHabit = false
    @State private var editingHabit: Habit? = nil
    @State private var selectedHabit: Habit? = nil
    @State private var showingArchived = false
    @State private var showingReminders = false
    @State private var burstAmount: Int? = nil
    @State private var burstID = UUID()
    @State private var selectedCategory: HabitCategory? = nil
    @State private var pendingNoteHabit: Habit? = nil
    @State private var pendingNoteKey: String = ""

    private var categoriesInUse: [HabitCategory] {
        let all = store.habits + store.notDueHabits
        let used = Set(all.map { $0.category })
        return HabitCategory.allCases.filter { used.contains($0) }
    }

    private var filteredHabits: [Habit] {
        guard let cat = selectedCategory else { return store.habits }
        return store.habits.filter { $0.category == cat }
    }

    private func moveHabits(from source: IndexSet, to destination: Int) {
        guard selectedCategory == nil else { return }
        store.move(from: source, to: destination)
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryFilterChip(title: "All", icon: "square.grid.2x2", color: .primary, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categoriesInUse, id: \.self) { cat in
                    CategoryFilterChip(title: cat.displayName, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .padding(.horizontal, 16)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    XPHeaderView(store: store)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    HabitsStatsBar(store: store)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                if categoriesInUse.count > 1 {
                    Section {
                        categoryFilterBar
                    }
                    .listSectionSpacing(4)
                }

                ForEach(filteredHabits) { habit in
                    Button {
                        selectedHabit = habit
                    } label: {
                        HabitRow(habit: habit) {
                            let key = habit.schedule == .hourly
                                ? Habit.hourSlotKey(for: .now, interval: habit.hourlyInterval)
                                : Habit.dateString(for: .now)
                            let earned = store.toggle(habit)
                            burstAmount = earned ? 10 : -10
                            burstID = UUID()
                            if earned {
                                pendingNoteHabit = habit
                                pendingNoteKey = key
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editingHabit = habit } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button { store.archive(habit) } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        Divider()
                        Button(role: .destructive) { store.delete(habit) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: moveHabits)

                if !store.notDueHabits.isEmpty {
                    Section("Later") {
                        ForEach(store.notDueHabits) { habit in                            Button { selectedHabit = habit } label: {
                            HStack(spacing: 12) {
                                Image(systemName: habit.iconName)
                                    .font(.body)
                                    .foregroundStyle(habit.color.opacity(0.5))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.name)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 4) {
                                        Text(habit.nextDueLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if habit.remainingTodayCount > 1 {
                                            Text("· \(habit.remainingTodayCount) more today")
                                                .font(.caption.bold())
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                                Spacer()
                                if habit.currentStreak > 0 {
                                    StreakDotsView(streak: habit.currentStreak)
                                }
                            }
                            .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    editingHabit = habit
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    store.archive(habit)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    store.delete(habit)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .moveDisabled(true)
                    }
                }
            }
            .environment(\.editMode, Binding.constant(EditMode.active))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddHabit) {
                AddHabitSheet { name, colorName, iconName, schedule, scheduledTime, endTime, interval, category in
                    store.add(name: name, colorName: colorName, iconName: iconName, schedule: schedule, scheduledTime: scheduledTime, scheduleEndTime: endTime, hourlyInterval: interval, category: category)
                }
            }
            .sheet(item: $editingHabit) { habit in
                EditHabitSheet(habit: habit) { name, colorName, iconName, schedule, scheduledTime, endTime, interval, category in
                    store.update(habit, name: name, colorName: colorName, iconName: iconName, schedule: schedule, scheduledTime: scheduledTime, scheduleEndTime: endTime, hourlyInterval: interval, category: category)
                }
            }
            .sheet(item: $selectedHabit) { habit in
                HabitDetailSheet(habit: habit)
            }
            .sheet(isPresented: $showingArchived) {
                ArchivedHabitsView()
            }
            .sheet(isPresented: $showingReminders) {
                RemindersSheet()
            }
            .sheet(item: $pendingNoteHabit) { habit in
                HabitNoteSheet(habit: habit, dateKey: pendingNoteKey) { note in
                    store.saveNote(note, for: habit, dateKey: pendingNoteKey)
                }
            }
            .overlay {
                if store.habits.isEmpty && store.notDueHabits.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + and pretend you'll actually do it")
                    )
                    .background(.background)
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    Button { showingReminders = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.regularMaterial, in: Circle())
                    }
                    if !store.archivedHabits.isEmpty {
                        Button { showingArchived = true } label: {
                            Image(systemName: "archivebox")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .background(.regularMaterial, in: Circle())
                        }
                    }
                    Button { showingAddHabit = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.green, in: Circle())
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
        }
        .overlay {
            if let amount = burstAmount {
                XPBurstView(amount: amount) {
                    burstAmount = nil
                }
                .id(burstID)
            }
        }
    }
}

// MARK: - Habits Stats Bar

struct HabitsStatsBar: View {
    var store: HabitStore

    private var allHabits: [Habit] { store.habits + store.notDueHabits }

    private var completedToday: Int {
        allHabits.filter { $0.isCompletedToday() }.count
    }
    private var total: Int { allHabits.count }
    private var bestStreak: Int { allHabits.map { $0.currentStreak }.max() ?? 0 }
    private var bestLongest: Int { allHabits.map { $0.longestStreak }.max() ?? 0 }

    private var message: String {
        guard total > 0 else { return "" }
        switch completedToday {
        case 0:
            return "Today's not going great, is it?"
        case total:
            return "Okay, maybe actually productive"
        default:
            let hints: [String] = [
                "Keep going, almost there",
                "Still counts as trying",
                "Progress. Technically.",
                "Not bad. Could be worse.",
                "The couch can wait",
                "You started, that's something",
                "Momentum detected",
                "Someone's on a roll. Kinda.",
                "More than yesterday? Win.",
                "The rest won't do themselves"
            ]
            let index = completedToday % hints.count
            return hints[index]
        }
    }

    var body: some View {
        if total > 0 {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedToday)/\(total) done")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if bestLongest > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(bestStreak > 0 ? bestStreak : bestLongest)")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        Text(bestStreak > 0 ? "current" : "best")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - XP Header

struct XPHeaderView: View {
    var store: HabitStore
    @State private var displayedXP: Int = 0
    @State private var displayedLevel: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Level \(displayedLevel)", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    .contentTransition(.numericText())
                Spacer()
                Text("\(displayedXP) / 100 XP")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(displayedXP) / 100,
                            height: 10
                        )
                }
            }
            .frame(height: 10)
        }
        .onAppear {
            displayedXP = store.xpInCurrentLevel
            displayedLevel = store.level
        }
        .onChange(of: store.totalXP) { oldTotal, newTotal in
            let oldLevel = oldTotal / 100 + 1
            let newLevel = newTotal / 100 + 1

            if newLevel > oldLevel {
                // Phase 1: fill bar to 100%
                withAnimation(.spring(duration: 0.4)) {
                    displayedXP = 100
                }
                // Phase 2: flip to new level at 0%, then fill to remainder
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    displayedLevel = newLevel
                    displayedXP = 0
                    withAnimation(.spring(duration: 0.6)) {
                        displayedXP = store.xpInCurrentLevel
                    }
                }
            } else {
                withAnimation(.spring(duration: 0.4)) {
                    displayedXP = store.xpInCurrentLevel
                }
            }
        }
    }
}

// MARK: - XP Burst Animation

private struct BurstParticle {
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double
}

struct XPBurstView: View {
    let amount: Int
    var message: String = ""
    let onFinished: () -> Void

    @State private var animate = false

    private let particles: [BurstParticle] = {
        let colors: [Color] = [.yellow, .orange, .red, .pink, .purple, .cyan, .green, .mint]
        let count = 18
        return (0..<count).map { i in
            BurstParticle(
                angle: Double(i) / Double(count) * 2 * .pi + Double.random(in: -0.2...0.2),
                distance: CGFloat.random(in: 70...130),
                size: CGFloat.random(in: 6...14),
                color: colors[i % colors.count],
                delay: Double(i) * 0.015
            )
        }
    }()

    private var isNegative: Bool { amount < 0 }

    var body: some View {
        ZStack {
            if isNegative {
                ForEach(particles.indices, id: \.self) { i in
                    let p = particles[i]
                    Text("🔥")
                        .font(.system(size: p.size + 4))
                        .offset(
                            x: animate ? cos(p.angle) * p.distance : 0,
                            y: animate ? sin(p.angle) * p.distance : 0
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: 0.7).delay(p.delay), value: animate)
                }
            } else {
                ForEach(particles.indices, id: \.self) { i in
                    let p = particles[i]
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .offset(
                            x: animate ? cos(p.angle) * p.distance : 0,
                            y: animate ? sin(p.angle) * p.distance : 0
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: 0.7).delay(p.delay), value: animate)
                }
            }

            VStack(spacing: 6) {
                Text(isNegative ? "\(amount) XP" : "+\(amount) XP")
                    .font(.title.bold())
                    .foregroundStyle(isNegative ? .pink : .green)
                    .shadow(color: isNegative ? .red.opacity(0.4) : .green.opacity(0.4), radius: 6)

                if !message.isEmpty {
                    Text(message)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .offset(y: animate ? -40 : 0)
            .opacity(animate ? 0 : 1)
            .animation(.easeIn(duration: 1.0).delay(1.8), value: animate)
        }
        .allowsHitTesting(false)
        .task {
            animate = true
            do {
                try await Task.sleep(for: .seconds(3.2))
                onFinished()
            } catch {
                // Task was cancelled (new burst started) — do nothing
            }
        }
    }
}

// MARK: - Habit Row

struct HabitRow: View {
    let habit: Habit
    let onToggle: () -> Void

    @State private var bounceID = 0

    var body: some View {
        HStack(spacing: 12) {
            Button {
                let wasCompleted = habit.isCompletedToday()
                onToggle()
                if !wasCompleted { bounceID += 1 }
            } label: {
                Image(systemName: habit.isCompletedToday() ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(habit.isCompletedToday() ? habit.color : Color.secondary)
                    .symbolEffect(.bounce, value: bounceID)
                    .animation(.spring(duration: 0.2), value: habit.isCompletedToday())
                    .padding(.vertical, 10)
                    .padding(.trailing, 4)
            }
            .buttonStyle(.borderless)

            Image(systemName: habit.iconName)
                .font(.body)
                .foregroundStyle(habit.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.body)
                if habit.schedule == .hourly {
                    Text("\(habit.completedSlotsToday)/\(habit.todaySlotCount) today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if habit.schedule != .daily {
                    Text(habit.schedule.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if habit.currentStreak > 0 {
                StreakDotsView(streak: habit.currentStreak)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Streak Dots

struct StreakDotsView: View {
    let streak: Int
    private let maxDots = 7

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(streak, maxDots), id: \.self) { _ in
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
            }
            if streak > maxDots {
                Text("+\(streak - maxDots)")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Add Habit Sheet

struct AddHabitSheet: View {
    let onAdd: (String, String, String, RepeatSchedule, Date?, Date?, Int, HabitCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "checkmark"
    @State private var selectedSchedule: RepeatSchedule = .daily
    @State private var hasScheduledTime: Bool = false
    @State private var scheduledTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var hourlyInterval: Int = 2
    @State private var scheduleEndTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now
    @State private var selectedCategory: HabitCategory = .other
    @FocusState private var focused: Bool

    static let colorOptions: [(String, Color)] = [
        ("red", .red), ("orange", .orange), ("yellow", .yellow), ("green", .green),
        ("teal", .teal), ("blue", .blue), ("purple", .purple), ("pink", .pink)
    ]

    static let iconOptions: [String] = [
        "checkmark", "star.fill", "heart.fill", "flame.fill",
        "figure.walk", "dumbbell.fill", "fork.knife", "drop.fill",
        "book.fill", "pencil", "music.note", "moon.fill",
        "sun.max.fill", "leaf.fill", "bicycle", "brain.head.profile"
    ]

    private var selectedColorValue: Color {
        Self.colorOptions.first { $0.0 == selectedColor }?.1 ?? .blue
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit name") {
                    TextField("e.g. Read for 20 minutes", text: $name)
                        .focused($focused)
                }

                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(Self.colorOptions, id: \.0) { colorName, color in
                            Button {
                                selectedColor = colorName
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if selectedColor == colorName {
                                            Circle().stroke(Color.white, lineWidth: 2.5)
                                            Circle().stroke(color, lineWidth: 1).padding(-1.5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(Self.iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.body)
                                    .foregroundStyle(selectedIcon == icon ? selectedColorValue : Color.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? selectedColorValue.opacity(0.15) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(HabitCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Schedule") {
                    Picker("Repeat", selection: $selectedSchedule) {
                        ForEach(RepeatSchedule.allCases, id: \.self) { schedule in
                            Text(schedule.displayName).tag(schedule)
                        }
                    }
                    .pickerStyle(.menu)

                    if selectedSchedule == .hourly {
                        Stepper("Every \(hourlyInterval)h", value: $hourlyInterval, in: 1...12)
                        DatePicker("From", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                        DatePicker("To", selection: $scheduleEndTime, displayedComponents: .hourAndMinute)
                    } else {
                        Toggle("Scheduled Time", isOn: $hasScheduledTime)
                        if hasScheduledTime {
                            DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(selectedColorValue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedIcon)
                                .foregroundStyle(selectedColorValue)
                                .font(.title3)
                        }
                        Text(name.isEmpty ? "Your new habit" : name)
                            .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(
                            name.trimmingCharacters(in: .whitespaces),
                            selectedColor,
                            selectedIcon,
                            selectedSchedule,
                            selectedSchedule == .hourly ? scheduledTime : (hasScheduledTime ? scheduledTime : nil),
                            selectedSchedule == .hourly ? scheduleEndTime : nil,
                            hourlyInterval,
                            selectedCategory
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}

// MARK: - Edit Habit Sheet

struct EditHabitSheet: View {
    let habit: Habit
    let onSave: (String, String, String, RepeatSchedule, Date?, Date?, Int, HabitCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: String
    @State private var selectedIcon: String
    @State private var selectedSchedule: RepeatSchedule
    @State private var hasScheduledTime: Bool
    @State private var scheduledTime: Date
    @State private var hourlyInterval: Int
    @State private var scheduleEndTime: Date
    @State private var selectedCategory: HabitCategory

    init(habit: Habit, onSave: @escaping (String, String, String, RepeatSchedule, Date?, Date?, Int, HabitCategory) -> Void) {
        self.habit = habit
        self.onSave = onSave
        _name = State(initialValue: habit.name)
        _selectedColor = State(initialValue: habit.colorName)
        _selectedIcon = State(initialValue: habit.iconName)
        _selectedSchedule = State(initialValue: habit.schedule)
        _hasScheduledTime = State(initialValue: habit.scheduledTime != nil)
        _scheduledTime = State(initialValue: habit.scheduledTime ?? Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now)
        _hourlyInterval = State(initialValue: habit.hourlyInterval)
        _scheduleEndTime = State(initialValue: habit.scheduleEndTime ?? Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now)
        _selectedCategory = State(initialValue: habit.category)
    }

    private var selectedColorValue: Color {
        AddHabitSheet.colorOptions.first { $0.0 == selectedColor }?.1 ?? .blue
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit name") {
                    TextField("Habit name", text: $name)
                }

                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(AddHabitSheet.colorOptions, id: \.0) { colorName, color in
                            Button {
                                selectedColor = colorName
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if selectedColor == colorName {
                                            Circle().stroke(Color.white, lineWidth: 2.5)
                                            Circle().stroke(color, lineWidth: 1).padding(-1.5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(AddHabitSheet.iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.body)
                                    .foregroundStyle(selectedIcon == icon ? selectedColorValue : Color.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? selectedColorValue.opacity(0.15) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(HabitCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Schedule") {
                    Picker("Repeat", selection: $selectedSchedule) {
                        ForEach(RepeatSchedule.allCases, id: \.self) { schedule in
                            Text(schedule.displayName).tag(schedule)
                        }
                    }
                    .pickerStyle(.menu)

                    if selectedSchedule == .hourly {
                        Stepper("Every \(hourlyInterval)h", value: $hourlyInterval, in: 1...12)
                        DatePicker("From", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                        DatePicker("To", selection: $scheduleEndTime, displayedComponents: .hourAndMinute)
                    } else {
                        Toggle("Scheduled Time", isOn: $hasScheduledTime)
                        if hasScheduledTime {
                            DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                Section("Preview") {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(selectedColorValue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedIcon)
                                .foregroundStyle(selectedColorValue)
                                .font(.title3)
                        }
                        Text(name.isEmpty ? "Your habit" : name)
                            .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            selectedColor,
                            selectedIcon,
                            selectedSchedule,
                            selectedSchedule == .hourly ? scheduledTime : (hasScheduledTime ? scheduledTime : nil),
                            selectedSchedule == .hourly ? scheduleEndTime : nil,
                            hourlyInterval,
                            selectedCategory
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Habit Detail Sheet

struct HabitDetailSheet: View {
    let habit: Habit

    @State private var displayedMonth = Date.now

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

    private var completionThisMonth: (done: Int, total: Int) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)
        let isCurrentMonth = calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
        let total = isCurrentMonth
            ? calendar.component(.day, from: .now)
            : (calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0)
        // Use prefix match to handle both "yyyy-MM-dd" and "yyyy-MM-dd HH" (hourly) formats
        let monthPrefix = String(format: "%04d-%02d", year, month)
        let done = Set(
            habit.completedDates
                .filter { $0.hasPrefix(monthPrefix) }
                .map { String($0.prefix(10)) }  // normalize to "yyyy-MM-dd"
        ).count
        return (done, total)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    habitHeader
                    statsRow
                    calendarSection
                    if !habit.notes.isEmpty {
                        notesSection
                    }
                }
                .padding()
            }
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(habit.notes.sorted { $0.key > $1.key }, id: \.key) { key, note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedNoteKey(key))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(note)
                        .font(.body)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func formattedNoteKey(_ key: String) -> String {
        let parts = key.split(separator: " ")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(parts[0])) else { return key }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        var result = display.string(from: date)
        if parts.count > 1 { result += " at \(parts[1]):00" }
        return result
    }

    private var habitHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(habit.color.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: habit.iconName)
                    .font(.title)
                    .foregroundStyle(habit.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.title2.bold())
                if habit.currentStreak > 0 {
                    Label("\(habit.currentStreak) day streak", systemImage: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        let (done, total) = completionThisMonth
        return HStack(spacing: 0) {
            statCell(value: "\(habit.currentStreak)", label: "Current\nStreak", icon: "flame.fill", color: .orange)
            Divider().frame(height: 44)
            statCell(value: "\(habit.longestStreak)", label: "Longest\nStreak", icon: "trophy.fill", color: .yellow)
            Divider().frame(height: 44)
            statCell(value: "\(done)/\(total)", label: "This\nMonth", icon: "calendar", color: habit.color)
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var calendarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
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
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(dayHeaders.indices, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let ds = Habit.dateString(for: date)
                        let completed = habit.completedDates.contains { $0 == ds || $0.hasPrefix(ds + " ") }
                        let isToday = ds == Habit.dateString(for: .now)
                        let hasNote = habit.notes.keys.contains { $0 == ds || $0.hasPrefix(ds + " ") }
                        HabitDayCell(
                            date: date,
                            completed: completed,
                            isToday: isToday,
                            color: habit.color,
                            hasNote: hasNote
                        )
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }
}

// MARK: - Habit Day Cell

struct HabitDayCell: View {
    let date: Date
    let completed: Bool
    let isToday: Bool
    let color: Color
    var hasNote: Bool = false

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    var body: some View {
        ZStack {
            Text(dayNumber)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(completed ? .white : (isToday ? color : .secondary))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(completed ? color.opacity(0.85) : (isToday ? color.opacity(0.12) : Color.clear))
                )
            if hasNote {
                VStack {
                    Spacer()
                    Circle()
                        .fill(completed ? .white.opacity(0.8) : color)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 4)
                }
                .frame(height: 44)
            }
        }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(completed && isToday ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
            )
    }
}

// MARK: - Habit Note Sheet

struct HabitNoteSheet: View {
    let habit: Habit
    let dateKey: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("What happened? No pressure.", text: $noteText, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focused)
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Add a note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(noteText)
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220)])
        .onAppear {
            noteText = habit.notes[dateKey] ?? ""
            focused = true
        }
    }
}

// MARK: - Archived Habits View

struct ArchivedHabitsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHabit: Habit? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.archivedHabits.isEmpty {
                    ContentUnavailableView(
                        "No archived habits",
                        systemImage: "archivebox",
                        description: Text("Long press a habit to archive it")
                    )
                } else {
                    List {
                        ForEach(store.archivedHabits) { habit in
                            Button {
                                selectedHabit = habit
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: habit.iconName)
                                        .foregroundStyle(habit.color)
                                        .frame(width: 24)
                                    Text(habit.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Button {
                                        store.unarchive(habit)
                                    } label: {
                                        Image(systemName: "arrow.uturn.left")
                                            .foregroundStyle(.green)
                                    }
                                    .buttonStyle(.borderless)
                                    Button(role: .destructive) {
                                        store.delete(habit)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .sheet(item: $selectedHabit) { habit in
                        HabitDetailSheet(habit: habit)
                    }
                }
            }
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reminders Sheet

struct RemindersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HabitStore.self) private var habitStore

    @AppStorage("habitsReminderEnabled") private var habitsEnabled = false
    @AppStorage("habitsReminderSeconds") private var habitsSeconds: Double = 9 * 3600
    @AppStorage("moodReminderEnabled") private var moodEnabled = false
    @AppStorage("moodReminderSeconds") private var moodSeconds: Double = 21 * 3600
    @AppStorage("colorSchemeRaw") private var colorSchemeRaw: String = "system"

    private var habitsTime: Binding<Date> { timeBinding($habitsSeconds) }
    private var moodTime: Binding<Date> { timeBinding($moodSeconds) }

    private func timeBinding(_ seconds: Binding<Double>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(seconds.wrappedValue) },
            set: { seconds.wrappedValue = $0.timeIntervalSince(Calendar.current.startOfDay(for: $0)) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $colorSchemeRaw) {
                        Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Light", systemImage: "sun.max.fill").tag("light")
                        Label("Dark", systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Habits reminder", isOn: $habitsEnabled)
                    if habitsEnabled {
                        DatePicker("Time", selection: habitsTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Habits")
                } footer: {
                    Text("A gentle nudge to check off your habits. Very gentle.")
                }

                Section {
                    Toggle("Mood reminder", isOn: $moodEnabled)
                    if moodEnabled {
                        DatePicker("Time", selection: moodTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Mood")
                } footer: {
                    Text("Because you'll forget otherwise. We believe in you.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: habitsEnabled) { _, new in
            if new { NotificationManager.shared.requestPermission() }
            rescheduleAll()
        }
        .onChange(of: habitsSeconds) { _, _ in rescheduleAll() }
        .onChange(of: moodEnabled) { _, new in
            if new { NotificationManager.shared.requestPermission() }
            rescheduleAll()
        }
        .onChange(of: moodSeconds) { _, _ in rescheduleAll() }
    }

    private func rescheduleAll() {
        let nm = NotificationManager.shared
        let allHabits = habitStore.habits + habitStore.notDueHabits + habitStore.archivedHabits
        nm.rescheduleHabitNotifications(allHabits: allHabits)

        if moodEnabled {
            let c = Calendar.current.dateComponents([.hour, .minute], from: moodTime.wrappedValue)
            nm.scheduleMoodReminder(hour: c.hour ?? 21, minute: c.minute ?? 0)
        } else {
            nm.cancelMoodReminder()
        }
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Habit.self, MoodEntry.self, AppState.self], inMemory: true)
}
