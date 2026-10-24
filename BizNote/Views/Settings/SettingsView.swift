import SwiftUI

struct SettingsView: View {
    @State private var showExporter: Bool = false

    var body: some View {
        Form {
            Section(String(localized: "settings.noteCategories")) {
                NavigationLink(value: SettingsDestination.noteCategories) {
                    Label(String(localized: "settings.noteCategories"),
                          systemImage: "folder.badge.gearshape")
                }
            }

            Section(String(localized: "settings.icloud.title")) {
                NavigationLink(value: SettingsDestination.iCloud) {
                    Label(String(localized: "settings.icloud.title"), systemImage: "icloud")
                }
            }

            Section(String(localized: "settings.integration.title", defaultValue: "Apple 앱 연동")) {
                NavigationLink(value: SettingsDestination.integration) {
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

            if AdService.shared.isPrivacyOptionsRequired {
                Section {
                    Button {
                        Task { await AdService.shared.presentPrivacyOptions() }
                    } label: {
                        Label(String(localized: "settings.adPrivacyOptions", defaultValue: "광고 개인정보 설정"), systemImage: "hand.raised")
                    }
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
        .navigationDestination(for: SettingsDestination.self) { destination in
            switch destination {
            case .noteCategories:
                NoteCategoriesSettingsView()
            case .iCloud:
                CloudSyncSettingsView()
            case .integration:
                IntegrationSettingsView()
            }
        }
        .sheet(isPresented: $showExporter) {
            NavigationStack { ExportView() }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.25"
    }

    private var privacyPolicyURL: URL? {
        URL(string: "https://fakukulab.github.io/BizNote/privacy-policy/")
    }

    private var supportURL: URL? {
        URL(string: "https://fakukulab.github.io/BizNote/support/")
    }
}

private enum SettingsDestination: Hashable {
    case noteCategories
    case iCloud
    case integration
}

#Preview {
    NavigationStack { SettingsView() }
}
