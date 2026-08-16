import SwiftUI
import SwiftData

struct NoteListView: View {
    let category: NoteCategorySelection?

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = false
    @State private var showExporter: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedNoteIDs: Set<PersistentIdentifier> = []
    @State private var path = NavigationPath()

    var filteredNotes: [Note] {
        allNotes.filter { note in
            (category == nil || note.categorySelection == category) &&
            (!showFavoritesOnly || note.isFavorite) &&
            (searchText.isEmpty ||
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) })
        }
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
            .navigationTitle(category?.localizedName ?? String(localized: "nav.notes"))
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
                        Menu {
                            Toggle(String(localized: "note.favorite"), isOn: $showFavoritesOnly)
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

                        Button {
                            createNote()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showExporter) {
                NavigationStack {
                    ExportView()
                }
            }
        }
    }

    private func createNote() {
        let targetCategory = category ?? .builtin(.workLog)
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

        context.insert(note)
        try? context.save()

        path.append(note.persistentModelID)
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
                    Text(note.updatedAt, style: .date)
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
