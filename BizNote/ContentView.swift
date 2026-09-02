import SwiftUI
import SwiftData

enum SmartFolder: String, CaseIterable, Hashable, Identifiable {
    case allNotes
    case favorites
    case recent7Days

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .allNotes: return String(localized: "smartFolder.allNotes")
        case .favorites: return String(localized: "smartFolder.favorites")
        case .recent7Days: return String(localized: "smartFolder.recent7Days")
        }
    }

    var systemIconName: String {
        switch self {
        case .allNotes: return "tray.full"
        case .favorites: return "star.fill"
        case .recent7Days: return "clock.arrow.circlepath"
        }
    }
}

enum SidebarDestination: Hashable {
    case smartFolder(SmartFolder)
    case category(NoteCategorySelection)
    case exhibitions
    case businessCards
    case settings
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { proxy in
            if horizontalSizeClass == .regular {
                if proxy.size.width > proxy.size.height {
                    WideRoot()
                } else {
                    iPadRoot()
                }
            } else {
                iPhoneRoot()
            }
        }
    }
}

private struct WideRoot: View {
    @Environment(\.modelContext) private var context
    @Query private var exhibitionPresets: [ExhibitionPreset]

    @State private var selection: SidebarDestination? = .smartFolder(.allNotes)
    @State private var selectedNoteID: PersistentIdentifier?
    @State private var selectedExhibitionPresetID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } content: {
            switch selection {
            case .smartFolder(let smartFolder):
                NoteColumnListView(smartFolder: smartFolder, selectedNoteID: $selectedNoteID)
            case .category(let category):
                NoteColumnListView(category: category, selectedNoteID: $selectedNoteID)
            case .exhibitions:
                NavigationStack { ExhibitionPresetsView(selectedPresetID: $selectedExhibitionPresetID) }
            case .businessCards:
                NavigationStack { BusinessCardListView() }
            case .settings:
                NavigationStack { SettingsView() }
            case nil:
                NoteColumnListView(smartFolder: .allNotes, selectedNoteID: $selectedNoteID)
            }
        } detail: {
            switch selection {
            case .exhibitions:
                if let selectedExhibitionPresetID,
                   let preset = exhibitionPresets.first(where: { $0.id == selectedExhibitionPresetID }) {
                    NavigationStack {
                        ExhibitionDetailView(preset: preset)
                    }
                } else {
                    ContentUnavailableView(
                        String(localized: "settings.exhibitionPresets"),
                        systemImage: "building.columns",
                        description: Text(String(localized: "exhibitionPreset.empty"))
                    )
                }
            default:
                if let selectedNoteID,
                   let note = context.model(for: selectedNoteID) as? Note {
                    NavigationStack {
                        NoteDetailView(note: note)
                    }
                } else {
                    ContentUnavailableView(
                        String(localized: "empty.noNotes"),
                        systemImage: "note.text",
                        description: Text(String(localized: "empty.startNew"))
                    )
                }
            }
        }
        .onChange(of: selection) { _, newSelection in
            selectedNoteID = nil
            if newSelection != .exhibitions {
                selectedExhibitionPresetID = nil
            }
        }
    }
}

private struct iPadRoot: View {
    @State private var selection: SidebarDestination? = .smartFolder(.allNotes)

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .smartFolder(let smartFolder):
                NoteListView(smartFolder: smartFolder)
            case .category(let category):
                NoteListView(category: category)
            case .exhibitions:
                NavigationStack { ExhibitionPresetsView() }
            case .businessCards:
                NavigationStack { BusinessCardListView() }
            case .settings:
                NavigationStack { SettingsView() }
            case nil:
                NoteListView(smartFolder: .allNotes)
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
