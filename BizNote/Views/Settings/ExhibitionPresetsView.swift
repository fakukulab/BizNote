import SwiftUI
import SwiftData

struct ExhibitionPresetsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExhibitionPreset.createdAt, order: .reverse)
    private var presets: [ExhibitionPreset]

    @State private var showAdd: Bool = false
    @State private var editing: ExhibitionPreset?

    var body: some View {
        List {
            if presets.isEmpty {
                ContentUnavailableView(
                    String(localized: "exhibitionPreset.empty"),
                    systemImage: "building.columns",
                    description: Text(String(localized: "settings.addPreset"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(presets) { preset in
                    Button {
                        editing = preset
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name).font(.headline).foregroundStyle(.primary)
                            HStack(spacing: 12) {
                                Label(preset.dateRangeDescription, systemImage: "calendar")
                                if !preset.venue.isEmpty {
                                    Label(preset.venue, systemImage: "mappin.and.ellipse")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if !preset.organizer.isEmpty {
                                Text(preset.organizer)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        context.delete(presets[i])
                    }
                    try? context.save()
                }
            }
        }
        .navigationTitle(String(localized: "settings.exhibitionPresets"))
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
                ExhibitionPresetEditor(preset: nil) { newPreset in
                    context.insert(newPreset)
                    try? context.save()
                }
            }
        }
        .sheet(item: $editing) { preset in
            NavigationStack {
                ExhibitionPresetEditor(preset: preset) { _ in
                    try? context.save()
                }
            }
        }
    }
}
