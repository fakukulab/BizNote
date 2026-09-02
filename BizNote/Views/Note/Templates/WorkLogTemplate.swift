import SwiftUI
import SwiftData

struct WorkLogTemplateSection: View {
    @Bindable var note: Note
    var onChange: () -> Void

    @State private var data: WorkLogTemplateData

    @Query(
        filter: #Predicate<Note> { $0.categoryRaw == "meeting_minutes" },
        sort: \Note.updatedAt,
        order: .reverse
    )
    private var meetings: [Note]

    private var sameDayMeetings: [Note] {
        meetings.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: data.date) }
    }

    init(note: Note, onChange: @escaping () -> Void) {
        self.note = note
        self.onChange = onChange
        _data = State(initialValue: TemplateCoder.decode(WorkLogTemplateData.self, from: note.templateData) ?? .init())
    }

    var body: some View {
        Group {
            Section(String(localized: "template.workLog.date")) {
                DatePicker(
                    String(localized: "template.workLog.date"),
                    selection: Binding(
                        get: { data.date },
                        set: { newDate in
                            data.date = newDate
                            updateTitle(for: newDate)
                        }
                    ),
                    displayedComponents: [.date]
                )
                .labelsHidden()
            }

            if !sameDayMeetings.isEmpty {
                Section(String(localized: "template.workLog.sameDayMeetings")) {
                    ForEach(sameDayMeetings) { m in
                        NavigationLink {
                            NoteDetailView(note: m)
                        } label: {
                            Label(m.title.isEmpty ? String(localized: "category.meetingMinutes") : m.title,
                                  systemImage: "person.2.fill")
                        }
                    }
                }
            }

            Section(String(localized: "template.workLog.items")) {
                ForEach($data.workItems) { $item in
                    VStack(alignment: .leading, spacing: 16) {
                        TextField(String(localized: "template.workLog.itemPlaceholder"), text: $item.task)
                        Picker(String(localized: "task.status.todo"), selection: $item.status) {
                            ForEach(WorkLogTemplateData.WorkItem.TaskStatus.allCases) { s in
                                Text(s.localizedName).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 10)
                }
                .onDelete { data.workItems.remove(atOffsets: $0) }

                Button {
                    data.workItems.append(.init())
                } label: {
                    Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
                }
                .padding(.top, 12)
            }

            Section(String(localized: "template.workLog.achievements")) {
                TextEditor(text: $data.achievements)
                    .frame(minHeight: editorHeight(for: data.achievements))
            }

            Section(String(localized: "template.workLog.issues")) {
                TextEditor(text: $data.issues)
                    .frame(minHeight: editorHeight(for: data.issues))
            }

            Section {
                TextEditor(text: $data.nextTodos)
                    .frame(minHeight: editorHeight(for: data.nextTodos))
            } header: {
                Text(String(localized: "template.workLog.nextTodos"))
            } footer: {
                Text(String(localized: "template.workLog.nextTodosHint"))
                    .font(.caption)
            }
        }
        .onChange(of: data.workItems) { _, _ in
            syncAchievementsFromDoneItems()
        }
        .onChange(of: data) { _, _ in save() }
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

    private func syncAchievementsFromDoneItems() {
        let completedTasks = data.workItems
            .filter { $0.status == .done }
            .map { $0.task.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let achievements = completedTasks.joined(separator: "\n")
        guard data.achievements != achievements else { return }
        data.achievements = achievements
    }

    private func syncReminders() {
        for item in data.workItems where !item.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let itemID = item.id
            Task {
                let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                    title: item.task,
                    detail: item.status.localizedName,
                    assignees: [],
                    dueDate: data.date,
                    isCompleted: item.status == .done,
                    existingIdentifier: item.reminderIdentifier
                )
                guard let reminderID,
                      let index = data.workItems.firstIndex(where: { $0.id == itemID }),
                      data.workItems[index].reminderIdentifier != reminderID else { return }
                data.workItems[index].reminderIdentifier = reminderID
            }
        }
    }

    private func updateTitle(for date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        note.title = "\(formatter.string(from: date)) \(NoteCategory.workLog.localizedName)"
    }

}
