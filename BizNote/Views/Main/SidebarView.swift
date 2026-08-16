import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarDestination?
    @Query private var allNotes: [Note]
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    var body: some View {
        List(selection: $selection) {
            Section(String(localized: "nav.categories")) {
                ForEach(NoteCategory.allCases) { category in
                    categoryRow(.builtin(category))
                }
                ForEach(customCategories) { category in
                    categoryRow(.custom(category))
                }
            }

            Section {
                NavigationLink(value: SidebarDestination.exhibitions) {
                    Label(String(localized: "nav.exhibitions"), systemImage: "building.columns")
                }
                NavigationLink(value: SidebarDestination.businessCards) {
                    Label(String(localized: "nav.businessCards"), systemImage: "person.crop.rectangle")
                }
                NavigationLink(value: SidebarDestination.settings) {
                    Label(String(localized: "nav.settings"), systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("BizNote")
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
