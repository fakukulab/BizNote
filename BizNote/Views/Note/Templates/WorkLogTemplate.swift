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
                    selection: $data.date,
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
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(String(localized: "template.workLog.itemPlaceholder"), text: $item.task)
                        Picker(String(localized: "task.status.todo"), selection: $item.status) {
                            ForEach(WorkLogTemplateData.WorkItem.TaskStatus.allCases) { s in
                                Text(s.localizedName).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        Stepper(value: $item.duration, in: 0...24, step: 0.5) {
                            Text(String(format: "%.1f h", item.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .onDelete { data.workItems.remove(atOffsets: $0) }

                Button {
                    data.workItems.append(.init())
                } label: {
                    Label(String(localized: "action.add"), systemImage: "plus.circle.fill")
                }
                .padding(.top, 4)
            }

            Section(String(localized: "template.workLog.achievements")) {
                TextField(String(localized: "template.workLog.achievements"), text: $data.achievements, axis: .vertical).lineLimit(2...6)
            }

            Section(String(localized: "template.workLog.issues")) {
                TextField(String(localized: "template.workLog.issues"), text: $data.issues, axis: .vertical).lineLimit(2...6)
            }

            Section {
                TextField(String(localized: "template.workLog.nextTodos"), text: $data.nextTodos, axis: .vertical).lineLimit(2...6)
            } header: {
                Text(String(localized: "template.workLog.nextTodos"))
            } footer: {
                Text(String(localized: "template.workLog.nextTodosHint"))
                    .font(.caption)
            }
        }
        .onChange(of: data) { _, _ in save() }
    }

    private func save() {
        note.templateData = TemplateCoder.encode(data)
        onChange()
    }
}
