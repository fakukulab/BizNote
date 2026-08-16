import SwiftUI
import SwiftData

struct NoteCategoriesSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCategory.createdAt) private var categories: [CustomCategory]
    @Query private var allNotes: [Note]

    @State private var showAdd: Bool = false
    @State private var editing: CustomCategory?

    var body: some View {
        List {
            if categories.isEmpty {
                ContentUnavailableView(
                    String(localized: "noteCategory.empty"),
                    systemImage: "folder.badge.plus",
                    description: Text(String(localized: "noteCategory.add"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(categories) { category in
                    Button {
                        editing = category
                    } label: {
                        Label {
                            Text(category.name)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: category.systemIconName)
                                .foregroundStyle(category.accentColor)
                        }
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        delete(categories[i])
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.noteCategories"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                NoteCategoryEditor(category: nil) { newCategory in
                    context.insert(newCategory)
                    try? context.save()
                }
            }
        }
        .sheet(item: $editing) { category in
            NavigationStack {
                NoteCategoryEditor(category: category) { _ in
                    try? context.save()
                }
            }
        }
    }

    private func delete(_ category: CustomCategory) {
        for note in allNotes where note.customCategory?.id == category.id {
            note.categoryRaw = NoteCategory.workLog.rawValue
            note.customCategory = nil
        }
        context.delete(category)
        try? context.save()
    }
}

struct NoteCategoryEditor: View {
    let category: CustomCategory?
    var onSave: (CustomCategory) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var systemIconName: String = "folder.fill"
    @State private var color: Color = Color(red: 0.486, green: 0.227, blue: 0.929)

    private let iconChoices: [String] = [
        "folder.fill", "tag.fill", "star.fill", "flag.fill",
        "book.fill", "lightbulb.fill", "cart.fill", "airplane",
        "car.fill", "heart.fill", "bell.fill", "paperclip"
    ]

    var body: some View {
        Form {
            Section(String(localized: "noteCategory.name")) {
                TextField(String(localized: "noteCategory.name"), text: $name)
            }

            Section(String(localized: "noteCategory.color")) {
                ColorPicker(String(localized: "noteCategory.color"), selection: $color, supportsOpacity: false)
            }

            Section(String(localized: "noteCategory.icon")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(iconChoices, id: \.self) { icon in
                        Button {
                            systemIconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .foregroundStyle(systemIconName == icon ? color : .secondary)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(systemIconName == icon ? color.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(category == nil
                         ? String(localized: "settings.addNoteCategory")
                         : String(localized: "action.edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "action.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "action.save")) {
                    let target = category ?? CustomCategory()
                    target.name = name
                    target.systemIconName = systemIconName
                    target.accentColor = color
                    onSave(target)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let category {
                name = category.name
                systemIconName = category.systemIconName
                color = category.accentColor
            }
        }
    }
}
