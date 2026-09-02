import SwiftUI

struct SettingsView: View {
    @State private var showExporter: Bool = false

    var body: some View {
        Form {
            Section(String(localized: "settings.noteCategories")) {
                NavigationLink {
                    NoteCategoriesSettingsView()
                } label: {
                    Label(String(localized: "settings.noteCategories"),
                          systemImage: "folder.badge.gearshape")
                }
            }

            Section(String(localized: "settings.icloud.title")) {
                NavigationLink {
                    CloudSyncSettingsView()
                } label: {
                    Label(String(localized: "settings.icloud.title"), systemImage: "icloud")
                }
            }

            Section(String(localized: "settings.integration.title", defaultValue: "Apple 앱 연동")) {
                NavigationLink {
                    IntegrationSettingsView()
                } label: {
                    Label(String(localized: "settings.integration.title", defaultValue: "Apple 앱 연동"), systemImage: "app.connected.to.app.below.fill")
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
