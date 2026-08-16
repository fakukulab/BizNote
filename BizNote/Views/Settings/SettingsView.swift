import SwiftUI

struct SettingsView: View {
    @State private var showExporter: Bool = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $iCloudSyncEnabled) {
                    Label(String(localized: "settings.iCloudSync"), systemImage: "icloud")
                }
                Text(String(localized: "settings.iCloudSyncHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.noteCategories")) {
                NavigationLink {
                    NoteCategoriesSettingsView()
                } label: {
                    Label(String(localized: "settings.noteCategories"),
                          systemImage: "folder.badge.gearshape")
                }
            }

            Section(String(localized: "action.export")) {
                Button {
                    showExporter = true
                } label: {
                    Label(String(localized: "export.title"), systemImage: "square.and.arrow.up")
                }
            }

            Section(String(localized: "settings.about")) {
                LabeledContent(String(localized: "settings.version")) {
                    Text(appVersion)
                }
            }
        }
        .navigationTitle(String(localized: "nav.settings"))
        .sheet(isPresented: $showExporter) {
            NavigationStack { ExportView() }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
