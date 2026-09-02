import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarDestination?
    @Environment(\.modelContext) private var context
    @Query private var allNotes: [Note]
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]
    @State private var showAddNoteList = false

    var body: some View {
        List(selection: $selection) {
            Section(String(localized: "sidebar.smartFolders")) {
                ForEach(SmartFolder.allCases) { smartFolder in
                    smartFolderRow(smartFolder)
                }
                NavigationLink(value: SidebarDestination.businessCards) {
                    Label(String(localized: "nav.businessCardManagement"), systemImage: "person.crop.rectangle")
                }
            }

            Section(String(localized: "sidebar.eventList")) {
                NavigationLink(value: SidebarDestination.exhibitions) {
                    Label(String(localized: "nav.event"), systemImage: "building.columns")
                }
            }

            Section(String(localized: "sidebar.noteList")) {
                Button {
                    showAddNoteList = true
                } label: {
                    Label(String(localized: "noteList.addNote", defaultValue: "Note"), systemImage: "plus")
                }
                ForEach(NoteCategory.allCases) { category in
                    categoryRow(.builtin(category))
                }
                ForEach(customCategories) { category in
                    categoryRow(.custom(category))
                }
            }

            Section {
                NavigationLink(value: SidebarDestination.settings) {
                    Label(String(localized: "nav.settings"), systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("BizNote")
        .sheet(isPresented: $showAddNoteList) {
            NavigationStack {
                NoteCategoryEditor(
                    category: nil,
                    addTitle: String(localized: "settings.addNote", defaultValue: "Add Note")
                ) { newCategory in
                    context.insert(newCategory)
                    try? context.save()
                }
            }
        }
    }

    @ViewBuilder
    private func smartFolderRow(_ smartFolder: SmartFolder) -> some View {
        NavigationLink(value: SidebarDestination.smartFolder(smartFolder)) {
            Label(smartFolder.localizedName, systemImage: smartFolder.systemIconName)
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: NoteCategorySelection) -> some View {
        NavigationLink(value: SidebarDestination.category(category)) {
            Label {
                HStack {
                    Text(category.localizedName)
                    Spacer()
                    Text(verbatim: "\(count(for: category))")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } icon: {
                Image(systemName: category.systemIconName)
                    .foregroundStyle(category.accentColor)
            }
        }
    }

    private func count(for category: NoteCategorySelection) -> Int {
        allNotes.filter { $0.categorySelection == category }.count
    }
}
