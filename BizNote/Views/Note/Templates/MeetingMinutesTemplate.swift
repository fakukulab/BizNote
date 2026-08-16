import SwiftUI

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
                    Text(data.participants[i])
                }
                .onDelete { data.participants.remove(atOffsets: $0) }

                HStack {
                    TextField(String(localized: "template.meeting.participants"), text: $participantInput)
                    Button {
                        addParticipant()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(participantInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section(String(localized: "template.meeting.agenda")) {
                TextField(String(localized: "template.meeting.agenda"), text: $data.agenda, axis: .vertical).lineLimit(2...6)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $item.isCompleted) {
                            TextField(String(localized: "template.meeting.actions"), text: $item.task)
                        }
                        HStack {
                            TextField(String(localized: "businessCard.name"), text: $item.assignee)
                                .textFieldStyle(.roundedBorder)
                            DatePicker(String(localized: "template.exhibition.taskDueDate"), selection: $item.dueDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
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
    }

    private func addParticipant() {
        let trimmed = participantInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        data.participants.append(trimmed)
        participantInput = ""
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
    }
}
