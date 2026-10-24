import SwiftUI
import Contacts
import UIKit

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
    var onPickContact: (@escaping (CNContact) -> Void) -> Void

    @State private var data: MeetingMinutesTemplateData
    @State private var participantInput: String = ""
    @State private var agendaInput: String = ""
    @State private var discussionInput: String = ""
    @State private var decisionInput: String = ""
    @State private var locationService = LocationService()
    @State private var isLocating: Bool = false
    @State private var locationError: String? = nil
    @State private var showCardImporter = false
    @State private var deadlineOptions: [UUID: FollowUpDeadlineOption] = [:]
    @State private var agendaItemIDs: [UUID]
    @State private var discussionItemIDs: [UUID]
    @State private var decisionItemIDs: [UUID]

    init(
        note: Note,
        onChange: @escaping () -> Void,
        onSearchLocation: @escaping (@escaping (String) -> Void) -> Void,
        onPickContact: @escaping (@escaping (CNContact) -> Void) -> Void
    ) {
        self.note = note
        self.onChange = onChange
        self.onSearchLocation = onSearchLocation
        self.onPickContact = onPickContact
        let initialData = TemplateCoder.decode(MeetingMinutesTemplateData.self, from: note.templateData) ?? .init()
        _data = State(initialValue: initialData)
        _agendaItemIDs = State(initialValue: Self.makeIDs(count: Self.agendaItems(from: initialData.agenda).count))
        _discussionItemIDs = State(initialValue: Self.makeIDs(count: initialData.discussionPoints.count))
        _decisionItemIDs = State(initialValue: Self.makeIDs(count: initialData.decisions.count))
    }

    var body: some View {
        Group {
            Section(String(localized: "template.meeting.date")) {
                HStack(spacing: 8) {
                    DatePicker(
                        String(localized: "template.meeting.date"),
                        selection: Binding(
                            get: { data.meetingDate },
                            set: { setMeetingStart($0) }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(minHeight: 36)

                    FiveMinuteTimePicker(
                        date: Binding(
                            get: { data.meetingDate },
                            set: { setMeetingStart($0) }
                        )
                    )
                    .frame(width: 104, height: 40)

                    Text("~")
                        .foregroundStyle(.secondary)

                    FiveMinuteTimePicker(
                        date: Binding(
                            get: { data.meetingEndDate },
                            set: { data.meetingEndDate = roundToFiveMinutes($0) }
                        )
                    )
                    .frame(width: 104, height: 40)
                }
            }

            Section(String(localized: "template.meeting.location")) {
                HStack {
                    TextField(String(localized: "template.meeting.location"), text: $data.location)

                    Button {
                        onSearchLocation { address in
                            applyLocationSelection(address)
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

                if let onlineMeetingURL {
                    HStack {
                        Link(destination: onlineMeetingURL) {
                            Label(data.onlineLink, systemImage: "link")
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            data.onlineLink = ""
                            data.isOnlineMeeting = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "action.delete"))
                    }
                }
            }

            Section(String(localized: "template.meeting.participants")) {
                ForEach(data.participants.indices, id: \.self) { i in
                    Text(participantSummary(data.participants[i]))
                }
                .onDelete { data.participants.remove(atOffsets: $0) }

                HStack {
                    TextField(String(localized: "template.meeting.participants"), text: $participantInput)
                    Spacer()
                    Menu {
                        Button(String(localized: "businessCard.importFromCard")) {
                            showCardImporter = true
                        }
                        Button(String(localized: "contacts.import", defaultValue: "연락처에서 불러오기")) {
                            onPickContact { contact in
                                addParticipant(from: contact)
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .accessibilityLabel(String(localized: "template.meeting.participants.add", defaultValue: "참석자 추가"))

                    Button {
                        addParticipant()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(participantInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section(String(localized: "template.meeting.agenda")) {
                ForEach(agendaRows) { row in
                    let i = row.index
                    EditableMeetingTextRow(
                        text: Binding(
                            get: { agendaItem(at: i) },
                            set: { updateAgendaItem(at: i, text: $0) }
                        ),
                        placeholder: String(localized: "template.meeting.agenda")
                    )
                }
                .onDelete { deleteAgendaItems(at: $0) }
                .onMove { source, destination in
                    moveAgendaItems(from: source, to: destination)
                }

                HStack {
                    TextField(String(localized: "template.meeting.agenda"), text: $agendaInput)
                    Button {
                        addAgenda()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(agendaInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .environment(\.editMode, .constant(.active))

            Section(String(localized: "template.meeting.discussion")) {
                ForEach(discussionRows) { row in
                    let i = row.index
                    EditableMeetingTextRow(
                        text: Binding(
                            get: { data.discussionPoints[i] },
                            set: { data.discussionPoints[i] = $0 }
                        ),
                        placeholder: String(localized: "template.meeting.discussion")
                    )
                }
                .onDelete { deleteDiscussionItems(at: $0) }
                .onMove { source, destination in
                    moveDiscussionItems(from: source, to: destination)
                }

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
            .environment(\.editMode, .constant(.active))

            Section(String(localized: "template.meeting.decisions")) {
                ForEach(decisionRows) { row in
                    let i = row.index
                    EditableMeetingTextRow(
                        text: Binding(
                            get: { data.decisions[i] },
                            set: { data.decisions[i] = $0 }
                        ),
                        placeholder: String(localized: "template.meeting.decisions")
                    )
                }
                .onDelete { deleteDecisionItems(at: $0) }
                .onMove { source, destination in
                    moveDecisionItems(from: source, to: destination)
                }

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
            .environment(\.editMode, .constant(.active))

            Section(String(localized: "template.meeting.actions")) {
                ForEach($data.actionItems) { $item in
                    MeetingActionRow(item: $item)
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
        .onAppear {
            syncTextItemIDs()
        }
        .navigationDestination(isPresented: $showCardImporter) {
            BusinessCardImportPickerView { card in
                addParticipant(from: card)
                showCardImporter = false
            }
        }
    }

    private var onlineMeetingURL: URL? {
        normalizedURL(from: data.onlineLink)
    }

    private var agendaItems: [String] {
        Self.agendaItems(from: data.agenda)
    }

    private var agendaRows: [MeetingTextRowReference] {
        rows(for: agendaItems.indices, ids: agendaItemIDs)
    }

    private var discussionRows: [MeetingTextRowReference] {
        rows(for: data.discussionPoints.indices, ids: discussionItemIDs)
    }

    private var decisionRows: [MeetingTextRowReference] {
        rows(for: data.decisions.indices, ids: decisionItemIDs)
    }

    private static func agendaItems(from text: String) -> [String] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func makeIDs(count: Int) -> [UUID] {
        (0..<count).map { _ in UUID() }
    }

    private func rows(for indices: Range<Int>, ids: [UUID]) -> [MeetingTextRowReference] {
        indices.compactMap { index in
            guard ids.indices.contains(index) else { return nil }
            return MeetingTextRowReference(id: ids[index], index: index)
        }
    }

    private func applyLocationSelection(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = normalizedURL(from: trimmed) {
            data.onlineLink = url.absoluteString
            data.isOnlineMeeting = true
        } else {
            data.location = trimmed
        }
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            return url
        }

        guard trimmed.contains("."),
              !trimmed.contains(" "),
              let url = URL(string: "https://\(trimmed)") else {
            return nil
        }
        return url
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
        participant.company = contact.organizationName
        participant.jobTitle = contact.jobTitle
        participant.phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        participant.email = contact.emailAddresses.first.map { String($0.value) } ?? ""
        data.participants.append(participant)
    }

    private func addParticipant(from card: BusinessCard) {
        var participant = MeetingMinutesTemplateData.Participant()
        participant.name = card.name
        participant.company = card.company
        participant.jobTitle = card.jobTitle
        participant.phone = card.phone.isEmpty ? card.officePhone : card.phone
        participant.email = card.email
        participant.linkedCardID = card.id
        data.participants.append(participant)
    }

    private func setMeetingStart(_ newDate: Date) {
        let roundedStart = roundToFiveMinutes(newDate)
        data.meetingDate = roundedStart
        data.meetingEndDate = roundedStart.addingTimeInterval(3600)
    }

    private func roundToFiveMinutes(_ date: Date) -> Date {
        let interval = TimeInterval(5 * 60)
        let rounded = (date.timeIntervalSinceReferenceDate / interval).rounded() * interval
        return Date(timeIntervalSinceReferenceDate: rounded)
    }

    private func participantSummary(_ participant: MeetingMinutesTemplateData.Participant) -> String {
        [
            participant.name,
            participant.jobTitle,
            participant.company
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
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

    private func agendaItem(at index: Int) -> String {
        let items = agendaItems
        guard items.indices.contains(index) else { return "" }
        return items[index]
    }

    private func updateAgendaItem(at index: Int, text: String) {
        var items = agendaItems
        guard items.indices.contains(index) else { return }
        items[index] = text
        data.agenda = items.joined(separator: "\n")
    }

    private func addAgenda() {
        let trimmed = agendaInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var items = agendaItems
        items.append(trimmed)
        agendaItemIDs.append(UUID())
        data.agenda = items.joined(separator: "\n")
        agendaInput = ""
    }

    private func addDiscussion() {
        let trimmed = discussionInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        data.discussionPoints.append(trimmed)
        discussionItemIDs.append(UUID())
        discussionInput = ""
    }

    private func addDecision() {
        let trimmed = decisionInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        data.decisions.append(trimmed)
        decisionItemIDs.append(UUID())
        decisionInput = ""
    }

    private func deleteAgendaItems(at offsets: IndexSet) {
        var items = agendaItems
        items.remove(atOffsets: offsets)
        agendaItemIDs.remove(atOffsets: offsets)
        data.agenda = items.joined(separator: "\n")
    }

    private func moveAgendaItems(from source: IndexSet, to destination: Int) {
        var items = agendaItems
        items.move(fromOffsets: source, toOffset: destination)
        agendaItemIDs.move(fromOffsets: source, toOffset: destination)
        data.agenda = items.joined(separator: "\n")
    }

    private func deleteDiscussionItems(at offsets: IndexSet) {
        data.discussionPoints.remove(atOffsets: offsets)
        discussionItemIDs.remove(atOffsets: offsets)
    }

    private func moveDiscussionItems(from source: IndexSet, to destination: Int) {
        data.discussionPoints.move(fromOffsets: source, toOffset: destination)
        discussionItemIDs.move(fromOffsets: source, toOffset: destination)
    }

    private func deleteDecisionItems(at offsets: IndexSet) {
        data.decisions.remove(atOffsets: offsets)
        decisionItemIDs.remove(atOffsets: offsets)
    }

    private func moveDecisionItems(from source: IndexSet, to destination: Int) {
        data.decisions.move(fromOffsets: source, toOffset: destination)
        decisionItemIDs.move(fromOffsets: source, toOffset: destination)
    }

    private func syncTextItemIDs() {
        reconcileIDs(&agendaItemIDs, count: agendaItems.count)
        reconcileIDs(&discussionItemIDs, count: data.discussionPoints.count)
        reconcileIDs(&decisionItemIDs, count: data.decisions.count)
    }

    private func reconcileIDs(_ ids: inout [UUID], count: Int) {
        if ids.count > count {
            ids.removeLast(ids.count - count)
        } else if ids.count < count {
            ids.append(contentsOf: Self.makeIDs(count: count - ids.count))
        }
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

private struct MeetingTextRowReference: Identifiable {
    let id: UUID
    let index: Int
}

private struct EditableMeetingTextRow: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(localized: "list.bulletPrefix"))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct MeetingActionRow: View {
    @Binding var item: MeetingMinutesTemplateData.ActionItem
    @State private var showDetailEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField(String(localized: "template.exhibition.taskTitle"), text: $item.task)
                    .textFieldStyle(.plain)

                Button {
                    showDetailEditor = true
                } label: {
                    Label(String(localized: "template.exhibition.taskDetails", defaultValue: "Task Details"), systemImage: "info.circle")
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
            }

            let summary = actionSummary
            if !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showDetailEditor) {
            NavigationStack {
                MeetingActionDetailEditor(item: $item) {
                    item.isDetailConfigured = true
                }
            }
        }
    }

    private var actionSummary: String {
        guard item.isDetailConfigured else { return item.assignees.first ?? "" }
        return [
            item.category.localizedName,
            detailDateString(for: item.dueDate),
            detailTimeString(for: item.dueDate),
            item.assignees.first ?? ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    private func detailDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func detailTimeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct FiveMinuteTimePicker: UIViewRepresentable {
    @Binding var date: Date

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.minuteInterval = 5
        picker.preferredDatePickerStyle = .compact
        picker.setContentCompressionResistancePriority(.required, for: .horizontal)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        context.coordinator.applyBodyFont(to: picker)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        if abs(picker.date.timeIntervalSince(date)) > 1 {
            picker.date = date
        }
        context.coordinator.applyBodyFont(to: picker)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: FiveMinuteTimePicker

        init(parent: FiveMinuteTimePicker) {
            self.parent = parent
        }

        @objc func valueChanged(_ picker: UIDatePicker) {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: picker.date)
            parent.date = calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: parent.date
            ) ?? parent.date
        }

        func applyBodyFont(to view: UIView) {
            let bodyFont = UIFont.preferredFont(forTextStyle: .body)
            for subview in view.subviews {
                if let label = subview as? UILabel {
                    label.font = bodyFont
                }
                applyBodyFont(to: subview)
            }
        }
    }
}

private struct MeetingActionDetailEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var item: MeetingMinutesTemplateData.ActionItem
    var onDone: () -> Void = {}

    var body: some View {
        Form {
            Section(String(localized: "note.category", defaultValue: "Category")) {
                Picker(String(localized: "note.category", defaultValue: "Category"), selection: $item.category) {
                    ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.selectableCases) { category in
                        Label(category.localizedName, systemImage: category.systemImage)
                            .tag(category)
                    }
                }
            }

            Section(String(localized: "deadline.title", defaultValue: "Deadline")) {
                DatePicker(
                    String(localized: "template.exhibition.taskDueDate"),
                    selection: $item.dueDate,
                    displayedComponents: .date
                )
                DatePicker(
                    String(localized: "deadline.time", defaultValue: "Time"),
                    selection: $item.dueDate,
                    displayedComponents: .hourAndMinute
                )
            }

            Section(String(localized: "template.followUp.assignee")) {
                TextField(String(localized: "template.followUp.assignee"), text: assignee)
            }
        }
        .navigationTitle(String(localized: "template.exhibition.taskDetails", defaultValue: "Task Details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "action.cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "action.done")) {
                    onDone()
                    dismiss()
                }
            }
        }
    }

    private var assignee: Binding<String> {
        Binding(
            get: { item.assignees.first ?? "" },
            set: { item.assignees = $0.isEmpty ? [] : [$0] }
        )
    }
}
