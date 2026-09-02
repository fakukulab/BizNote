import SwiftUI
import Contacts

private enum FollowUpDeadlineOption: String, CaseIterable, Identifiable {
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

struct MeetingMinutesTemplateSection: View {
    @Bindable var note: Note
    var onChange: () -> Void
    var onSearchLocation: (@escaping (String) -> Void) -> Void

    @State private var data: MeetingMinutesTemplateData
    @State private var participantInput: String = ""
    @State private var discussionInput: String = ""
    @State private var decisionInput: String = ""
    @State private var locationService = LocationService()
    @State private var isLocating: Bool = false
    @State private var locationError: String? = nil
    @State private var showContactPicker = false
    @State private var showCardImporter = false
    @State private var deadlineOptions: [UUID: FollowUpDeadlineOption] = [:]

    init(
        note: Note,
        onChange: @escaping () -> Void,
        onSearchLocation: @escaping (@escaping (String) -> Void) -> Void
    ) {
        self.note = note
        self.onChange = onChange
        self.onSearchLocation = onSearchLocation
        _data = State(initialValue: TemplateCoder.decode(MeetingMinutesTemplateData.self, from: note.templateData) ?? .init())
    }

    var body: some View {
        Group {
            Section(String(localized: "template.meeting.date")) {
                DatePicker(
                    String(localized: "template.meeting.date"),
                    selection: $data.meetingDate
                )
                .labelsHidden()
            }

            Section(String(localized: "template.meeting.location")) {
                HStack {
                    TextField(String(localized: "template.meeting.location"), text: $data.location)
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
                        onSearchLocation { address in
                            data.location = address
                        }
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

            Section(String(localized: "template.meeting.participants")) {
                ForEach(data.participants.indices, id: \.self) { i in
                    Text(data.participants[i].name)
                }
                .onDelete { data.participants.remove(atOffsets: $0) }

                HStack {
                    TextField(String(localized: "template.meeting.participants"), text: $participantInput)
                    Spacer()
                    Button {
                        showContactPicker = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "contacts.import", defaultValue: "Import from Contacts"))

                    Button {
                        showCardImporter = true
                    } label: {
                        Image(systemName: "person.crop.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "businessCard.importFromCard"))

                    Button {
                        addParticipant()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(participantInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section(String(localized: "template.meeting.agenda")) {
                TextEditor(text: $data.agenda)
                    .frame(minHeight: editorHeight(for: data.agenda))
            }

            Section(String(localized: "template.meeting.discussion")) {
                ForEach(data.discussionPoints.indices, id: \.self) { i in
                    Text(verbatim: "\(String(localized: "list.bulletPrefix")) \(data.discussionPoints[i])")
                }
                .onDelete { data.discussionPoints.remove(atOffsets: $0) }

                HStack {
                    TextField(String(localized: "template.meeting.discussion"), text: $discussionInput)
                    Button {
                        addDiscussion()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(discussionInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section(String(localized: "template.meeting.decisions")) {
                ForEach(data.decisions.indices, id: \.self) { i in
                    Text(verbatim: "\(String(localized: "list.bulletPrefix")) \(data.decisions[i])")
                }
                .onDelete { data.decisions.remove(atOffsets: $0) }

                HStack {
                    TextField(String(localized: "template.meeting.decisions"), text: $decisionInput)
                    Button {
                        addDecision()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(decisionInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section(String(localized: "template.meeting.actions")) {
                ForEach($data.actionItems) { $item in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(String(localized: "template.exhibition.taskTitle"), text: $item.task)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 8) {
                            Menu {
                                Text(String(localized: "note.category", defaultValue: "Category"))
                                    .foregroundStyle(.secondary)
                                    .disabled(true)
                                Divider()
                                ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.selectableCases) { category in
                                    Button {
                                        item.category = category
                                    } label: {
                                        Label(category.localizedName, systemImage: category.systemImage)
                                    }
                                }
                            } label: {
                                Label(item.category.localizedName, systemImage: item.category.systemImage)
                            }

                            Menu {
                                Text(String(localized: "deadline.title", defaultValue: "Deadline"))
                                    .foregroundStyle(.secondary)
                                    .disabled(true)
                                Divider()
                                ForEach(FollowUpDeadlineOption.allCases) { option in
                                    Button {
                                        deadlineOptions[item.id] = option
                                        applyDeadlineOption(option, to: $item.dueDate)
                                    } label: {
                                        Text(option.localizedName)
                                    }
                                }
                            } label: {
                                Label(
                                    selectedDeadlineOption(for: item.id, dueDate: item.dueDate).localizedName,
                                    systemImage: "calendar"
                                )
                            }

                            if selectedDeadlineOption(for: item.id, dueDate: item.dueDate) == .custom {
                                DatePicker(
                                    String(localized: "template.exhibition.taskDueDate"),
                                    selection: $item.dueDate,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                            } else {
                                Text(shortDateString(for: item.dueDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            DatePicker(
                                String(localized: "deadline.time", defaultValue: "Time"),
                                selection: $item.dueDate,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()

                            TextField(String(localized: "template.followUp.assignee"), text: assigneeBinding($item))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { data.actionItems.remove(atOffsets: $0) }

                Button {
                    data.actionItems.append(.init())
                } label: {
                    Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
                }
            }
        }
        .onChange(of: data) { _, _ in save() }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { contact in
                addParticipant(from: contact)
                showContactPicker = false
            }
        }
        .navigationDestination(isPresented: $showCardImporter) {
            BusinessCardImportPickerView { card in
                addParticipant(from: card)
                showCardImporter = false
            }
        }
    }

    private func addParticipant() {
        let trimmed = participantInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var participant = MeetingMinutesTemplateData.Participant()
        participant.name = trimmed
        data.participants.append(participant)
        participantInput = ""
    }

    private func addParticipant(from contact: CNContact) {
        var participant = MeetingMinutesTemplateData.Participant()
        participant.name = contact.displayName
        data.participants.append(participant)
    }

    private func addParticipant(from card: BusinessCard) {
        var participant = MeetingMinutesTemplateData.Participant()
        participant.name = card.name
        data.participants.append(participant)
    }

    private func assigneeBinding(_ item: Binding<MeetingMinutesTemplateData.ActionItem>) -> Binding<String> {
        Binding(
            get: { item.wrappedValue.assignees.first ?? "" },
            set: { newValue in
                item.wrappedValue.assignees = newValue.isEmpty ? [] : [newValue]
            }
        )
    }

    private func deadlineBinding(id: UUID, dueDate: Binding<Date>) -> Binding<FollowUpDeadlineOption> {
        Binding(
            get: { selectedDeadlineOption(for: id, dueDate: dueDate.wrappedValue) },
            set: { option in
                deadlineOptions[id] = option
                applyDeadlineOption(option, to: dueDate)
            }
        )
    }

    private func selectedDeadlineOption(for id: UUID, dueDate: Date) -> FollowUpDeadlineOption {
        deadlineOptions[id] ?? deadlineOption(for: dueDate)
    }

    private func deadlineOption(for date: Date) -> FollowUpDeadlineOption {
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

    private func applyDeadlineOption(_ option: FollowUpDeadlineOption, to dueDate: Binding<Date>) {
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

    private func addDiscussion() {
        let trimmed = discussionInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        data.discussionPoints.append(trimmed)
        discussionInput = ""
    }

    private func addDecision() {
        let trimmed = decisionInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        data.decisions.append(trimmed)
        decisionInput = ""
    }

    private func useCurrentLocation() {
        isLocating = true
        locationError = nil
        Task {
            do {
                data.location = try await locationService.currentAddress()
            } catch {
                locationError = error.localizedDescription
            }
            isLocating = false
        }
    }

    private func save() {
        note.templateData = TemplateCoder.encode(data)
        onChange()
        syncReminders()
    }

    private func editorHeight(for text: String, minimumLines: Int = 2) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }

    private func syncReminders() {
        for item in data.actionItems where !item.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let itemID = item.id
            Task {
                let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                    title: item.task,
                    detail: item.detail,
                    assignees: item.assignees,
                    dueDate: item.dueDate,
                    isCompleted: item.isCompleted,
                    existingIdentifier: item.reminderIdentifier
                )
                guard let reminderID,
                      let index = data.actionItems.firstIndex(where: { $0.id == itemID }),
                      data.actionItems[index].reminderIdentifier != reminderID else { return }
                data.actionItems[index].reminderIdentifier = reminderID
            }
        }
    }
}
