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
    case eventMode
    case settings
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var sidebarSelection: SidebarDestination? = .smartFolder(.allNotes)
    @State private var viewportSize: CGSize = .zero
    @State private var showEventMode = false
    @State private var isEnteringEventMode = false

    var body: some View {
        Group {
            switch rootLayout {
            case .wide:
                WideRoot(selection: $sidebarSelection)
            case .regular:
                iPadRoot(selection: $sidebarSelection)
            case .compact:
                iPhoneRoot()
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            // The view's own size shrinks when the keyboard appears, which would flip
            // portrait to `.wide` and rebuild the whole root (losing the open note's
            // edit state). The window bounds are unaffected by the keyboard.
            viewportSize = Self.activeWindowSize() ?? newSize
        }
        .onChange(of: sidebarSelection) { _, newSelection in
            // Event Mode is entered only after an interstitial ad (iPad sidebar only).
            guard newSelection == .eventMode, !isEnteringEventMode else { return }
            isEnteringEventMode = true
            sidebarSelection = .smartFolder(.allNotes)
            Task {
                await AdService.shared.showInterstitial()
                showEventMode = true
                isEnteringEventMode = false
            }
        }
        .fullScreenCover(isPresented: $showEventMode) {
            EventModeRootView()
        }
    }

    private static func activeWindowSize() -> CGSize? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first(where: \.isKeyWindow)?
            .bounds.size
    }

    private var rootLayout: RootLayout {
        guard horizontalSizeClass == .regular else { return .compact }
        return viewportSize.width > viewportSize.height ? .wide : .regular
    }
}

private enum RootLayout {
    case compact
    case regular
    case wide
}

private struct WideRoot: View {
    @Binding var selection: SidebarDestination?
    @State private var selectedNoteID: PersistentIdentifier?
    @State private var selectedExhibitionPresetID: UUID?
    @State private var selectedBusinessCardID: UUID?
    @State private var detailPath = NavigationPath()

    var body: some View {
        Group {
            if selection == .settings {
                WideSettingsSplitView(selection: $selection, detailPath: $detailPath)
            } else if selection == .businessCards {
                WideBusinessCardsSplitView(
                    selection: $selection,
                    selectedBusinessCardID: $selectedBusinessCardID,
                    detailPath: $detailPath
                )
            } else {
                WideNotesSplitView(
                    selection: $selection,
                    selectedNoteID: $selectedNoteID,
                    selectedExhibitionPresetID: $selectedExhibitionPresetID,
                    detailPath: $detailPath
                )
            }
        }
        .onChange(of: selection) { _, newSelection in
            selectedNoteID = nil
            detailPath = NavigationPath()
            if newSelection != .exhibitions {
                selectedExhibitionPresetID = nil
            }
            if newSelection != .businessCards {
                selectedBusinessCardID = nil
            }
        }
    }
}

private struct WideSettingsSplitView: View {
    @Binding var selection: SidebarDestination?
    @Binding var detailPath: NavigationPath

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            NavigationStack(path: $detailPath) {
                SettingsView()
            }
        }
        .id("settings")
    }
}

private struct WideBusinessCardsSplitView: View {
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var businessCards: [BusinessCard]

    @Binding var selection: SidebarDestination?
    @Binding var selectedBusinessCardID: UUID?
    @Binding var detailPath: NavigationPath

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } content: {
            NavigationStack {
                BusinessCardListView(selectedCardID: $selectedBusinessCardID)
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                if let selectedBusinessCardID,
                   let card = businessCards.first(where: { $0.id == selectedBusinessCardID }) {
                    BusinessCardResultView(card: card, attachedNote: card.note)
                } else {
                    ContentUnavailableView(
                        String(localized: "nav.businessCards"),
                        systemImage: "person.crop.rectangle",
                        description: Text(String(localized: "businessCard.empty"))
                    )
                }
            }
        }
        .id("businessCards")
    }
}

private struct WideNotesSplitView: View {
    @Environment(\.modelContext) private var context
    @Query private var exhibitionPresets: [ExhibitionPreset]

    @Binding var selection: SidebarDestination?
    @Binding var selectedNoteID: PersistentIdentifier?
    @Binding var selectedExhibitionPresetID: UUID?
    @Binding var detailPath: NavigationPath

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } content: {
            Group {
                switch selection {
                case .smartFolder(let smartFolder):
                    NoteColumnListView(smartFolder: smartFolder, selectedNoteID: $selectedNoteID)
                case .category(let category):
                    NoteColumnListView(category: category, selectedNoteID: $selectedNoteID)
                case .exhibitions:
                    NavigationStack { ExhibitionPresetsView(selectedPresetID: $selectedExhibitionPresetID) }
                case .businessCards:
                    EmptyView()
                case .eventMode:
                    EmptyView()
                case .settings:
                    EmptyView()
                case nil:
                    NoteColumnListView(smartFolder: .allNotes, selectedNoteID: $selectedNoteID)
                }
            }
            .id(selection)
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    switch selection {
                    case .exhibitions:
                        if let selectedExhibitionPresetID,
                           let preset = exhibitionPresets.first(where: { $0.id == selectedExhibitionPresetID }) {
                            ExhibitionDetailView(preset: preset)
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
                            NoteDetailView(note: note)
                        } else {
                            ContentUnavailableView(
                                String(localized: "empty.noNotes"),
                                systemImage: "note.text",
                                description: Text(String(localized: "empty.startNew"))
                            )
                        }
                    }
                }
                .id(selection)
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    if let note = context.model(for: id) as? Note {
                        NoteDetailView(note: note)
                    }
                }
            }
        }
        .id("notes")
    }
}

private struct iPadRoot: View {
    @Binding var selection: SidebarDestination?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            Group {
                switch selection {
                case .smartFolder(let smartFolder):
                    NoteListView(smartFolder: smartFolder)
                case .category(let category):
                    NoteListView(category: category)
                case .exhibitions:
                    NavigationStack { ExhibitionPresetsView() }
                case .businessCards:
                    NavigationStack { BusinessCardListView() }
                case .eventMode:
                    EmptyView()
                case .settings:
                    NavigationStack { SettingsView() }
                case nil:
                    NoteListView(smartFolder: .allNotes)
                }
            }
            .id(selection)
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
