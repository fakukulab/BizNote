import SwiftUI
import SwiftData
import Foundation

private enum ExhibitionDeadlineOption: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case nextWeek
    case custom

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .today: return String(localized: "deadline.today", defaultValue: "Today")
        case .tomorrow: return String(localized: "deadline.tomorrow", defaultValue: "Tomorrow")
        case .nextWeek: return String(localized: "deadline.nextWeek", defaultValue: "Next Week")
        case .custom: return String(localized: "deadline.custom", defaultValue: "Custom")
        }
    }
}

struct ExhibitionTemplateSection: View {
    @Bindable var note: Note
    var onChange: () -> Void
    var onPickPreset: (@escaping (ExhibitionPreset) -> Void) -> Void

    @Query(sort: \ExhibitionPreset.createdAt, order: .reverse)
    private var presets: [ExhibitionPreset]

    @State private var data: ExhibitionTemplateData
    @State private var cardImportTarget: ExhibitionCardImportTarget?
    @State private var showCardImporter: Bool = false
    @State private var deadlineOptions: [UUID: ExhibitionDeadlineOption] = [:]

    init(
        note: Note,
        onChange: @escaping () -> Void,
        onPickPreset: @escaping (@escaping (ExhibitionPreset) -> Void) -> Void
    ) {
        self.note = note
        self.onChange = onChange
        self.onPickPreset = onPickPreset
        _data = State(initialValue: TemplateCoder.decode(ExhibitionTemplateData.self, from: note.templateData) ?? .init())
    }

