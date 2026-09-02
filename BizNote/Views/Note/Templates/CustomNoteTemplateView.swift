import SwiftUI
import SwiftData
import QuickLook

struct CustomNoteTemplateView: View {
    @Binding var data: CustomNoteTemplateData
    @Binding var attachmentPaths: [String]
    @Environment(\.modelContext) private var context
    @Query(sort: \ExhibitionPreset.createdAt, order: .reverse)
    private var presets: [ExhibitionPreset]

    @State private var showAddExhibition = false
    @State private var eventPresetTargetSectionID: UUID?
    @State private var locationSearchTargetSectionID: UUID?

    var body: some View {
        Group {
            ForEach($data.sections) { $section in
                if section.isEnabled {
                    Section(section.title.isEmpty ? section.kind.defaultTitle : section.title) {
                        CustomNoteSectionContent(
                            section: $section,
                            attachmentPaths: $attachmentPaths,
                            selectedPresetDescription: selectedPresetDescription(for: section),
                            onAddEvent: { showAddExhibition = true },
                            onPickEventPreset: { eventPresetTargetSectionID = section.id },
                            onSearchLocation: { locationSearchTargetSectionID = section.id }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showAddExhibition) {
            NavigationStack {
                ExhibitionPresetEditor(preset: nil) { newPreset in
                    context.insert(newPreset)
                    try? context.save()
                    Task { await CalendarReminderSyncService.shared.syncEvent(for: newPreset) }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { locationSearchTargetSectionID != nil },
            set: { if !$0 { locationSearchTargetSectionID = nil } }
        )) {
            NavigationStack {
                LocationSearchSheet { address in
                    applyLocation(address)
                    locationSearchTargetSectionID = nil
                }
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { eventPresetTargetSectionID != nil },
            set: { if !$0 { eventPresetTargetSectionID = nil } }
        )) {
            ExhibitionPresetPickerView { preset in
                applyPreset(preset)
                eventPresetTargetSectionID = nil
            }
        }
    }

    private func selectedPresetDescription(for section: CustomNoteTemplateSection) -> String? {
        guard let presetID = section.presetID else { return nil }
        return presets.first { $0.id == presetID }?.dateRangeDescription
    }

    private func applyPreset(_ preset: ExhibitionPreset) {
        guard let sectionID = eventPresetTargetSectionID,
              let index = data.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        data.sections[index].text = preset.name
        data.sections[index].presetID = preset.id
    }

    private func applyLocation(_ address: String) {
        guard let sectionID = locationSearchTargetSectionID,
              let index = data.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        data.sections[index].text = address
    }
}

private struct CustomNoteSectionContent: View {
    @Binding var section: CustomNoteTemplateSection
    @Binding var attachmentPaths: [String]
    let selectedPresetDescription: String?
    let onAddEvent: () -> Void
    let onPickEventPreset: () -> Void
    let onSearchLocation: () -> Void

    @State private var locationService = LocationService()
    @State private var isLocating = false
    @State private var locationError: String?

    var body: some View {
        switch section.kind {
        case .date:
            DatePicker(
                String(localized: "template.item.date", defaultValue: "Date"),
                selection: dateBinding,
                displayedComponents: .date
            )
            .labelsHidden()
        case .workItems:
            workItems
        case .memo, .achievement, .work:
            TextEditor(text: $section.text)
                .frame(minHeight: editorHeight(for: section.text, minimumLines: 3))
        case .location:
            locationContent
        case .eventName:
            eventNameContent
        case .taskBoard:
            taskBoard
        case .attachments:
            AttachmentsSectionContent(attachmentPaths: $attachmentPaths)
        case .participants:
            ParticipantsSectionContent(participants: $section.participants)
        case .contacts:
            ContactsSectionContent(contacts: $section.participants)
        case .followUp:
            followUp
        case .addEvent:
            Button {
                onAddEvent()
            } label: {
                Label(String(localized: "exhibitions.add", defaultValue: "Add Event"), systemImage: "calendar.badge.plus")
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                ISO8601DateFormatter().date(from: section.text) ?? Date()
            },
            set: { newValue in
                section.text = ISO8601DateFormatter().string(from: newValue)
            }
        )
    }

    private func editorHeight(for text: String, minimumLines: Int) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }

    @ViewBuilder
    private var eventNameContent: some View {
        HStack {
            TextField(String(localized: "template.exhibition.name"), text: $section.text)
            Button {
                onPickEventPreset()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "template.exhibition.pickPreset"))
        }

        Text(selectedPresetDescription ?? String(localized: "template.exhibition.noEventDate"))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var locationContent: some View {
        HStack {
            TextField(String(localized: "template.meeting.location"), text: $section.text)
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
                onSearchLocation()
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

    private func useCurrentLocation() {
        isLocating = true
        locationError = nil
        Task {
            do {
                section.text = try await locationService.currentAddress()
            } catch {
                locationError = error.localizedDescription
            }
            isLocating = false
        }
    }

    @ViewBuilder
    private var workItems: some View {
        ForEach($section.tasks) { $task in
            VStack(alignment: .leading, spacing: 16) {
                TextField(String(localized: "template.workLog.itemPlaceholder"), text: $task.title)
                Picker(String(localized: "task.status.todo"), selection: $task.status) {
                    ForEach(CustomNoteTask.Status.allCases) { status in
                        Text(status.localizedName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 10)
        }
        .onDelete { section.tasks.remove(atOffsets: $0) }

        Button {
            section.tasks.append(CustomNoteTask())
        } label: {
            Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var taskBoard: some View {
        ForEach(CustomNoteTask.Status.allCases) { status in
            DisclosureGroup(status.localizedName) {
                ForEach($section.tasks) { $task in
                    if task.status == status {
                        taskRow($task)
                    }
                }
                Button {
                    section.tasks.append(CustomNoteTask(status: status))
                } label: {
                    Label(String(localized: "template.workLog.item.add"), systemImage: "plus")
                }
            }
        }
    }

    private func taskRow(_ task: Binding<CustomNoteTask>) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(CustomNoteTask.Status.allCases) { status in
                    Button(status.localizedName) {
                        task.wrappedValue.status = status
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle")
            }

            TextField(String(localized: "template.workLog.item.placeholder"), text: task.title, axis: .vertical)
                .lineLimit(1...3)

            Button(role: .destructive) {
                section.tasks.removeAll { $0.id == task.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var followUp: some View {
        ForEach($section.tasks) { task in
            VStack(alignment: .leading, spacing: 10) {
                TextField(String(localized: "template.exhibition.taskTitle", defaultValue: "Task"), text: task.title, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Menu {
                        ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.selectableCases) { category in
                            Button {
                                task.wrappedValue.category = category
                            } label: {
                                Label(category.localizedName, systemImage: category.systemImage)
                            }
                        }
                    } label: {
                        Label(task.wrappedValue.category.localizedName, systemImage: task.wrappedValue.category.systemImage)
                    }

                    DatePicker(
                        String(localized: "template.exhibition.taskDueDate"),
                        selection: task.dueDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    DatePicker(
                        String(localized: "deadline.time", defaultValue: "Time"),
                        selection: task.dueDate,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()

                    TextField(String(localized: "template.followUp.assignee"), text: assigneeBinding(task))
                        .textFieldStyle(.roundedBorder)

                    Button(role: .destructive) {
                        section.tasks.removeAll { $0.id == task.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }

        Button {
            section.tasks.append(CustomNoteTask())
        } label: {
            Label(String(localized: "template.workLog.item.add", defaultValue: "Add Item"), systemImage: "plus")
        }
    }

    private func assigneeBinding(_ task: Binding<CustomNoteTask>) -> Binding<String> {
        Binding(
            get: { task.wrappedValue.assignees.first ?? "" },
            set: { newValue in
                task.wrappedValue.assignees = newValue.isEmpty ? [] : [newValue]
            }
        )
    }
}

private struct ParticipantsSectionContent: View {
    @Binding var participants: [CustomNoteParticipant]

    var body: some View {
        ForEach($participants) { $participant in
            HStack(spacing: 8) {
                TextField(String(localized: "template.meeting.participant.name", defaultValue: "이름"), text: $participant.name)
                TextField(String(localized: "businessCard.jobTitle", defaultValue: "직급"), text: $participant.jobTitle)
                TextField(String(localized: "template.meeting.participant.company", defaultValue: "회사"), text: $participant.company)
                Button(role: .destructive) {
                    participants.removeAll { $0.id == participant.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
            }
        }
        Button {
            participants.append(CustomNoteParticipant())
        } label: {
            Label(String(localized: "template.meeting.participants.add", defaultValue: "참석자 추가"), systemImage: "plus")
        }
    }
}

private struct ContactsSectionContent: View {
    @Binding var contacts: [CustomNoteParticipant]
    @State private var importTargetContactID: UUID?

    private static let countryNames: [String] = {
        let locale = Locale.current
        let names = Locale.Region.isoRegions.compactMap { locale.localizedString(forRegionCode: $0.identifier) }
        return Array(Set(names)).sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }()

    var body: some View {
        ForEach($contacts) { $contact in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    countryMenu(for: $contact.country)
                    Button {
                        importTargetContactID = contact.id
                    } label: {
                        Image(systemName: "person.crop.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "businessCard.importFromCard"))
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
                        .frame(minHeight: editorHeight(for: contact.memo, minimumLines: 2))
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary)
                        )
                }

                Button(role: .destructive) {
                    contacts.removeAll { $0.id == contact.id }
                } label: {
                    Label(String(localized: "action.delete"), systemImage: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 6)
        }

        Button {
            contacts.append(CustomNoteParticipant())
        } label: {
            Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
        }
        .navigationDestination(isPresented: Binding(
            get: { importTargetContactID != nil },
            set: { if !$0 { importTargetContactID = nil } }
        )) {
            BusinessCardImportPickerView { card in
                applyBusinessCard(card)
                importTargetContactID = nil
            }
        }
    }

    private func applyBusinessCard(_ card: BusinessCard) {
        guard let importTargetContactID,
              let index = contacts.firstIndex(where: { $0.id == importTargetContactID }) else { return }
        contacts[index].company = card.company
        contacts[index].name = card.name
        contacts[index].jobTitle = card.jobTitle
        contacts[index].email = card.email
        contacts[index].phone = card.phone.isEmpty ? card.officePhone : card.phone
    }

    private func countryMenu(for country: Binding<String>) -> some View {
        Menu {
            ForEach(Self.countryNames, id: \.self) { option in
                Button {
                    country.wrappedValue = option
                } label: {
                    Text(option)
                }
            }
        } label: {
            HStack {
                Text(country.wrappedValue.isEmpty
                     ? String(localized: "template.exhibition.country")
                     : country.wrappedValue)
                    .foregroundStyle(country.wrappedValue.isEmpty ? .secondary : .primary)
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
    }

    private func editorHeight(for text: String, minimumLines: Int) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }
}

private struct AttachmentsSectionContent: View {
    @Binding var attachmentPaths: [String]
    @State private var showImporter = false
    @State private var previewPath: String?

    var body: some View {
        ForEach(attachmentPaths, id: \.self) { path in
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                Text(AttachmentStorage.attachmentDisplayName(path: path))
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    previewPath = path
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.plain)
                Button(role: .destructive) {
                    AttachmentStorage.removeAttachment(path: path)
                    attachmentPaths.removeAll { $0 == path }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
            }
        }

        Button {
            showImporter = true
        } label: {
            Label(String(localized: "template.workLog.attachments.add", defaultValue: "파일 추가"), systemImage: "paperclip")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let path = AttachmentStorage.saveAttachment(from: url) {
                    attachmentPaths.append(path)
                }
            }
        }
        .sheet(item: Binding(
            get: { previewPath.map { AttachmentPreviewItem(path: $0) } },
            set: { previewPath = $0?.path }
        )) { item in
            QuickLookPreview(url: AttachmentStorage.fileURL(path: item.path))
        }
    }
}

private struct AttachmentPreviewItem: Identifiable {
    let path: String
    var id: String { path }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
