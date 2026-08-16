import SwiftUI
import SwiftData

struct ExhibitionTemplateSection: View {
    @Bindable var note: Note
    var onChange: () -> Void
    var onPickPreset: (@escaping (ExhibitionPreset) -> Void) -> Void

    @Query(sort: \ExhibitionPreset.createdAt, order: .reverse)
    private var presets: [ExhibitionPreset]

    @State private var data: ExhibitionTemplateData
    @State private var cardImportTarget: ExhibitionCardImportTarget?
    @State private var showCardImporter: Bool = false

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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle(String(localized: "task.status.done"), isOn: $task.isCompleted).labelsHidden()
                        TextField(String(localized: "template.exhibition.taskTitle"), text: $task.title)
                            .textFieldStyle(.roundedBorder)
                    }
                    Picker(String(localized: "note.category"), selection: $task.category) {
                        ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.allCases) { c in
                            Label(c.localizedName, systemImage: c.systemImage).tag(c)
                        }
                    }
                    DatePicker(
                        String(localized: "template.exhibition.taskDueDate"),
                        selection: $task.dueDate,
                        displayedComponents: [.date]
                    )
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
                onApplyPreset(newPreset)
                showAddPreset = false
            }
        }
    }
}

private struct BusinessCardImportPickerView: View {
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
            HStack {
                TextField("#", text: $booth.boothNumber)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "businessCard.company"), text: $booth.companyName)
                    .textFieldStyle(.roundedBorder)
            }
            TextField(String(localized: "businessCard.name"), text: $booth.contactPerson)
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
            HStack {
                Text(verbatim: "\(String(localized: "template.exhibition.interestPrefix")) \(booth.interestLevel)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Slider(value: Binding(
                    get: { Double(booth.interestLevel) },
                    set: { booth.interestLevel = Int($0) }
                ), in: 1...5, step: 1)
            }
            TextField(String(localized: "businessCard.memo"),
                      text: $booth.notes, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)

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
}

private struct ContactRow: View {
    @Binding var contact: ExhibitionTemplateData.Contact
    var onImportCard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: "template.exhibition.country"), text: $contact.country)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.name"), text: $contact.name)
                .textFieldStyle(.roundedBorder)
            TextField(String(localized: "businessCard.company"), text: $contact.company)
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
            TextField(String(localized: "businessCard.memo"), text: $contact.memo, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)

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
                TextField(String(localized: "exhibitionPreset.venue"), text: $venue)
            }
            Section(String(localized: "exhibitionPreset.organizer")) {
                TextField(String(localized: "exhibitionPreset.organizer"), text: $organizer)
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
                    onSave(target)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let preset {
                name = preset.name
                startDate = preset.startDate
                endDate = preset.endDate
                venue = preset.venue
                organizer = preset.organizer
            }
        }
    }
}
