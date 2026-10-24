import SwiftUI
import SwiftData

enum NoteListSortOrder: String, CaseIterable, Identifiable {
    case noteType
    case newest
    case oldest

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .noteType:
            return String(localized: "noteList.sort.noteType", defaultValue: "Type")
        case .newest:
            return String(localized: "noteList.sort.newest", defaultValue: "Newest")
        case .oldest:
            return String(localized: "noteList.sort.oldest", defaultValue: "Oldest")
        }
    }

    var systemIconName: String {
        switch self {
        case .noteType:
            return "folder"
        case .newest:
            return "arrow.down"
        case .oldest:
            return "arrow.up"
        }
    }
}

extension NoteListSortOrder {
    static func availableOrders(in smartFolder: SmartFolder?) -> [NoteListSortOrder] {
        smartFolder == nil ? [.newest, .oldest] : [.noteType, .newest, .oldest]
    }
}

extension Array where Element == Note {
    func sorted(by order: NoteListSortOrder) -> [Note] {
        switch order {
        case .noteType:
            return sorted {
                if $0.categoryName == $1.categoryName {
                    return $0.listDate > $1.listDate
                }
                return $0.categoryName.localizedStandardCompare($1.categoryName) == .orderedAscending
            }
        case .newest:
            return sorted { $0.listDate > $1.listDate }
        case .oldest:
            return sorted { $0.listDate < $1.listDate }
        }
    }
}

struct NoteListFilter {
    let category: NoteCategorySelection?
    let smartFolder: SmartFolder?

    var title: String {
        smartFolder?.localizedName ?? category?.localizedName ?? String(localized: "nav.notes")
    }

    var defaultCategory: NoteCategorySelection {
        category ?? .builtin(.workLog)
    }

    func includes(_ note: Note, showFavoritesOnly: Bool, searchText: String) -> Bool {
        let matchesScope: Bool
        if let smartFolder {
            switch smartFolder {
            case .allNotes:
                matchesScope = true
            case .favorites:
                matchesScope = note.isFavorite
            case .recent7Days:
                let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                matchesScope = note.updatedAt >= startDate
            }
        } else {
            matchesScope = category == nil || note.categorySelection == category
        }

        return matchesScope &&
            (!showFavoritesOnly || note.isFavorite) &&
            (searchText.isEmpty ||
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) })
    }
}

enum WorkLogNoteDefaults {
    static func apply(to note: Note, previousNotes: [Note]) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        note.title = "\(df.string(from: Date())) \(NoteCategory.workLog.localizedName)"

        let previous = previousNotes
            .filter { $0.category == .workLog }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        var data = WorkLogTemplateData()
        data.date = Date()

        if let previous,
           let prevData = TemplateCoder.decode(WorkLogTemplateData.self, from: previous.templateData) {
            let inProgressItems = prevData.workItems
                .filter { $0.status == .inProgress && !$0.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { previousItem in
                    var item = WorkLogTemplateData.WorkItem()
                    item.task = previousItem.task
                    item.status = .inProgress
                    return item
                }

            let carryLines = prevData.nextTodos
                .split(whereSeparator: { $0 == "\n" || $0 == "," })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let todoItems = carryLines
                .filter { line in
                    !inProgressItems.contains { $0.task == line }
                }
                .map { line in
                    var item = WorkLogTemplateData.WorkItem()
                    item.task = line
                    item.status = .todo
                    return item
                }
            data.workItems = inProgressItems + todoItems
        }

        note.templateData = TemplateCoder.encode(data)
    }
}

struct NoteListView: View {
    let category: NoteCategorySelection?
    let smartFolder: SmartFolder?

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
    @State private var path = NavigationPath()

    init(category: NoteCategorySelection? = nil, smartFolder: SmartFolder? = nil) {
        self.category = category
        self.smartFolder = smartFolder
    }

    private var filter: NoteListFilter {
        NoteListFilter(category: category, smartFolder: smartFolder)
    }

    private var filteredNotes: [Note] {
        allNotes.filter { note in
            filter.includes(note, showFavoritesOnly: showFavoritesOnly, searchText: searchText)
        }
        .sorted(by: sortOrder)
    }

    private var availableSortOrders: [NoteListSortOrder] {
        NoteListSortOrder.availableOrders(in: smartFolder)
    }

    var body: some View {
        NavigationStack(path: $path) {
            noteList
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle(filter.title)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let note = context.model(for: id) as? Note {
                    NoteDetailView(note: note)
                }
            }
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
                        sortMenu

                        Menu {
                            Toggle(isOn: $showFavoritesOnly) {
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
            .onChange(of: smartFolder) { _, _ in
                normalizeSortOrder()
            }
        }
    }

    @ViewBuilder
    private var noteList: some View {
        if isSelecting {
            List(selection: $selectedNoteIDs) {
                noteRows
            }
        } else {
            List {
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
                    NavigationLink(value: note.persistentModelID) {
                        NoteRowView(note: note)
                    }
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

    @ViewBuilder
    private var newNoteButton: some View {
        if smartFolder == nil {
            Button {
                createNote()
            } label: {
                Image(systemName: "square.and.pencil")
            }
        } else {
            Menu {
                noteTypeSelectionButtons()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel(String(localized: "note.type.select", defaultValue: "Select Note Type"))
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

        path.append(note.persistentModelID)
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

        for note in notesToDelete {
            context.delete(note)
        }
        try? context.save()
        exitSelectionMode()
    }

    private func delete(_ note: Note) {
        context.delete(note)
        try? context.save()
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
            Image(systemName: sortOrder.systemIconName)
        }
        .accessibilityLabel(String(localized: "noteList.sortOptions"))
    }

    private func normalizeSortOrder() {
        if !availableSortOrders.contains(sortOrder) {
            sortOrder = .newest
        }
    }
}
