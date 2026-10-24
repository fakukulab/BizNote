import SwiftUI
import SwiftData

/// Lets event-mode staff wipe collected visitor records — either for a single
/// saved event or across all of them — without touching the saved event
/// (`ExhibitionPreset`) definitions themselves, or any regular note/business
/// card data outside Event Mode.
struct EventModeResetVisitorsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExhibitionPreset.startDate, order: .reverse) private var presets: [ExhibitionPreset]

    @State private var isConfirmingDeleteAll = false

    var body: some View {
        NavigationStack {
            List {
                if !presets.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            isConfirmingDeleteAll = true
                        } label: {
                            Label(
                                String(localized: "eventMode.settings.resetVisitors.all", defaultValue: "모든 행사의 방문객 목록 삭제"),
                                systemImage: "trash"
                            )
                        }
                        .popover(isPresented: $isConfirmingDeleteAll) {
                            DeleteConfirmationPopover(message: deleteAllMessage) {
                                deleteAllVisitors()
                                isConfirmingDeleteAll = false
                            } onCancel: {
                                isConfirmingDeleteAll = false
                            }
                        }
                    }
                }

                Section(String(localized: "eventMode.settings.resetVisitors.byEvent", defaultValue: "행사별로 삭제")) {
                    if presets.isEmpty {
                        ContentUnavailableView(
                            String(localized: "exhibitionPreset.empty"),
                            systemImage: "building.columns"
                        )
                    } else {
                        ForEach(presets) { preset in
                            PresetResetRow(preset: preset) {
                                deleteVisitors(in: preset)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "eventMode.settings.resetVisitors", defaultValue: "방문객 목록 초기화"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
            }
        }
    }

    private var deleteAllMessage: String {
        String(
            format: String(
                localized: "eventMode.settings.resetVisitors.confirmAll",
                defaultValue: "모든 행사의 방문객 %lld명이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다."
            ),
            presets.reduce(0) { $0 + ($1.visitors?.count ?? 0) }
        )
    }

    private func deleteVisitors(in preset: ExhibitionPreset) {
        for visitor in preset.visitors ?? [] {
            context.delete(visitor)
        }
        try? context.save()
    }

    private func deleteAllVisitors() {
        for preset in presets {
            for visitor in preset.visitors ?? [] {
                context.delete(visitor)
            }
        }
        try? context.save()
    }
}

/// A single saved event's row. Owns its own confirmation popover so tapping
/// one row never affects another row's confirmation state.
private struct PresetResetRow: View {
    let preset: ExhibitionPreset
    var onConfirmDelete: () -> Void

    @State private var isConfirming = false

    var body: some View {
        Button(role: .destructive) {
            isConfirming = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name.isEmpty ? String(localized: "note.untitled") : preset.name)
                        .foregroundStyle(.primary)
                    Text(String(format: String(localized: "eventMode.list.totalCount", defaultValue: "총 %lld명"), preset.visitors?.count ?? 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isConfirming) {
            DeleteConfirmationPopover(message: confirmMessage) {
                onConfirmDelete()
                isConfirming = false
            } onCancel: {
                isConfirming = false
            }
        }
    }

    private var confirmMessage: String {
        String(
            format: String(
                localized: "eventMode.settings.resetVisitors.confirmEvent",
                defaultValue: "'%@'의 방문객 %lld명이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다."
            ),
            preset.name.isEmpty ? String(localized: "note.untitled") : preset.name,
            preset.visitors?.count ?? 0
        )
    }
}

/// Confirmation shown as a popover anchored directly to the row/button that
/// triggered it, rather than a bottom sheet detached from the item.
private struct DeleteConfirmationPopover: View {
    let message: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                String(localized: "eventMode.settings.resetVisitors.confirmTitle", defaultValue: "방문객 목록을 삭제할까요?"),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(String(localized: "action.cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(String(localized: "action.confirm", defaultValue: "확인")) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
    }
}
