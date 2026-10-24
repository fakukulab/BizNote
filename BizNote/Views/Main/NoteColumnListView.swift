import SwiftUI
import SwiftData

private enum NoteColumnListMode: String, CaseIterable, Identifiable {
    case all
    case workLogsWithInProgress

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .all:
            return String(localized: "noteList.mode.all")
        case .workLogsWithInProgress:
            return String(localized: "noteList.mode.inProgress", defaultValue: "In Progress")
        }
    }

    var systemIconName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .workLogsWithInProgress:
            return "clock.badge.exclamationmark"
        }
    }

    func includes(_ note: Note) -> Bool {
        switch self {
        case .all:
            return true
        case .workLogsWithInProgress:
            guard note.categorySelection == .builtin(.workLog),
                  let data = TemplateCoder.decode(WorkLogTemplateData.self, from: note.templateData) else {
                return false
            }
            return data.workItems.contains { item in
                item.status == .inProgress && !item.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }
}

struct NoteColumnListView: View {
    let category: NoteCategorySelection?
    let smartFolder: SmartFolder?
    @Binding var selectedNoteID: PersistentIdentifier?

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = false
    @State private var showExporter: Bool = false
    @State private var sortOrder: NoteListSortOrder = .newest
    @State private var isSelecting: Bool = false
    @State private var selectedNoteIDs: Set<PersistentIdentifier> = []
    @State private var editMode: EditMode = .inactive
    @State private var listMode: NoteColumnListMode = .all

    init(
        category: NoteCategorySelection? = nil,
        smartFolder: SmartFolder? = nil,
        selectedNoteID: Binding<PersistentIdentifier?>
    ) {
        self.category = category
        self.smartFolder = smartFolder
        self._selectedNoteID = selectedNoteID
    }

    private var filter: NoteListFilter {
        NoteListFilter(category: category, smartFolder: smartFolder)
    }

    private var filteredNotes: [Note] {
        allNotes.filter { note in
            filter.includes(note, showFavoritesOnly: showFavoritesOnly, searchText: searchText) &&
            (!isWorkLogFilterAvailable || listMode.includes(note))
        }
        .sorted(by: sortOrder)
    }

    private var isWorkLogFilterAvailable: Bool {
        category == .builtin(.workLog) && smartFolder == nil
    }

    private var availableSortOrders: [NoteListSortOrder] {
        NoteListSortOrder.availableOrders(in: smartFolder)
    }

    var body: some View {
        noteList
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle(filter.title)
            .searchable(text: $searchText, prompt: Text(String(localized: "note.searchPlaceholder")))
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.cancel")) {
                            exitSelectionMode()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            deleteSelectedNotes()
                        } label: {
                            Label(String(localized: "note.deleteSelected"), systemImage: "trash")
                        }
                        .disabled(selectedNoteIDs.isEmpty)
                    }
                } else {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if isWorkLogFilterAvailable {
                            filterModeMenu
                        }

                        sortMenu

                        Menu {
                            Button {
                                showFavoritesOnly.toggle()
                            } label: {
                                Label(String(localized: "note.favorite"), systemImage: "star.fill")
                            }
                            Button {
                                enterSelectionMode()
                            } label: {
                                Label(String(localized: "action.select"), systemImage: "checkmark.circle")
                            }
                            .disabled(filteredNotes.isEmpty)
                            Button {
                                showExporter = true
                            } label: {
                                Label(String(localized: "action.export"), systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Label(String(localized: "action.more", defaultValue: "More"), systemImage: "ellipsis.circle")
                        }
                        .labelStyle(.iconOnly)

                        newNoteButton
                    }
                }
            }
            .sheet(isPresented: $showExporter) {
                NavigationStack {
                    ExportView()
                }
            }
            .onChange(of: listMode) { _, _ in
                clearSelectionIfNeeded()
            }
            .onChange(of: smartFolder) { _, _ in
                normalizeSortOrder()
            }
            .onChange(of: category) { _, _ in
                normalizeSortOrder()
            }
    }

    @ViewBuilder
    private var noteList: some View {
        if isSelecting {
            List(selection: $selectedNoteIDs) {
                noteRows
            }
        } else {
            List(selection: $selectedNoteID) {
                noteRows
            }
        }
    }

    @ViewBuilder
    private var noteRows: some View {
        if filteredNotes.isEmpty {
            Section {
                ContentUnavailableView(
                    String(localized: "empty.noNotes"),
                    systemImage: "note.text",
                    description: Text(String(localized: "empty.startNew"))
                )
                .listRowBackground(Color.clear)
            }
        } else {
            ForEach(filteredNotes, id: \.persistentModelID) { note in
                if isSelecting {
                    NoteRowView(note: note)
                        .tag(note.persistentModelID)
                } else {
                    Button {
                        selectedNoteID = note.persistentModelID
                    } label: {
                        NoteRowView(note: note)
                    }
                        .buttonStyle(.plain)
                        .tag(note.persistentModelID)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(note)
                            } label: {
                                Label(String(localized: "action.delete"), systemImage: "trash")
                            }
                            Button {
                                note.isFavorite.toggle()
                            } label: {
                                Label(String(localized: "note.favorite"),
                                      systemImage: note.isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                }
            }
        }
    }

    private func clearSelectionIfNeeded() {
        guard let selectedNoteID else { return }
        if !filteredNotes.contains(where: { $0.persistentModelID == selectedNoteID }) {
            self.selectedNoteID = nil
        }
    }

    @ViewBuilder
    private var newNoteButton: some View {
        if smartFolder == nil {
            Button {
                createNote()
            } label: {
                Label(String(localized: "action.newNote"), systemImage: "square.and.pencil")
            }
            .labelStyle(.iconOnly)
        } else {
            Menu {
                noteTypeSelectionButtons()
            } label: {
                Label(String(localized: "note.type.select", defaultValue: "Select Note Type"), systemImage: "square.and.pencil")
            }
            .labelStyle(.iconOnly)
        }
    }

    private func createNote() {
        createNote(in: filter.defaultCategory)
    }

    private func createNote(in targetCategory: NoteCategorySelection) {
        let note: Note
        switch targetCategory {
        case .builtin(let c):
            note = Note(title: "", category: c)
            if c == .workLog {
                WorkLogNoteDefaults.apply(to: note, previousNotes: allNotes)
            }
        case .custom(let c):
            note = Note(title: "", customCategory: c)
        }

        note.isFavorite = smartFolder == .favorites
        context.insert(note)
        try? context.save()

        selectedNoteID = note.persistentModelID
    }

    @ViewBuilder
    private func noteTypeSelectionButtons() -> some View {
        ForEach(NoteCategory.allCases) { category in
            Button {
                createNote(in: .builtin(category))
            } label: {
                Label(category.localizedName, systemImage: category.systemIconName)
            }
        }

        ForEach(customCategories) { category in
            Button {
                createNote(in: .custom(category))
            } label: {
                Label(category.name, systemImage: category.systemIconName)
            }
        }
    }

    private func enterSelectionMode() {
        selectedNoteIDs = []
        isSelecting = true
        editMode = .active
    }

    private func exitSelectionMode() {
        selectedNoteIDs = []
        isSelecting = false
        editMode = .inactive
    }

    private func deleteSelectedNotes() {
        let notesToDelete = filteredNotes.filter { selectedNoteIDs.contains($0.persistentModelID) }
        guard !notesToDelete.isEmpty else { return }

        let shouldClearDetail = selectedNoteID.map { selectedNoteIDs.contains($0) } ?? false

        for note in notesToDelete {
            context.delete(note)
        }
        try? context.save()
        exitSelectionMode()
        if shouldClearDetail {
            selectedNoteID = nil
        }
    }

    private func delete(_ note: Note) {
        let deletedID = note.persistentModelID
        context.delete(note)
        try? context.save()
        if selectedNoteID == deletedID {
            selectedNoteID = nil
        }
    }

    private var filterModeMenu: some View {
        Menu {
            ForEach(NoteColumnListMode.allCases) { mode in
                Button {
                    listMode = mode
                } label: {
                    Label(mode.localizedName, systemImage: mode.systemIconName)
                }
            }
        } label: {
            Label(String(localized: "noteList.filterOptions", defaultValue: "Filter Options"), systemImage: listMode.systemIconName)
        }
        .labelStyle(.iconOnly)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(availableSortOrders) { order in
                Button {
                    sortOrder = order
                } label: {
                    Label(order.localizedName, systemImage: order.systemIconName)
                }
            }
        } label: {
            Label(String(localized: "noteList.sortOptions"), systemImage: sortOrder.systemIconName)
        }
        .labelStyle(.iconOnly)
    }

    private func normalizeSortOrder() {
        if !availableSortOrders.contains(sortOrder) {
            sortOrder = .newest
        }
    }
}

struct NoteRowView: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: note.categoryIconName)
                .foregroundStyle(note.categoryAccentColor)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title.isEmpty ? String(localized: "note.title") : note.title)
                        .font(.headline)
                        .lineLimit(1)
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                    Spacer()
                    Text(note.listDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(note.categoryAccentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
