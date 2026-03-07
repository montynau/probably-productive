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
    @State private var burstAmount: Int? = nil
    @State private var burstID = UUID()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                XPHeaderView(store: store)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                HabitsStatsBar(store: store)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                List {
                    ForEach(store.habits) { habit in
                        HabitRow(habit: habit) {
                            let earned = store.toggle(habit)
                            burstAmount = earned ? 10 : -10
                            burstID = UUID()
                        } onTap: {
                            selectedHabit = habit
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingHabit = habit
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.delete(habit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                store.archive(habit)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                    }
                    .onMove(perform: store.move)
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddHabit = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                if !store.archivedHabits.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            showingArchived = true
                        } label: {
                            Label("Archived", systemImage: "archivebox")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitSheet { name, colorName, iconName in
                    store.add(name: name, colorName: colorName, iconName: iconName)
                }
            }
            .sheet(item: $editingHabit) { habit in
                EditHabitSheet(habit: habit) { name, colorName, iconName in
                    store.update(habit, name: name, colorName: colorName, iconName: iconName)
                }
            }
            .sheet(item: $selectedHabit) { habit in
                HabitDetailSheet(habit: habit)
            }
            .sheet(isPresented: $showingArchived) {
                ArchivedHabitsView()
            }
            .overlay {
                if store.habits.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + and pretend you'll actually do it")
                    )
                }
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

    private var completedToday: Int {
        store.habits.filter { $0.isCompletedToday() }.count
    }
    private var total: Int { store.habits.count }
    private var bestStreak: Int { store.habits.map { $0.currentStreak }.max() ?? 0 }
    private var bestLongest: Int { store.habits.map { $0.longestStreak }.max() ?? 0 }

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
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: habit.isCompletedToday() ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(habit.isCompletedToday() ? habit.color : Color.secondary)
                    .animation(.spring(duration: 0.2), value: habit.isCompletedToday())
            }
            .buttonStyle(.plain)

            Image(systemName: habit.iconName)
                .font(.body)
                .foregroundStyle(habit.color)
                .frame(width: 20)

            Text(habit.name)
                .font(.body)

            Spacer()

            if habit.currentStreak > 0 {
                StreakDotsView(streak: habit.currentStreak)
            }

            Button(action: onTap) {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
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
    let onAdd: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "checkmark"
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
                        onAdd(name, selectedColor, selectedIcon)
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
    let onSave: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: String
    @State private var selectedIcon: String

    init(habit: Habit, onSave: @escaping (String, String, String) -> Void) {
        self.habit = habit
        self.onSave = onSave
        _name = State(initialValue: habit.name)
        _selectedColor = State(initialValue: habit.colorName)
        _selectedIcon = State(initialValue: habit.iconName)
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
                        onSave(name, selectedColor, selectedIcon)
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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var last28Days: [Date] {
        (0..<28).map { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
        }
    }

    private var completionThisMonth: (done: Int, total: Int) {
        let calendar = Calendar.current
        let now = Date.now
        let daysElapsed = calendar.component(.day, from: now)
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let done = habit.completedDates.filter { ds in
            guard let date = formatter.date(from: ds) else { return false }
            return calendar.component(.year, from: date) == year &&
                   calendar.component(.month, from: date) == month
        }.count
        return (done, daysElapsed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    habitHeader
                    statsRow
                    calendarSection
                }
                .padding()
            }
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
        }
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 28 Days")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(last28Days.enumerated()), id: \.offset) { _, date in
                    let ds = Habit.dateString(for: date)
                    let completed = habit.completedDates.contains(ds)
                    let isToday = ds == Habit.dateString(for: .now)
                    Circle()
                        .fill(completed ? AnyShapeStyle(habit.color) : AnyShapeStyle(.quaternary.opacity(0.5)))
                        .frame(height: 36)
                        .padding(isToday ? 2 : 0)
                        .background {
                            if isToday {
                                Circle().stroke(habit.color, lineWidth: 2)
                            }
                        }
                }
            }

            HStack(spacing: 8) {
                Circle().fill(habit.color).frame(width: 10, height: 10)
                Text("Completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Circle().fill(.quaternary).frame(width: 10, height: 10)
                Text("Missed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Archived Habits View

struct ArchivedHabitsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.archivedHabits.isEmpty {
                    ContentUnavailableView(
                        "No archived habits",
                        systemImage: "archivebox",
                        description: Text("Swipe left on a habit to archive it")
                    )
                } else {
                    List {
                        ForEach(store.archivedHabits) { habit in
                            HStack(spacing: 12) {
                                Image(systemName: habit.iconName)
                                    .foregroundStyle(habit.color)
                                    .frame(width: 24)
                                Text(habit.name)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.unarchive(habit)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.left")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(habit)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
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

#Preview {
    RootView()
        .modelContainer(for: [Habit.self, MoodEntry.self, AppState.self], inMemory: true)
}
