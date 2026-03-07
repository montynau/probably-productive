import SwiftData
import Foundation

// MARK: - Schema V1: Original (Habit without colorName/iconName/sortOrder)

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [Habit.self, MoodEntry.self, AppState.self]

    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var completedDates: [String] = []

        init(name: String) {
            self.id = UUID()
            self.name = name
            self.completedDates = []
        }
    }
}

// MARK: - Schema V2: Current (Habit with colorName, iconName, sortOrder)

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [Habit.self, MoodEntry.self, AppState.self]
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [AppSchemaV1.self, AppSchemaV2.self]
    static var stages: [MigrationStage] = [migrateV1toV2]

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let habits = try context.fetch(FetchDescriptor<Habit>())
            for (index, habit) in habits.enumerated() {
                habit.colorName = "blue"
                habit.iconName = "checkmark"
                habit.sortOrder = index
            }
            try context.save()
        }
    )
}
