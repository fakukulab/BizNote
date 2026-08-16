import SwiftUI
import SwiftData

enum SidebarDestination: Hashable {
    case category(NoteCategorySelection)
    case exhibitions
    case businessCards
    case settings
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadRoot()
        } else {
            iPhoneRoot()
        }
    }
}

private struct iPadRoot: View {
    @State private var selection: SidebarDestination? = .category(.builtin(.workLog))

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .category(let category):
                NoteListView(category: category)
            case .exhibitions:
                NavigationStack { ExhibitionPresetsView() }
            case .businessCards:
                NavigationStack { BusinessCardListView() }
            case .settings:
                NavigationStack { SettingsView() }
            case nil:
                NoteListView(category: nil)
            }
        }
    }
}

private struct iPhoneRoot: View {
    var body: some View {
        TabView {
            NoteListView(category: nil)
                .tabItem {
                    Label(String(localized: "nav.notes"), systemImage: "note.text")
                }

            NavigationStack {
                ExhibitionPresetsView()
            }
            .tabItem {
                Label(String(localized: "nav.exhibitions"), systemImage: "building.columns")
            }

            NavigationStack {
                BusinessCardListView()
            }
            .tabItem {
                Label(String(localized: "nav.businessCards"), systemImage: "person.crop.rectangle")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(String(localized: "nav.settings"), systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Note.self, BusinessCard.self], inMemory: true)
}
