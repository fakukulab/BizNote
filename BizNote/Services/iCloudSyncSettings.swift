import Foundation
import SwiftData

enum CloudSyncSettings {
    static let syncEnabledKey = "iCloudSyncEnabled"
    static let backupEnabledKey = "iCloudBackupEnabled"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            syncEnabledKey: true,
            backupEnabledKey: true
        ])
    }

    static var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: syncEnabledKey)
    }

    static var isBackupEnabled: Bool {
        UserDefaults.standard.bool(forKey: backupEnabledKey)
    }

    static func cloudKitDatabase(containerIdentifier: String) -> ModelConfiguration.CloudKitDatabase {
        isSyncEnabled ? .private(containerIdentifier) : .none
    }

    static func applyBackupPreference() {
        let shouldExcludeFromBackup = !isBackupEnabled
        let fileManager = FileManager.default
        let directories = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ]

        for directory in directories.compactMap({ $0 }) {
            var url = directory
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                var values = URLResourceValues()
                values.isExcludedFromBackup = shouldExcludeFromBackup
                try url.setResourceValues(values)
            } catch {
                assertionFailure("Failed to update iCloud backup preference: \(error.localizedDescription)")
            }
        }
    }
}
