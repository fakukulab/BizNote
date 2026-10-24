import SwiftUI
import SwiftData

struct EventModeEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExhibitionPreset.startDate, order: .reverse) private var presets: [ExhibitionPreset]

    @State private var showCreate = false

    var onSelect: (ExhibitionPreset) -> Void

    var body: some View {
        NavigationStack {
            List {
                if presets.isEmpty {
                    ContentUnavailableView(
                        String(localized: "exhibitionPreset.empty"),
                        systemImage: "building.columns",
                        description: Text(String(localized: "settings.addPreset"))
                    )
                } else {
                    Section {
                        ForEach(presets) { preset in
                            Button {
                                onSelect(preset)
                            } label: {
                                presetRow(preset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "eventMode.entry.title", defaultValue: "행사 선택"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Label(String(localized: "eventMode.entry.newEvent", defaultValue: "새 행사"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    ExhibitionPresetEditor(preset: nil) { newPreset in
                        context.insert(newPreset)
                        try? context.save()
                        Task { await CalendarReminderSyncService.shared.syncEvent(for: newPreset) }
                        onSelect(newPreset)
                    }
                }
            }
        }
    }

    private func presetRow(_ preset: ExhibitionPreset) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.name.isEmpty ? String(localized: "note.untitled") : preset.name)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack(spacing: 12) {
                Label(preset.dateRangeDescription, systemImage: "calendar")
                if !preset.venue.isEmpty {
                    Label(preset.venue, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
