import SwiftUI
import SwiftData

enum EventVisitorSortOption: String, CaseIterable, Identifiable {
    case newest
    case name
    case company

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .newest:  String(localized: "eventMode.list.sort.newest", defaultValue: "등록순")
        case .name:    String(localized: "eventMode.list.sort.name", defaultValue: "이름순")
        case .company: String(localized: "eventMode.list.sort.company", defaultValue: "회사순")
        }
    }

    func sorted(_ visitors: [EventVisitor]) -> [EventVisitor] {
        switch self {
        case .newest:
            visitors.sorted { $0.createdAt > $1.createdAt }
        case .name:
            visitors.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .company:
            visitors.sorted { $0.company.localizedStandardCompare($1.company) == .orderedAscending }
        }
    }
}

struct EventModeVisitorListView: View {
    @Bindable var preset: ExhibitionPreset
    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var sortOption: EventVisitorSortOption = .newest
    @State private var countryFilter: String?
    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var showExportSheet = false
    @State private var showDuplicateMerge = false

    private var visitors: [EventVisitor] { preset.visitors ?? [] }

    private var duplicateGroups: [[EventVisitor]] {
        guard !visitors.isEmpty else { return [] }
        return EventVisitor.duplicateGroups(in: visitors)
    }

    private var filtered: [EventVisitor] {
        guard !visitors.isEmpty else { return [] }
        var result = visitors
        if let countryFilter {
            result = result.filter { $0.countryCode == countryFilter }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.name.localizedStandardContains(query) ||
                $0.company.localizedStandardContains(query) ||
                $0.email.localizedStandardContains(query)
            }
        }
        return sortOption.sorted(result)
    }

    private var todayCount: Int {
        let calendar = Calendar.current
        return visitors.count(where: { calendar.isDateInToday($0.createdAt) })
    }

    private var usedCountryCodes: [String] {
        let codes = Array(Set(visitors.map(\.countryCode).filter { !$0.isEmpty }))
        return codes.sorted { EventCountry(code: $0).localizedName < EventCountry(code: $1).localizedName }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label(
                        String(format: String(localized: "eventMode.list.totalCount", defaultValue: "총 %lld명"), visitors.count),
                        systemImage: "person.3"
                    )
                    Spacer()
                    Label(
                        String(format: String(localized: "eventMode.list.todayCount", defaultValue: "오늘 %lld명"), todayCount),
                        systemImage: "calendar"
                    )
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Section {
                if filtered.isEmpty {
                    if visitors.isEmpty {
                        ContentUnavailableView(
                            String(localized: "eventMode.list.empty", defaultValue: "아직 등록된 방문객이 없습니다"),
                            systemImage: "person.crop.rectangle"
                        )
                    } else if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ContentUnavailableView(
                            String(localized: "eventMode.list.noFilterResults", defaultValue: "필터 조건에 맞는 방문객이 없습니다"),
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }
                } else {
                    ForEach(filtered) { visitor in
                        rowContent(for: visitor)
                    }
                    .onDelete { indexSet in
                        for index in indexSet { context.delete(filtered[index]) }
                        try? context.save()
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "search.prompt", defaultValue: "Search"))
        .navigationTitle(preset.name.isEmpty ? String(localized: "eventMode.list.title", defaultValue: "방문객 목록") : preset.name)
        .navigationDestination(for: UUID.self) { id in
            if let visitor = visitors.first(where: { $0.id == id }) {
                EventModeVisitorDetailView(visitor: visitor)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isSelecting ? String(localized: "action.done") : String(localized: "eventMode.list.select", defaultValue: "선택")) {
                    isSelecting.toggle()
                    if !isSelecting { selectedIDs.removeAll() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu(String(localized: "eventMode.list.filter", defaultValue: "필터"), systemImage: "line.3.horizontal.decrease.circle") {
                    Picker(String(localized: "eventMode.list.sort", defaultValue: "정렬"), selection: $sortOption) {
                        ForEach(EventVisitorSortOption.allCases) { option in
                            Text(option.localizedName).tag(option)
                        }
                    }
                    Picker(String(localized: "eventMode.list.countryFilter", defaultValue: "국가 필터"), selection: $countryFilter) {
                        Text(String(localized: "export.all")).tag(String?.none)
                        ForEach(usedCountryCodes, id: \.self) { code in
                            Text(EventCountry(code: code).localizedName).tag(String?.some(code))
                        }
                    }
                }
                .labelStyle(.iconOnly)
            }
            if !duplicateGroups.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showDuplicateMerge = true
                    } label: {
                        Label(String(localized: "eventMode.duplicate.title", defaultValue: "중복 정리"), systemImage: "arrow.triangle.merge")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showExportSheet = true
                } label: {
                    Label(String(localized: "action.export"), systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            NavigationStack {
                EventModeExportView(
                    preset: preset,
                    allVisitors: visitors,
                    filteredVisitors: filtered,
                    selectedVisitors: visitors.filter { selectedIDs.contains($0.id) }
                )
            }
        }
        .sheet(isPresented: $showDuplicateMerge) {
            EventModeDuplicateMergeView(groups: duplicateGroups) { primary, others in
                for other in others {
                    primary.absorb(other)
                    context.delete(other)
                }
                try? context.save()
            }
        }
    }

    @ViewBuilder
    private func rowContent(for visitor: EventVisitor) -> some View {
        if isSelecting {
            Button {
                if selectedIDs.contains(visitor.id) {
                    selectedIDs.remove(visitor.id)
                } else {
                    selectedIDs.insert(visitor.id)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedIDs.contains(visitor.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(visitor.id) ? Color.accentColor : Color.secondary)
                    visitorRow(visitor)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: visitor.id) {
                visitorRow(visitor)
            }
        }
    }

    private func visitorRow(_ visitor: EventVisitor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(visitor.name.isEmpty ? String(localized: "note.untitled") : visitor.name)
                    .font(.headline)
                if visitor.isDuplicateCandidate(in: visitors) {
                    Label(String(localized: "eventMode.list.duplicate", defaultValue: "중복"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(visitor.collectionMethod.localizedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if !visitor.company.isEmpty { Text(visitor.company) }
                if !visitor.jobTitle.isEmpty { Text(visitor.jobTitle) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if !visitor.email.isEmpty { Text(visitor.email) }
                if !visitor.mobile.isEmpty { Text(visitor.mobile) }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            if visitor.interestArea != nil || visitor.wantsMaterials != nil {
                HStack(spacing: 12) {
                    if let interestArea = visitor.interestArea {
                        Label(interestArea.localizedName, systemImage: interestArea.iconName)
                            .foregroundStyle(interestArea.accentColor)
                    }
                    if let wantsMaterials = visitor.wantsMaterials {
                        Label(
                            wantsMaterials
                                ? String(localized: "eventMode.list.materialsRequested", defaultValue: "자료 요청함")
                                : String(localized: "eventMode.list.materialsNotRequested", defaultValue: "자료 요청 안 함"),
                            systemImage: wantsMaterials ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        .foregroundStyle(wantsMaterials ? Color.green : Color.secondary)
                    }
                }
                .font(.caption.weight(.semibold))
            }
            Text(DateFormatter.exportTimestamp.string(from: visitor.createdAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