    var body: some View {
        Group {
            ExhibitionNamePresetSection(
                exhibitionName: $data.exhibitionName,
                selectedPresetDescription: selectedPreset?.dateRangeDescription,
                onPickPreset: onPickPreset
            ) { preset in
                applyPreset(preset)
            }

            Section(String(localized: "template.exhibition.venue")) {
                TextField(String(localized: "template.exhibition.venue"), text: $data.venue)
            }
            Section(String(localized: "template.exhibition.organizer")) {
                TextField(String(localized: "template.exhibition.organizer"), text: $data.organizer)
            }
            Section(String(localized: "exhibitions.supervisor", defaultValue: "Organizer")) {
                TextField(String(localized: "exhibitions.supervisor", defaultValue: "Organizer"), text: $data.supervisor)
            }

            Section(String(localized: "template.exhibition.participationType")) {
                Picker(String(localized: "template.exhibition.participationType"), selection: $data.participationType) {
                    ForEach(ExhibitionTemplateData.ParticipationType.allCases) { t in
                        Text(t.localizedName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "template.exhibition.participatingDate")) {
                DatePicker(
                    String(localized: "template.exhibition.participatingDate"),
                    selection: $data.participatingDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
            }

            if data.participationType == .visitor {
                visitedBoothsSection()
            } else {
                contactsSection()
            }

            tasksSection()
        }
        .navigationDestination(isPresented: $showCardImporter) {
            if let cardImportTarget {
                BusinessCardImportPickerView { card in
                    applyBusinessCard(card, to: cardImportTarget)
                    showCardImporter = false
                    self.cardImportTarget = nil
                }
            }
        }
        .onChange(of: data) { _, _ in save() }
    }

    @ViewBuilder
    private func visitedBoothsSection() -> some View {
        Section(String(localized: "template.exhibition.booths")) {
            ForEach($data.visitedBooths) { $booth in
                VisitedBoothRow(booth: $booth) {
                    cardImportTarget = .booth(booth.id)
                    showCardImporter = true
                }
            }
            .onDelete { data.visitedBooths.remove(atOffsets: $0) }

            Button {
                data.visitedBooths.append(.init())
            } label: {
                Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
            }
        }
    }

    @ViewBuilder
    private func contactsSection() -> some View {
        Section(String(localized: "template.exhibition.contacts")) {
            ForEach($data.contacts) { $contact in
                ContactRow(contact: $contact) {
                    cardImportTarget = .contact(contact.id)
                    showCardImporter = true
                }
            }
            .onDelete { data.contacts.remove(atOffsets: $0) }

            Button {
                data.contacts.append(.init())
            } label: {
                Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
            }
        }
    }

    @ViewBuilder
    private func tasksSection() -> some View {
        Section(String(localized: "template.exhibition.tasks")) {
            ForEach($data.tasks) { $task in
                VStack(alignment: .leading, spacing: 10) {
                    TextField(String(localized: "template.exhibition.taskTitle"), text: $task.title)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Menu {
                            Text(String(localized: "note.category", defaultValue: "Category"))
                                .foregroundStyle(.secondary)
                                .disabled(true)
                            Divider()
                            ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.selectableCases) { category in
                                Button {
                                    task.category = category
                                } label: {
                                    Label(category.localizedName, systemImage: category.systemImage)
                                }
                            }
                        } label: {
                            Label(task.category.localizedName, systemImage: task.category.systemImage)
                        }

                        Menu {
                            Text(String(localized: "deadline.title", defaultValue: "Deadline"))
                                .foregroundStyle(.secondary)
                                .disabled(true)
                            Divider()
                            ForEach(ExhibitionDeadlineOption.allCases) { option in
                                Button {
                                    deadlineOptions[task.id] = option
                                    applyDeadlineOption(option, to: $task.dueDate)
                                } label: {
                                    Text(option.localizedName)
                                }
                            }
                        } label: {
                            Label(
                                selectedDeadlineOption(for: task.id, dueDate: task.dueDate).localizedName,
                                systemImage: "calendar"
                            )
                        }

                        if selectedDeadlineOption(for: task.id, dueDate: task.dueDate) == .custom {
                            DatePicker(
                                String(localized: "template.exhibition.taskDueDate"),
                                selection: $task.dueDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        } else {
                            Text(shortDateString(for: task.dueDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        DatePicker(
                            String(localized: "deadline.time", defaultValue: "Time"),
                            selection: $task.dueDate,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()

                        TextField(String(localized: "template.followUp.assignee"), text: assigneeBinding($task))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { data.tasks.remove(atOffsets: $0) }

            Button {
                data.tasks.append(.init())
            } label: {
                Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
            }
        }
    }

    private var selectedPreset: ExhibitionPreset? {
        guard let id = data.presetID else { return nil }
        return presets.first { $0.id == id }
    }

    private func applyPreset(_ preset: ExhibitionPreset) {
        data.exhibitionName = preset.name
        data.participatingDate = preset.startDate
        data.venue = preset.venue
        data.organizer = preset.organizer
        data.supervisor = preset.supervisor
        data.presetID = preset.id
    }

    private func applyBusinessCard(_ card: BusinessCard, to target: ExhibitionCardImportTarget) {
        switch target {
        case .booth(let id):
            guard let index = data.visitedBooths.firstIndex(where: { $0.id == id }) else { return }
            data.visitedBooths[index].companyName = card.company
            data.visitedBooths[index].contactPerson = card.name
            data.visitedBooths[index].contactEmail = card.email
            data.visitedBooths[index].contactPhone = card.phone.isEmpty ? card.officePhone : card.phone
            data.visitedBooths[index].linkedCardID = card.id
        case .contact(let id):
            guard let index = data.contacts.firstIndex(where: { $0.id == id }) else { return }
            data.contacts[index].name = card.name
            data.contacts[index].company = card.company
            data.contacts[index].jobTitle = card.jobTitle
            data.contacts[index].email = card.email
            data.contacts[index].phone = card.phone.isEmpty ? card.officePhone : card.phone
            data.contacts[index].linkedCardID = card.id
        }
    }

    private func save() {
        note.templateData = TemplateCoder.encode(data)
        onChange()
        syncReminders()
    }

    private func syncReminders() {
        for item in data.tasks where !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let itemID = item.id
            Task {
                let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                    title: item.title,
                    detail: item.detail,
                    assignees: item.assignees,
                    dueDate: item.dueDate,
                    isCompleted: item.isCompleted,
                    existingIdentifier: item.reminderIdentifier
                )
                guard let reminderID,
                      let index = data.tasks.firstIndex(where: { $0.id == itemID }),
                      data.tasks[index].reminderIdentifier != reminderID else { return }
                data.tasks[index].reminderIdentifier = reminderID
            }
        }
    }

    private func assigneeBinding(_ task: Binding<ExhibitionTemplateData.TaskItem>) -> Binding<String> {
        Binding(
            get: { task.wrappedValue.assignees.first ?? "" },
            set: { newValue in
                task.wrappedValue.assignees = newValue.isEmpty ? [] : [newValue]
            }
        )
    }

    private func deadlineBinding(id: UUID, dueDate: Binding<Date>) -> Binding<ExhibitionDeadlineOption> {
        Binding(
            get: { selectedDeadlineOption(for: id, dueDate: dueDate.wrappedValue) },
            set: { option in
                deadlineOptions[id] = option
                applyDeadlineOption(option, to: dueDate)
            }
        )
    }

    private func selectedDeadlineOption(for id: UUID, dueDate: Date) -> ExhibitionDeadlineOption {
        deadlineOptions[id] ?? deadlineOption(for: dueDate)
    }

    private func deadlineOption(for date: Date) -> ExhibitionDeadlineOption {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)

        if selectedDay == today {
            return .today
        }
        if selectedDay == tomorrow {
            return .tomorrow
        }
        if selectedDay == nextWeek {
            return .nextWeek
        }
        return .custom
    }

    private func applyDeadlineOption(_ option: ExhibitionDeadlineOption, to dueDate: Binding<Date>) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate: Date?

        switch option {
        case .today:
            targetDate = today
        case .tomorrow:
            targetDate = calendar.date(byAdding: .day, value: 1, to: today)
        case .nextWeek:
            targetDate = calendar.date(byAdding: .day, value: 7, to: today)
        case .custom:
            targetDate = nil
        }

        if let targetDate {
            dueDate.wrappedValue = date(targetDate, withTimeFrom: dueDate.wrappedValue)
        }
    }

    private func date(_ date: Date, withTimeFrom original: Date) -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: original)
        return calendar.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: 0,
            of: date
        ) ?? date
    }

    private func shortDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: date)
    }
}

