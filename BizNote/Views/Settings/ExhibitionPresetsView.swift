import SwiftUI
import SwiftData

struct ExhibitionPresetsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExhibitionPreset.startDate) private var presets: [ExhibitionPreset]

    @Binding private var selectedPresetID: UUID?
    private let usesExternalSelection: Bool

    @State private var showAdd: Bool = false
    @State private var searchText: String = ""
    @State private var periodFilter: ExhibitionPeriodFilter = .threeMonths
    @State private var customStartDate = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate = Calendar.current.date(byAdding: .month, value: 3, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var displayedCalendarMonth: Date = Date()

    init(selectedPresetID: Binding<UUID?>? = nil) {
        self._selectedPresetID = selectedPresetID ?? .constant(nil)
        self.usesExternalSelection = selectedPresetID != nil
    }

    var body: some View {
        List {
            Section {
                Group {
                    if usesExternalSelection {
                        MonthlyCalendarView(
                            events: sortedPresets.map {
                                MonthlyCalendarEvent(
                                    id: $0.id,
                                    range: Calendar.current.startOfDay(for: $0.startDate)...Calendar.current.startOfDay(for: $0.endDate)
                                )
                            },
                            displayedMonth: $displayedCalendarMonth,
                            selectedEventID: $selectedPresetID
                        )
                    } else {
                        MonthlyCalendarView(
                            eventRanges: sortedPresets.map {
                                Calendar.current.startOfDay(for: $0.startDate)...Calendar.current.startOfDay(for: $0.endDate)
                            },
                            displayedMonth: $displayedCalendarMonth
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Picker(String(localized: "export.periodLabel", defaultValue: "Period"), selection: $periodFilter) {
                    ForEach(ExhibitionPeriodFilter.predefined) { filter in
                        Text(filter.localizedName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: periodFilter) { _, newValue in
                    recalculateEndDate(for: newValue)
                }

                HStack {
                    DatePicker(String(localized: "exhibitionPreset.startDate"),
                               selection: $customStartDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("-").foregroundStyle(.secondary)
                    DatePicker(String(localized: "exhibitionPreset.endDate"),
                               selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                        .labelsHidden()
                }
            }

            Section {
                if filteredPresets.isEmpty {
                    ContentUnavailableView(
                        String(localized: "exhibitionPreset.empty"),
                        systemImage: "building.columns",
                        description: Text(String(localized: "settings.addPreset"))
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredPresets) { preset in
                        if usesExternalSelection {
                            Button {
                                selectedPresetID = preset.id
                            } label: {
                                presetRow(preset)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selectedPresetID == preset.id ? Color.accentColor.opacity(0.12) : Color.clear)
                        } else {
                            NavigationLink {
                                ExhibitionDetailView(preset: preset)
                            } label: {
                                presetRow(preset)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        let toDelete = indexSet.map { filteredPresets[$0] }
                        Task {
                            for preset in toDelete {
                                await CalendarReminderSyncService.shared.removeEvent(for: preset)
                            }
                            for preset in toDelete {
                                ExhibitionLogoStorage.remove(path: preset.logoImagePath)
                                context.delete(preset)
                            }
                            try? context.save()
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "search.prompt", defaultValue: "Search"))
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
                    Task { await CalendarReminderSyncService.shared.syncEvent(for: newPreset) }
                }
            }
        }
        .onAppear {
            recalculateEndDate(for: periodFilter)
        }
        .onChange(of: customStartDate) { _, newValue in
            customStartDate = Calendar.current.startOfDay(for: newValue)
            if let months = periodFilter.months {
                customEndDate = endDate(from: customStartDate, addingMonths: months)
            } else if customEndDate < customStartDate {
                customEndDate = customStartDate
            }
        }
    }

    @ViewBuilder
    private func presetRow(_ preset: ExhibitionPreset) -> some View {
        HStack(spacing: 12) {
            logoThumbnail(for: preset)
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
                if !preset.organizer.isEmpty {
                    Text(preset.organizer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func logoThumbnail(for preset: ExhibitionPreset) -> some View {
        if let image = ExhibitionLogoStorage.load(path: preset.logoImagePath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var sortedPresets: [ExhibitionPreset] {
        presets.sorted {
            if $0.startDate == $1.startDate {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.startDate < $1.startDate
        }
    }

    private var filteredPresets: [ExhibitionPreset] {
        sortedPresets.filter { matchesSearch($0) && matchesPeriod($0) }
    }

    private func matchesSearch(_ preset: ExhibitionPreset) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return [
            preset.name,
            preset.venue,
            preset.introduction,
            preset.exhibitItems,
            preset.organizer,
            preset.supervisor,
            preset.contact,
            preset.homepage
        ]
        .joined(separator: " ")
        .lowercased()
        .contains(query)
    }

    private func matchesPeriod(_ preset: ExhibitionPreset) -> Bool {
        let start = Calendar.current.startOfDay(for: min(customStartDate, customEndDate))
        let endBase = Calendar.current.startOfDay(for: max(customStartDate, customEndDate))
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endBase) ?? endBase
        return preset.startDate <= end && preset.endDate >= start
    }

    private func recalculateEndDate(for filter: ExhibitionPeriodFilter) {
        guard let months = filter.months else { return }
        customEndDate = endDate(from: customStartDate, addingMonths: months)
    }

    private func endDate(from startDate: Date, addingMonths months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: Calendar.current.startOfDay(for: startDate)) ?? startDate
    }
}

enum ExhibitionPeriodFilter: String, CaseIterable, Identifiable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case custom

    static let predefined: [ExhibitionPeriodFilter] = [.oneMonth, .threeMonths, .sixMonths, .oneYear]

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .oneMonth:
            return String(localized: "exhibitions.period.oneMonth", defaultValue: "1 month")
        case .threeMonths:
            return String(localized: "exhibitions.period.threeMonths", defaultValue: "3 months")
        case .sixMonths:
            return String(localized: "exhibitions.period.sixMonths", defaultValue: "6 months")
        case .oneYear:
            return String(localized: "exhibitions.period.oneYear", defaultValue: "1 year")
        case .custom:
            return String(localized: "exhibitions.period.custom", defaultValue: "Custom")
        }
    }

    var months: Int? {
        switch self {
        case .oneMonth:
            return 1
        case .threeMonths:
            return 3
        case .sixMonths:
            return 6
        case .oneYear:
            return 12
        case .custom:
            return nil
        }
    }
}
