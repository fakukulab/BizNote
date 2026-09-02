import SwiftUI

struct CloudSyncSettingsView: View {
    @AppStorage(CloudSyncSettings.syncEnabledKey) private var syncEnabled: Bool = true
    @AppStorage(CloudSyncSettings.backupEnabledKey) private var backupEnabled: Bool = true
    @State private var showRestartNotice: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $syncEnabled) {
                    Label(String(localized: "settings.icloud.sync"), systemImage: "icloud")
                }
            } footer: {
                Text(String(localized: "settings.icloud.sync.footer"))
            }

            Section {
                Toggle(isOn: $backupEnabled) {
                    Label(String(localized: "settings.icloud.backup"), systemImage: "externaldrive.badge.icloud")
                }
            } footer: {
                Text(String(localized: "settings.icloud.backup.footer"))
            }
        }
        .navigationTitle(String(localized: "settings.icloud.title"))
        .onChange(of: syncEnabled) { _, _ in
            showRestartNotice = true
        }
        .onChange(of: backupEnabled) { _, _ in
            CloudSyncSettings.applyBackupPreference()
        }
        .alert(String(localized: "settings.icloud.restart.title"), isPresented: $showRestartNotice) {
            Button(String(localized: "action.done"), role: .cancel) { }
        } message: {
            Text(String(localized: "settings.icloud.restart.message"))
        }
    }
}

#Preview {
    NavigationStack { CloudSyncSettingsView() }
}
