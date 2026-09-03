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

                if let privacyPolicyURL {
                    Link(destination: privacyPolicyURL) {
                        Label(String(localized: "settings.privacyPolicy"), systemImage: "hand.raised")
                    }
                }

                if let supportURL {
                    Link(destination: supportURL) {
                        Label(String(localized: "settings.support"), systemImage: "questionmark.circle")
                    }
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

    private var privacyPolicyURL: URL? {
        URL(string: "https://fakukulab.github.io/BizNote/privacy-policy/")
    }

    private var supportURL: URL? {
        URL(string: "https://fakukulab.github.io/BizNote/support/")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
