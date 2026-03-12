import SwiftUI

struct StatsView: View {
    @Environment(HabitStore.self) private var habitStore
    @Environment(MoodStore.self) private var moodStore

    private var allHabits: [Habit] { habitStore.habits + habitStore.notDueHabits }

    private var totalCompletions: Int {
        allHabits.reduce(0) { $0 + $1.completedDates.count }
    }

    private var longestEverStreak: Int {
        allHabits.map { $0.longestStreak }.max() ?? 0
    }

    private var doneTodayCount: Int {
        allHabits.filter { $0.isCompletedToday() }.count
    }

    private var topHabits: [Habit] {
        Array(allHabits.filter { $0.currentStreak > 0 }
            .sorted { $0.currentStreak > $1.currentStreak }
            .prefix(5))
    }

    private var moodDistribution: [(MoodLevel, Int)] {
        MoodLevel.allCases.map { level in
            (level, moodStore.entries.filter { $0.mood == level }.count)
        }
    }

    private var averageMoodLabel: String {
        guard !moodStore.entries.isEmpty else { return "—" }
        let avg = Double(moodStore.entries.reduce(0) { $0 + $1.mood.rawValue }) / Double(moodStore.entries.count)
        let rounded = Int(avg.rounded())
        return MoodLevel(rawValue: rounded)?.label ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    levelCard
                    habitsGrid
                    if !topHabits.isEmpty { topStreaksSection }
                    if !moodStore.entries.isEmpty { moodSection }
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Level Card

    private var levelCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(habitStore.level)")
                        .font(.largeTitle.bold())
                    Text("\(habitStore.totalXP) XP total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
                    .symbolRenderingMode(.hierarchical)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.green)
                        .frame(width: geo.size.width * Double(habitStore.xpInCurrentLevel) / 100)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(habitStore.xpInCurrentLevel) / 100 XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Next: Level \(habitStore.level + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Habits Grid

    private var habitsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habits")
                .font(.headline)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Active", value: "\(allHabits.count)", icon: "checkmark.circle.fill", color: .green)
                StatCard(title: "Done today", value: "\(doneTodayCount)/\(allHabits.count)", icon: "sun.max.fill", color: .orange)
                StatCard(title: "Total done", value: "\(totalCompletions)", icon: "trophy.fill", color: .yellow)
                StatCard(title: "Best streak", value: "\(longestEverStreak)d", icon: "flame.fill", color: .red)
            }
        }
    }

    // MARK: - Top Streaks

    private var topStreaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Streaks")
                .font(.headline)
                .padding(.horizontal, 2)

            VStack(spacing: 8) {
                ForEach(Array(topHabits.enumerated()), id: \.element.id) { index, habit in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 16)

                        Image(systemName: habit.iconName)
                            .font(.body)
                            .foregroundStyle(habit.color)
                            .frame(width: 22)

                        Text(habit.name)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(habit.currentStreak)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood")
                .font(.headline)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Days logged", value: "\(moodStore.entries.count)", icon: "face.smiling.fill", color: .blue)
                StatCard(title: "Average mood", value: averageMoodLabel, icon: "chart.line.uptrend.xyaxis", color: .purple)
            }

            moodDistributionChart
        }
    }

    private var moodDistributionChart: some View {
        let maxCount = moodDistribution.map { $0.1 }.max() ?? 1

        return VStack(alignment: .leading, spacing: 10) {
            Text("Distribution")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(moodDistribution, id: \.0) { level, count in
                    VStack(spacing: 4) {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(level.color.gradient)
                            .frame(height: maxCount > 0 ? max(4, 64 * Double(count) / Double(maxCount)) : 4)

                        Image(level.imageName)
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(height: 32)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .animation(.spring(duration: 0.4), value: moodDistribution.map { $0.1 })
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)

            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
