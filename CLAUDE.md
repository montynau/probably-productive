# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**probably-productive** is a SwiftUI multiplatform app (iOS, iPadOS, macOS) built with Xcode. It targets deployment on iOS/macOS 26.2+ and uses Swift 5.0.

- Bundle ID: `montynauorg.probably-productive`
- Supported platforms: iPhone, iPad, Mac (TARGETED_DEVICE_FAMILY = 1,2,7)

## Building & Running

Build and run via Xcode — open `probably-productive.xcodeproj`.

To build from the command line:
```bash
xcodebuild -project probably-productive.xcodeproj -scheme probably-productive -destination 'platform=iOS Simulator,name=iPhone 16' build
```

To run tests:
```bash
xcodebuild -project probably-productive.xcodeproj -scheme probably-productive -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Architecture

The app has two main features accessible via a `TabView`: **Habits** and **Mood**.

### File Structure

- `probably_productiveApp.swift` — `@main` entry point, wraps `ContentView` in a `WindowGroup`
- `ContentView.swift` — Root `TabView`; contains `HabitsView`, `XPHeaderView`, `XPBurstView`, `HabitRow`, `AddHabitSheet`
- `Habit.swift` — `Habit` model (id, name, completedDates, streak logic)
- `HabitStore.swift` — `ObservableObject` managing habits and XP; injected app-wide as `@EnvironmentObject`
- `Mood.swift` — `MoodLevel` enum (5 levels with emoji, label, color) and `MoodEntry` model
- `MoodStore.swift` — `ObservableObject` managing mood entries and monthly XP bonuses
- `MoodView.swift` — `MoodView`, `MoodWeekView`, `MoodMonthView`, `MoodDayCell`

The app uses `PBXFileSystemSynchronizedRootGroup`, meaning new Swift files added to the `probably-productive/` folder are automatically included in the build without manually updating the `.xcodeproj`.

### State Management

- `HabitStore` and `MoodStore` are `@Observable` classes created in `RootView` (which has access to `ModelContext`) and shared via `.environment()` — views access them via `@Environment(HabitStore.self)` / `@Environment(MoodStore.self)`
- Both stores share the same `AppState` instance (fetched or created in `RootView`)

### Persistence — SwiftData

All data stored in SwiftData (SQLite). No `UserDefaults` used anywhere.

| Model | Contents |
|---|---|
| `Habit` | id, name, completedDates `[String]` |
| `MoodEntry` | id, date `String`, moodRaw `Int`, note `String` |
| `AppState` | totalXP `Int`, paidBonusesData `Data` (JSON encoded `[String: [Int]]`) |

`ModelContainer` is set up in `probably_productiveApp` with all three models. `RootView` fetches or creates the single `AppState` record and injects it into both stores.

**CloudKit migration (future):** one line change:
```swift
// Current:
.modelContainer(for: [Habit.self, MoodEntry.self, AppState.self])
// With CloudKit:
.modelContainer(for: [Habit.self, MoodEntry.self, AppState.self], cloudKitDatabase: .automatic)
```

### XP & Leveling System

- **Habits**: completing a habit awards +10 XP; uncompleting removes it
- **Mood (monthly bonus)**: logged days in current calendar month unlock one-time bonuses, scaled dynamically to the actual number of days in the month (~33%, ~67%, ~83%, 100%):
  - ~33% of month → +20 XP
  - ~67% of month → +75 XP
  - ~83% of month → +150 XP
  - 100% of month → +250 XP (total always +495 XP regardless of month length)
- Thresholds computed via `thresholds(for: month)` each time — never cached — so February (28d) and March (31d) scale correctly
- Bonuses tracked in `AppState.paidBonuses` per month key ("yyyy-MM") to prevent double-paying
- `MoodStore.logMood()` returns `(xp: Int, message: String)` — message describes the milestone (e.g. "20 days logged this month!"); view calls `habitStore.addXP()` with the result
- Level = `totalXP / 100 + 1`; XP bar shows progress within current level

### XP Animations

- **`XPBurstView`** — particle burst with floating "+X XP" text and optional `message` label (Capsule pill style); text appears immediately, starts fading after 1.8s delay over 1.0s; `onFinished` called at 3.2s
- **`XPHeaderView`** — uses local `displayedXP` / `displayedLevel` state instead of reading store directly, enabling two-phase level-up animation: bar fills to 100% → flips to new level at 0% → animates to remainder; level number and XP count use `.contentTransition(.numericText())`
- **Mood XP toast** — when a mood bonus is earned, `XPHeaderView` slides in from the top of the screen (`.regularMaterial` background, `RoundedRectangle`); XP is added 0.3s after toast appears so the bar animates from old value; toast slides out at 3.2s (just after burst text disappears)

### Habits Feature

- Add/delete habits
- One-tap completion toggle per day
- Streak counter (consecutive days ending today or yesterday)
- XP burst particle animation on completion (+10 XP, no message)

### Mood Feature

- **Today section**: 5-emoji mood picker (Very Bad → Great)
  - One tap = instant save (no note)
  - Optional note field: tap emoji to select (highlighted), then "Log mood" button saves
  - Edit button to change today's mood or note
- **Calendar toggle** (`Week | Month`):
  - Week: 7-day row with emoji per day
  - Month: full grid calendar with month navigation (`< >`), tap a day to see entry details below
- **History section**: chronological list of all entries, searchable by note text or mood label; header shows monthly bonus progress (e.g. "12/20 days · +75 XP")
- **Test XP button** in toolbar (for development) — simulates a +75 XP bonus with full animation; remove before release


## Communication

- Conversations with the user: Lithuanian
- Code and code comments: English

## CLAUDE.md Maintenance

After any session where architecture, features, or conventions change — update this file without waiting to be asked. Keep it concise and accurate.
