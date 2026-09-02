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

private enum NoteListSortOrder: String, CaseIterable, Identifiable {
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

private extension NoteListSortOrder {
    static func availableOrders(in smartFolder: SmartFolder?) -> [NoteListSortOrder] {
        smartFolder == nil ? [.newest, .oldest] : [.noteType, .newest, .oldest]
    }
}

private extension Array where Element == Note {
    func sorted(by order: NoteListSortOrder) -> [Note] {
        switch order {
        case .noteType:
            return sorted {
                if $0.categoryName == $1.categoryName {
                    return $0.contentDate > $1.contentDate
                }
                return $0.categoryName.localizedStandardCompare($1.categoryName) == .orderedAscending
            }
        case .newest:
            return sorted { $0.contentDate > $1.contentDate }
        case .oldest:
            return sorted { $0.contentDate < $1.contentDate }
        }
    }
}

private struct NoteListFilter {
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
    @State private var path = NavigationPath()

    init(category: NoteCategorySelection? = nil, smartFolder: SmartFolder? = nil) {
        self.category = category
        self.smartFolder = smartFolder
    }

    private var filter: NoteListFilter {
        NoteListFilter(category: category, smartFolder: smartFolder)
    }

    var filteredNotes: [Note] {
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
            List {
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
                            Button {
                                toggleSelection(for: note)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedNoteIDs.contains(note.persistentModelID)
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .foregroundStyle(selectedNoteIDs.contains(note.persistentModelID) ? Color.accentColor : Color.secondary)
                                        .font(.title3)
                                    NoteRowView(note: note)
                                }
                            }
                            .buttonStyle(.plain)
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
            .listStyle(.insetGrouped)
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
                            Image(systemName: "ellipsis.circle")
                        }

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
                applyWorkLogDefaults(to: note)
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

    private func applyWorkLogDefaults(to note: Note) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        note.title = "\(df.string(from: Date())) \(NoteCategory.workLog.localizedName)"

        let previous = allNotes
            .filter { $0.category == .workLog }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        var data = WorkLogTemplateData()
        data.date = Date()

        if let previous,
           let prevData = TemplateCoder.decode(WorkLogTemplateData.self, from: previous.templateData) {
            let carryLines = prevData.nextTodos
                .split(whereSeparator: { $0 == "\n" || $0 == "," })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            data.workItems = carryLines.map { line in
                var item = WorkLogTemplateData.WorkItem()
                item.task = line
                item.status = .todo
                return item
            }
        }

        note.templateData = TemplateCoder.encode(data)
    }

    private func enterSelectionMode() {
        selectedNoteIDs = []
        isSelecting = true
    }

    private func exitSelectionMode() {
        selectedNoteIDs = []
        isSelecting = false
    }

    private func toggleSelection(for note: Note) {
        let id = note.persistentModelID
        if selectedNoteIDs.contains(id) {
            selectedNoteIDs.remove(id)
        } else {
            selectedNoteIDs.insert(id)
        }
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
        List(selection: $selectedNoteID) {
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
                        Button {
                            toggleSelection(for: note)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedNoteIDs.contains(note.persistentModelID)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(selectedNoteIDs.contains(note.persistentModelID) ? Color.accentColor : Color.secondary)
                                    .font(.title3)
                                NoteRowView(note: note)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NoteRowView(note: note)
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
        .listStyle(.insetGrouped)
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
                        Image(systemName: "ellipsis.circle")
                    }

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
                applyWorkLogDefaults(to: note)
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

    private func applyWorkLogDefaults(to note: Note) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        note.title = "\(df.string(from: Date())) \(NoteCategory.workLog.localizedName)"

        let previous = allNotes
            .filter { $0.category == .workLog }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        var data = WorkLogTemplateData()
        data.date = Date()

        if let previous,
           let prevData = TemplateCoder.decode(WorkLogTemplateData.self, from: previous.templateData) {
            let carryLines = prevData.nextTodos
                .split(whereSeparator: { $0 == "\n" || $0 == "," })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            data.workItems = carryLines.map { line in
                var item = WorkLogTemplateData.WorkItem()
                item.task = line
                item.status = .todo
                return item
            }
        }

        note.templateData = TemplateCoder.encode(data)
    }

    private func enterSelectionMode() {
        selectedNoteIDs = []
        isSelecting = true
    }

    private func exitSelectionMode() {
        selectedNoteIDs = []
        isSelecting = false
    }

    private func toggleSelection(for note: Note) {
        let id = note.persistentModelID
        if selectedNoteIDs.contains(id) {
            selectedNoteIDs.remove(id)
        } else {
            selectedNoteIDs.insert(id)
        }
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
            Image(systemName: listMode.systemIconName)
        }
        .accessibilityLabel(String(localized: "noteList.filterOptions", defaultValue: "Filter Options"))
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

private struct NoteRowView: View {
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
                    Text(note.contentDate, style: .date)
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
