# ProbablyProductive

> *Maybe productive. Definitely trying.*

A SwiftUI app for iOS, iPadOS, and macOS that helps you build habits and track your mood — without taking itself too seriously.

## Features

### Habits
- Add, edit, archive, and reorder habits
- Flexible repeat schedules: daily, weekdays, weekends, weekly, hourly, and more
- Hourly habits with configurable interval and time window
- One-tap completion toggle with XP animations (+10 XP / -10 XP)
- "Later" section for habits not due yet — sorted by next due time
- Streak counter visualized as orange dots
- 28-day streak calendar + stats in habit detail view
- Sarcastic daily progress messages

### Mood
- 5-level emoji mood picker (Very Bad → Great)
- Optional notes per entry
- Full history with search
- Monthly XP bonuses for consistent logging

### Calendar
- Unified monthly calendar showing both mood and habit progress per day
- Tap any day to see details

### Progression System
- XP bar and level shown at the top of Habits
- Animated XP burst on completions and milestones
- Humorous milestone messages

## Tech Stack

- **SwiftUI** — UI framework
- **SwiftData** — local persistence (V1→V5 migration, ready for CloudKit)
- **SwiftCharts** — mood chart
- **Swift 5.0**
- **Targets** — iOS 26.2+, macOS 26.2+

## Requirements

- Xcode 16+
- iOS 26.2 / macOS 26.2 or later

## Getting Started

1. Clone the repository
2. Open `probably-productive.xcodeproj` in Xcode
3. Select a simulator or device
4. Build and run (`⌘R`)

## License

Copyright © 2026 MontyNau. All rights reserved. See [LICENSE](LICENSE) for details.