private enum ExhibitionCardImportTarget: Identifiable {
    case booth(UUID)
    case contact(UUID)

    var id: String {
        switch self {
        case .booth(let id): return "booth-\(id.uuidString)"
        case .contact(let id): return "contact-\(id.uuidString)"
        }
    }
}

private struct ExhibitionNamePresetSection: View {
    @Binding var exhibitionName: String
    let selectedPresetDescription: String?
    var onPickPreset: (@escaping (ExhibitionPreset) -> Void) -> Void
    var onApplyPreset: (ExhibitionPreset) -> Void

    var body: some View {
        Group {
            Section {
                HStack {
                    TextField(String(localized: "template.exhibition.name"), text: $exhibitionName)
                    Button {
                        onPickPreset { preset in
                            onApplyPreset(preset)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text(String(localized: "template.exhibition.name"))
            } footer: {
                Text(String(localized: "template.exhibition.presetHint"))
                    .font(.caption)
            }

            Section(String(localized: "template.exhibition.eventDate")) {
                Text(selectedPresetDescription ?? String(localized: "template.exhibition.noEventDate"))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ExhibitionPresetPickerView: View {
    var onApplyPreset: (ExhibitionPreset) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \ExhibitionPreset.createdAt, order: .reverse)
    private var presets: [ExhibitionPreset]

    @State private var showAddPreset: Bool = false

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
                        onApplyPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name.isEmpty ? "-" : preset.name)
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
                    }
                }
            }
        }
        .navigationTitle(String(localized: "template.exhibition.pickPreset"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddPreset = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showAddPreset) {
            ExhibitionPresetEditor(preset: nil) { newPreset in
                context.insert(newPreset)
                try? context.save()
                Task { await CalendarReminderSyncService.shared.syncEvent(for: newPreset) }
                onApplyPreset(newPreset)
                showAddPreset = false
            }
        }
    }
}

struct BusinessCardImportPickerView: View {
    var onSelect: (BusinessCard) -> Void

