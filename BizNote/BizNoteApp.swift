import SwiftUI
import SwiftData

@main
struct BizNoteApp: App {
    private static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    private static let cloudKitContainerIdentifier = "iCloud.com.biznote.app"

    let container: ModelContainer
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    init() {
        do {
            let schema = Schema([
                Note.self,
                BusinessCard.self,
                ExhibitionPreset.self,
                CustomCategory.self
            ])
            let iCloudSyncEnabled = UserDefaults.standard.object(forKey: Self.iCloudSyncEnabledKey) as? Bool ?? true
            let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = iCloudSyncEnabled
                ? .private(Self.cloudKitContainerIdentifier)
                : .none
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKitDatabase
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
