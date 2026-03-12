import SwiftData
import Foundation

// MARK: - Schema V1: Original (Habit without colorName/iconName/sortOrder)

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [AppSchemaV1.Habit.self, MoodEntry.self, AppState.self]

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

// MARK: - Schema V2: Habit with colorName, iconName, sortOrder

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [AppSchemaV2.Habit.self, MoodEntry.self, AppState.self]

    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var completedDates: [String] = []
        var colorName: String = "blue"
        var iconName: String = "checkmark"
        var sortOrder: Int = 0

        init(name: String) {
            self.id = UUID()
            self.name = name
            self.completedDates = []
        }
    }
}

// MARK: - Schema V3: adds isArchived

enum AppSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] = [AppSchemaV3.Habit.self, MoodEntry.self, AppState.self]

    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var completedDates: [String] = []
        var colorName: String = "blue"
        var iconName: String = "checkmark"
        var sortOrder: Int = 0
        var isArchived: Bool = false

        init(name: String) {
            self.id = UUID()
            self.name = name
            self.completedDates = []
        }
    }
}

// MARK: - Schema V4: Adds scheduleRaw, scheduledTime

enum AppSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] = [AppSchemaV4.Habit.self, MoodEntry.self, AppState.self]

    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var completedDates: [String] = []
        var colorName: String = "blue"
        var iconName: String = "checkmark"
        var sortOrder: Int = 0
        var isArchived: Bool = false
        var scheduleRaw: String = "daily"
        var scheduledTime: Date? = nil

        init(name: String) {
            self.id = UUID()
            self.name = name
            self.completedDates = []
        }
    }
}

// MARK: - Schema V5: Adds hourlyInterval, scheduleEndTime

enum AppSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] = [Habit.self, MoodEntry.self, AppState.self]
}

// MARK: - Schema V6: Current (adds categoryRaw)

enum AppSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)
    static var models: [any PersistentModel.Type] = [Habit.self, MoodEntry.self, AppState.self]
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self, AppSchemaV4.self, AppSchemaV5.self, AppSchemaV6.self]
    static var stages: [MigrationStage] = [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6]

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

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AppSchemaV2.self,
        toVersion: AppSchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: AppSchemaV3.self,
        toVersion: AppSchemaV4.self
    )

    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: AppSchemaV4.self,
        toVersion: AppSchemaV5.self
    )

    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: AppSchemaV5.self,
        toVersion: AppSchemaV6.self
    )
}