    @Query(sort: \BusinessCard.createdAt, order: .reverse)
    private var cards: [BusinessCard]

    var body: some View {
        List {
            if cards.isEmpty {
                ContentUnavailableView(
                    String(localized: "businessCard.empty"),
                    systemImage: "person.crop.rectangle",
                    description: Text(String(localized: "action.scanCard"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(cards) { card in
                    Button {
                        onSelect(card)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name.isEmpty ? String(localized: "businessCard.name") : card.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if !card.company.isEmpty || !card.jobTitle.isEmpty {
                                HStack(spacing: 8) {
                                    if !card.company.isEmpty {
                                        Text(card.company)
                                    }
                                    if !card.jobTitle.isEmpty {
                                        Text(card.jobTitle)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.subheadline)
                            }
                            if !card.email.isEmpty || !card.phone.isEmpty || !card.officePhone.isEmpty {
                                Text([card.email, card.phone.isEmpty ? card.officePhone : card.phone]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "businessCard.select"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VisitedBoothRow: View {
    @Binding var booth: ExhibitionTemplateData.VisitedBooth
    var onImportCard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: "businessCard.company"), text: $booth.companyName)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.name"), text: $booth.contactPerson)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.jobTitle"), text: $booth.jobTitle)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.email"), text: $booth.contactEmail)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField(String(localized: "businessCard.phone"), text: $booth.contactPhone)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
            TextField(String(localized: "template.exhibition.productsServices"),
                      text: $booth.productsServices, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "businessCard.memo"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $booth.notes)
                    .frame(minHeight: editorHeight(for: booth.notes))
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary)
                    )
            }

            Button {
                onImportCard()
            } label: {
                Label(String(localized: "businessCard.importFromCard"), systemImage: "person.crop.rectangle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }

    private func editorHeight(for text: String, minimumLines: Int = 2) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }
}

private struct ContactRow: View {
    @Binding var contact: ExhibitionTemplateData.Contact
    var onImportCard: () -> Void

    private static let countryNames: [String] = {
        let locale = Locale.current
        let names = Locale.Region.isoRegions.compactMap { locale.localizedString(forRegionCode: $0.identifier) }
        return Array(Set(names)).sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(Self.countryNames, id: \.self) { country in
                    Button {
                        contact.country = country
                    } label: {
                        Text(country)
                    }
                }
            } label: {
                HStack {
                    Text(contact.country.isEmpty
                         ? String(localized: "template.exhibition.country")
                         : contact.country)
                        .foregroundStyle(contact.country.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary)
                )
            }
            TextField(String(localized: "businessCard.company"), text: $contact.company)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.name"), text: $contact.name)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.jobTitle"), text: $contact.jobTitle)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.email"), text: $contact.email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField(String(localized: "businessCard.phone"), text: $contact.phone)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "businessCard.memo"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $contact.memo)
                    .frame(minHeight: editorHeight(for: contact.memo))
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary)
                    )
            }

            Button {
                onImportCard()
            } label: {
                Label(String(localized: "businessCard.importFromCard"), systemImage: "person.crop.rectangle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }

    private func editorHeight(for text: String, minimumLines: Int = 2) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }
}

struct ExhibitionPresetEditor: View {
    let preset: ExhibitionPreset?
    var onSave: (ExhibitionPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var venue: String = ""
    @State private var organizer: String = ""
    @State private var introduction: String = ""
    @State private var exhibitItems: String = ""
    @State private var supervisor: String = ""
    @State private var contact: String = ""
    @State private var homepage: String = ""
    @State private var locationService = LocationService()
    @State private var isLocating = false
    @State private var locationError: String?
    @State private var showLocationSearch = false

    private func editorHeight(for text: String, minimumLines: Int = 2) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }

    var body: some View {
        Form {
            Section(String(localized: "exhibitionPreset.name")) {
                TextField(String(localized: "exhibitionPreset.name"), text: $name)
            }
            Section(String(localized: "exhibitionPreset.date")) {
                DatePicker(String(localized: "exhibitionPreset.startDate"),
                           selection: $startDate, displayedComponents: [.date])
                DatePicker(String(localized: "exhibitionPreset.endDate"),
                           selection: $endDate,
                           in: startDate...,
                           displayedComponents: [.date])
            }
            Section(String(localized: "exhibitionPreset.venue")) {
                HStack {
                    TextField(String(localized: "exhibitionPreset.venue"), text: $venue)

                    Button {
                        useCurrentLocation()
                    } label: {
                        if isLocating {
                            ProgressView()
                        } else {
                            Image(systemName: "location.fill")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLocating)
                    .accessibilityLabel(String(localized: "template.meeting.useCurrentLocation"))

                    Button {
                        showLocationSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "template.meeting.searchLocation"))
                }

                if let locationError {
                    Text(locationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section(String(localized: "exhibitions.introduction", defaultValue: "Event Introduction")) {
                TextEditor(text: $introduction)
                    .frame(minHeight: editorHeight(for: introduction))
            }
            Section(String(localized: "exhibitions.exhibitItems", defaultValue: "Exhibit Items")) {
                TextEditor(text: $exhibitItems)
                    .frame(minHeight: editorHeight(for: exhibitItems))
            }
            Section(String(localized: "exhibitionPreset.organizer")) {
                TextField(String(localized: "exhibitionPreset.organizer"), text: $organizer)
            }
            Section(String(localized: "exhibitions.supervisor", defaultValue: "Organizer")) {
                TextField(String(localized: "exhibitions.supervisor", defaultValue: "Organizer"), text: $supervisor)
            }
            Section(String(localized: "exhibitions.contact", defaultValue: "Contact")) {
                TextField(String(localized: "exhibitions.contact", defaultValue: "Contact"), text: $contact)
            }
            Section(String(localized: "exhibitions.homepage", defaultValue: "Homepage")) {
                TextField(String(localized: "exhibitions.homepage", defaultValue: "Homepage"), text: $homepage)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle(preset == nil
                         ? String(localized: "settings.addPreset")
                         : String(localized: "action.edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "action.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "action.save")) {
                    let target = preset ?? ExhibitionPreset()
                    target.name = name
                    target.startDate = startDate
                    target.endDate = max(startDate, endDate)
                    target.venue = venue
                    target.organizer = organizer
                    target.introduction = introduction
                    target.exhibitItems = exhibitItems
                    target.supervisor = supervisor
                    target.contact = contact
                    target.homepage = homepage
                    onSave(target)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showLocationSearch) {
            NavigationStack {
                LocationSearchSheet { address in
                    venue = address
                    showLocationSearch = false
                }
            }
        }
        .onAppear {
            if let preset {
                name = preset.name
                startDate = preset.startDate
                endDate = preset.endDate
                venue = preset.venue
                organizer = preset.organizer
                introduction = preset.introduction
                exhibitItems = preset.exhibitItems
                supervisor = preset.supervisor
                contact = preset.contact
                homepage = preset.homepage
            }
        }
    }

    private func useCurrentLocation() {
        isLocating = true
        locationError = nil
        Task {
            do {
                venue = try await locationService.currentAddress()
            } catch {
                locationError = error.localizedDescription
            }
            isLocating = false
        }
    }
}
