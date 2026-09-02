import SwiftUI
import SwiftData

@main
struct BizNoteApp: App {
    static let cloudKitContainerIdentifier = "iCloud.com.fakuku.biznote"

    let container: ModelContainer
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    init() {
        CloudSyncSettings.registerDefaults()
        CloudSyncSettings.applyBackupPreference()

        do {
            let schema = Schema([
                Note.self,
                BusinessCard.self,
                ExhibitionPreset.self,
                CustomCategory.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: CloudSyncSettings.cloudKitDatabase(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("\(String(localized: "app.modelContainerFailure")): \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, effectiveLocale)
        }
        .modelContainer(container)
    }

    private var effectiveLocale: Locale {
        switch appLanguage {
        case "ko": return Locale(identifier: "ko")
        case "en": return Locale(identifier: "en")
        default:   return .autoupdatingCurrent
        }
    }
}
