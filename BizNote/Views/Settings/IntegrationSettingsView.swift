import SwiftUI
import SwiftData

struct IntegrationSettingsView: View {
    @AppStorage("integration.syncEventsWithCalendar") private var syncEventsWithCalendar: Bool = false
    @AppStorage("integration.syncTasksWithReminders") private var syncTasksWithReminders: Bool = false
    @AppStorage("integration.selectedEventCalendarIdentifier") private var selectedEventCalendarIdentifier: String = ""
    @AppStorage("integration.selectedReminderListIdentifier") private var selectedReminderListIdentifier: String = ""

    @Environment(\.modelContext) private var context
    @Query private var exhibitionPresets: [ExhibitionPreset]
    @Query private var notes: [Note]

    @State private var eventCalendars: [CalendarReminderSyncService.Destination] = []
    @State private var reminderLists: [CalendarReminderSyncService.Destination] = []

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $syncEventsWithCalendar) {
                    Label(String(localized: "settings.iCloud.syncEventsWithCalendar", defaultValue: "행사를 캘린더 앱과 동기화"), systemImage: "calendar")
                }
                if syncEventsWithCalendar {
                    Picker(String(localized: "settings.iCloud.eventCalendar", defaultValue: "추가할 캘린더"),
                           selection: $selectedEventCalendarIdentifier) {
                        Text(String(localized: "settings.iCloud.destination.none", defaultValue: "선택 안 함")).tag("")
                        ForEach(eventCalendars) { calendar in
                            Text(destinationTitle(calendar)).tag(calendar.id)
                        }
                    }
                    .disabled(eventCalendars.isEmpty)
                }
            } footer: {
                Text(String(localized: "settings.iCloud.syncEventsWithCalendar.hint", defaultValue: "선택한 iCloud 캘린더에 행사 일정이 추가됩니다."))
            }

            Section {
                Toggle(isOn: $syncTasksWithReminders) {
                    Label(String(localized: "settings.iCloud.syncTasksWithReminders", defaultValue: "업무를 미리알림 앱과 동기화"), systemImage: "checklist")
                }
                if syncTasksWithReminders {
                    Picker(String(localized: "settings.iCloud.reminderList", defaultValue: "추가할 리스트"),
                           selection: $selectedReminderListIdentifier) {
                        Text(String(localized: "settings.iCloud.destination.none", defaultValue: "선택 안 함")).tag("")
                        ForEach(reminderLists) { list in
                            Text(destinationTitle(list)).tag(list.id)
                        }
                    }
                    .disabled(reminderLists.isEmpty)
                }
            } footer: {
                Text(String(localized: "settings.iCloud.syncTasksWithReminders.hint", defaultValue: "선택한 iCloud 미리알림 리스트에 업무 항목이 추가됩니다."))
            }
        }
        .navigationTitle(String(localized: "settings.integration.title", defaultValue: "Apple 앱 연동"))
        .task {
            await refreshDestinations(requestAccess: false)
        }
        .onChange(of: syncEventsWithCalendar) { _, enabled in
            guard enabled else { return }
            Task {
                await refreshEventCalendars(requestAccess: true)
                await syncExistingEvents()
            }
        }
        .onChange(of: syncTasksWithReminders) { _, enabled in
            guard enabled else { return }
            Task {
                await refreshReminderLists(requestAccess: true)
                await syncExistingTasks()
            }
        }
        .onChange(of: selectedEventCalendarIdentifier) { _, _ in
            guard syncEventsWithCalendar else { return }
            Task { await syncExistingEvents() }
        }
        .onChange(of: selectedReminderListIdentifier) { _, _ in
            guard syncTasksWithReminders else { return }
            Task { await syncExistingTasks() }
        }
    }

    private func destinationTitle(_ destination: CalendarReminderSyncService.Destination) -> String {
        "\(destination.title) (\(destination.sourceTitle))"
    }

    private func refreshDestinations(requestAccess: Bool) async {
        await refreshEventCalendars(requestAccess: requestAccess && syncEventsWithCalendar)
        await refreshReminderLists(requestAccess: requestAccess && syncTasksWithReminders)
    }

    private func refreshEventCalendars(requestAccess: Bool) async {
        eventCalendars = await CalendarReminderSyncService.shared.eventCalendars(requestAccess: requestAccess)
        if selectedEventCalendarIdentifier.isEmpty, let first = eventCalendars.first {
            selectedEventCalendarIdentifier = first.id
        } else if !selectedEventCalendarIdentifier.isEmpty,
                  !eventCalendars.contains(where: { $0.id == selectedEventCalendarIdentifier }) {
            selectedEventCalendarIdentifier = eventCalendars.first?.id ?? ""
        }
    }

    private func refreshReminderLists(requestAccess: Bool) async {
        reminderLists = await CalendarReminderSyncService.shared.reminderLists(requestAccess: requestAccess)
        if selectedReminderListIdentifier.isEmpty, let first = reminderLists.first {
            selectedReminderListIdentifier = first.id
        } else if !selectedReminderListIdentifier.isEmpty,
                  !reminderLists.contains(where: { $0.id == selectedReminderListIdentifier }) {
            selectedReminderListIdentifier = reminderLists.first?.id ?? ""
        }
    }

    private func syncExistingEvents() async {
        for preset in exhibitionPresets {
            await CalendarReminderSyncService.shared.syncEvent(for: preset)
        }
        try? context.save()
    }

    private func syncExistingTasks() async {
        var changed = false

        for note in notes where !note.isCustomCategory {
            switch note.category {
            case .workLog:
                guard var data = TemplateCoder.decode(WorkLogTemplateData.self, from: note.templateData) else { continue }
                let synced = await syncWorkLogItems(data.workItems, dueDate: data.date)
                if synced != data.workItems {
                    data.workItems = synced
                    note.templateData = TemplateCoder.encode(data)
                    changed = true
                }
            case .meetingMinutes:
                guard var data = TemplateCoder.decode(MeetingMinutesTemplateData.self, from: note.templateData) else { continue }
                let synced = await syncMeetingItems(data.actionItems)
                if synced != data.actionItems {
                    data.actionItems = synced
                    note.templateData = TemplateCoder.encode(data)
                    changed = true
                }
            case .exhibition:
                guard var data = TemplateCoder.decode(ExhibitionTemplateData.self, from: note.templateData) else { continue }
                let synced = await syncExhibitionItems(data.tasks)
                if synced != data.tasks {
                    data.tasks = synced
                    note.templateData = TemplateCoder.encode(data)
                    changed = true
                }
            }
        }

        if changed {
            try? context.save()
        }
    }

    private func syncWorkLogItems(
        _ items: [WorkLogTemplateData.WorkItem],
        dueDate: Date
    ) async -> [WorkLogTemplateData.WorkItem] {
        var synced = items
        for index in synced.indices {
            let item = synced[index]
            guard !item.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                title: item.task,
                detail: item.status.localizedName,
                assignees: [],
                dueDate: dueDate,
                isCompleted: item.status == .done,
                existingIdentifier: item.reminderIdentifier
            )
            synced[index].reminderIdentifier = reminderID
        }
        return synced
    }

    private func syncMeetingItems(
        _ items: [MeetingMinutesTemplateData.ActionItem]
    ) async -> [MeetingMinutesTemplateData.ActionItem] {
        var synced = items
        for index in synced.indices {
            let item = synced[index]
            guard !item.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                title: item.task,
                detail: item.detail,
                assignees: item.assignees,
                dueDate: item.dueDate,
                isCompleted: item.isCompleted,
                existingIdentifier: item.reminderIdentifier
            )
            synced[index].reminderIdentifier = reminderID
        }
        return synced
    }

    private func syncExhibitionItems(
        _ items: [ExhibitionTemplateData.TaskItem]
    ) async -> [ExhibitionTemplateData.TaskItem] {
        var synced = items
        for index in synced.indices {
            let item = synced[index]
            guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                title: item.title,
                detail: item.detail,
                assignees: item.assignees,
                dueDate: item.dueDate,
                isCompleted: item.isCompleted,
                existingIdentifier: item.reminderIdentifier
            )
            synced[index].reminderIdentifier = reminderID
        }
        return synced
    }
}

#Preview {
    NavigationStack { IntegrationSettingsView() }
}
