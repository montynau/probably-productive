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
    @State private var showingBurst = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                XPHeaderView(store: store)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                List {
                    ForEach(store.habits) { habit in
                        HabitRow(habit: habit) {
                            let earned = store.toggle(habit)
                            if earned { showingBurst = true }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitSheet { name in
                    store.add(name: name)
                }
            }
            .overlay {
                if store.habits.isEmpty {
                    ContentUnavailableView(
                        "No habits yet",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + to add your first habit")
                    )
                }
            }
        }
        .overlay {
            if showingBurst {
                XPBurstView(amount: 10) {
                    showingBurst = false
                }
            }
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
                    .background(.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
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
                                colors: [.yellow, .orange],
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

    var body: some View {
        ZStack {
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

            VStack(spacing: 6) {
                Text("+\(amount) XP")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 6)

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
        .onAppear {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                onFinished()
            }
        }
    }
}

// MARK: - Habit Row

struct HabitRow: View {
    let habit: Habit
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: habit.isCompletedToday() ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(habit.isCompletedToday() ? .green : .secondary)
                    .animation(.spring(duration: 0.2), value: habit.isCompletedToday())
            }
            .buttonStyle(.plain)

            Text(habit.name)
                .font(.body)

            Spacer()

            if habit.currentStreak > 0 {
                Label("\(habit.currentStreak)", systemImage: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Habit Sheet

struct AddHabitSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Read for 20 minutes", text: $name)
                        .focused($focused)
                } header: {
                    Text("Habit name")
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
                        onAdd(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Habit.self, MoodEntry.self, AppState.self], inMemory: true)
}
