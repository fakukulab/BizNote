import SwiftUI
import SwiftData

struct EventModeDuplicateMergeView: View {
    let groups: [[EventVisitor]]
    var onMerge: (EventVisitor, [EventVisitor]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mergedGroupIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    ContentUnavailableView(
                        String(localized: "eventMode.duplicate.empty", defaultValue: "중복된 방문객이 없습니다"),
                        systemImage: "checkmark.circle"
                    )
                } else {
                    ForEach(groups.indices, id: \.self) { index in
                        let group = groups[index]
                        if let primary = group.first {
                            Section {
                                ForEach(group) { visitor in
                                    row(for: visitor, isPrimary: visitor.id == primary.id)
                                }

                                if mergedGroupIDs.contains(primary.id) {
                                    Label(String(localized: "eventMode.duplicate.merged", defaultValue: "병합 완료"), systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Button {
                                        merge(group)
                                    } label: {
                                        Text(String(localized: "eventMode.duplicate.mergeButton", defaultValue: "이 그룹 병합"))
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                }
                            } footer: {
                                Text(String(
                                    localized: "eventMode.duplicate.footer",
                                    defaultValue: "병합하면 가장 먼저 등록된 레코드에 나머지 정보를 채우고 나머지는 삭제합니다."
                                ))
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "eventMode.duplicate.title", defaultValue: "중복 정리"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.close", defaultValue: "닫기")) { dismiss() }
                }
            }
        }
    }

    private func row(for visitor: EventVisitor, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(visitor.name.isEmpty ? String(localized: "note.untitled") : visitor.name)
                    .font(.headline)
                if isPrimary {
                    Text(String(localized: "eventMode.duplicate.keep", defaultValue: "유지됨"))
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
            }
            HStack(spacing: 10) {
                if !visitor.company.isEmpty { Text(visitor.company) }
                if !visitor.email.isEmpty { Text(visitor.email) }
                if !visitor.mobile.isEmpty { Text(visitor.mobile) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(DateFormatter.exportTimestamp.string(from: visitor.createdAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func merge(_ group: [EventVisitor]) {
        guard let primary = group.first, group.count >= 2 else { return }
        let others = Array(group.dropFirst())
        onMerge(primary, others)
        mergedGroupIDs.insert(primary.id)
    }
}
