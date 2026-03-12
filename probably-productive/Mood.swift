import Foundation
import SwiftData
import SwiftUI

enum MoodLevel: Int, Codable, CaseIterable, Identifiable {
    case veryBad = 1, bad, neutral, good, great

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .veryBad: "😢"
        case .bad: "😟"
        case .neutral: "😐"
        case .good: "🙂"
        case .great: "😄"
        }
    }

    var imageName: String {
        switch self {
        case .veryBad: "mood_very_bad"
        case .bad: "mood_bad"
        case .neutral: "mood_neutral"
        case .good: "mood_good"
        case .great: "mood_great"
        }
    }

    var label: String {
        switch self {
        case .veryBad: "Very Bad"
        case .bad: "Bad"
        case .neutral: "Neutral"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var color: Color {
        switch self {
        case .veryBad: .red
        case .bad: .orange
        case .neutral: .yellow
        case .good: .mint
        case .great: .green
        }
    }
}

@Model
class MoodEntry {
    var id: UUID
    var date: String // "yyyy-MM-dd"
    var moodRaw: Int  // MoodLevel stored as Int
    var note: String

    init(date: String = MoodEntry.dateString(for: .now), mood: MoodLevel, note: String = "") {
        self.id = UUID()
        self.date = date
        self.moodRaw = mood.rawValue
        self.note = note
    }

    var mood: MoodLevel {
        get { MoodLevel(rawValue: moodRaw) ?? .neutral }
        set { moodRaw = newValue.rawValue }
    }

    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var displayDate: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let d = parser.date(from: date) else { return date }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: d)
    }
}
