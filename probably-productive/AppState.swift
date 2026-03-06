import Foundation
import SwiftData

@Model
class AppState {
    var totalXP: Int = 0
    var paidBonusesData: Data = Data() // JSON encoded [String: [Int]]

    init() {}

    var paidBonuses: [String: [Int]] {
        get {
            (try? JSONDecoder().decode([String: [Int]].self, from: paidBonusesData)) ?? [:]
        }
        set {
            paidBonusesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}
