import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context

    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    @State private var cardScannerRequest: NoteCardScannerRequest?
    @State private var locationSearchRequest: LocationSearchRequest?
    @State private var exhibitionPresetRequest: ExhibitionPresetRequest?
    @State private var selectedBusinessCardID: UUID?
    @State private var isReadyForSheets: Bool = false

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "note.category"), selection: Binding(
                    get: { note.categorySelection },
                    set: { newValue in
                        guard newValue != note.categorySelection else { return }
                        note.categorySelection = newValue
                        if newValue == .builtin(.workLog) {
                            let df = DateFormatter()
                            df.dateFormat = "yyyy-MM-dd"
                            note.title = "\(df.string(from: Date())) \(NoteCategory.workLog.localizedName)"
                        } else {
                            note.title = ""
                        }
                        touch()
                    }
                )) {
                    ForEach(NoteCategory.allCases) { c in
                        Label(c.localizedName, systemImage: c.systemIconName)
                            .tag(NoteCategorySelection.builtin(c))
                    }
                    ForEach(customCategories) { c in
                        Label(c.name, systemImage: c.systemIconName)
                            .tag(NoteCategorySelection.custom(c))
                    }
                }

                TextField(String(localized: "note.title"), text: $note.title)
                    .font(.title3)
                    .onChange(of: note.title) { _, _ in touch() }

                Toggle(String(localized: "note.favorite"), isOn: Binding(
                    get: { note.isFavorite },
                    set: { note.isFavorite = $0; touch() }
                ))
            }

            categoryTemplateSection()

            Section(String(localized: "note.content")) {
                TextEditor(text: $note.content)
                    .frame(minHeight: editorHeight(for: note.content, minimumLines: 3))
                    .onChange(of: note.content) { _, _ in touch() }
            }

            businessCardsSection()

            Section(String(localized: "note.tags")) {
                TagEditorView(tags: $note.tags)
                    .onChange(of: note.tags) { _, _ in touch() }
            }
        }
        .navigationTitle(note.title.isEmpty ? String(localized: "action.newNote") : note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !(note.categorySelection == .builtin(.workLog)) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        guard isReadyForSheets else { return }
                        cardScannerRequest = NoteCardScannerRequest()
                    } label: {
                        Label(String(localized: "action.scanCard"), systemImage: "camera.viewfinder")
                    }
                }
            }
        }
        .sheet(item: $cardScannerRequest) { _ in
            BusinessCardScanFlow {
                let card = $0.makeBusinessCard()
                context.insert(card)
                card.note = note
                var cards = note.businessCards ?? []
                if !cards.contains(where: { $0.id == card.id }) {
                    cards.append(card)
                    note.businessCards = cards
                }
                note.updatedAt = Date()
                try context.save()
            } onComplete: {
                cardScannerRequest = nil
            }
        }
        .sheet(item: $locationSearchRequest) { request in
            NavigationStack {
                LocationSearchSheet { address in
                    request.onSelect(address)
                    locationSearchRequest = nil
                }
            }
        }
        .sheet(item: $exhibitionPresetRequest) { request in
            NavigationStack {
                ExhibitionPresetPickerView { preset in
                    request.onSelect(preset)
                    exhibitionPresetRequest = nil
                }
            }
        }
        .navigationDestination(item: $selectedBusinessCardID) { cardID in
            if let card = businessCard(with: cardID) {
                BusinessCardResultView(card: card, attachedNote: note)
            }
        }
        .environment(\.isReadyForSheetPresentation, isReadyForSheets)
        .onTransitionComplete { isReadyForSheets = true }
    }

    private func editorHeight(for text: String, minimumLines: Int) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }

    @ViewBuilder
    private func categoryTemplateSection() -> some View {
        if usesCustomTemplate {
            CustomNoteTemplateView(data: customTemplateBinding, attachmentPaths: $note.attachmentPaths)
                .onAppear { seedCustomTemplateIfNeeded() }
                .onChange(of: note.attachmentPaths) { _, _ in touch() }
        } else {
            switch note.category {
            case .workLog:
                WorkLogTemplateSection(note: note, onChange: touch)
            case .meetingMinutes:
                MeetingMinutesTemplateSection(note: note, onChange: touch) { onSelect in
                    locationSearchRequest = LocationSearchRequest(onSelect: onSelect)
                }
            case .exhibition:
                ExhibitionTemplateSection(note: note, onChange: touch) { onSelect in
                    exhibitionPresetRequest = ExhibitionPresetRequest(onSelect: onSelect)
                }
            }
        }
    }

    private var usesCustomTemplate: Bool {
        if note.isCustomCategory {
            return true
        }
        guard let data = TemplateCoder.decode(CustomNoteTemplateData.self, from: note.templateData) else {
            return false
        }
        return data.sections.contains { $0.isEnabled }
    }

    private var customTemplateBinding: Binding<CustomNoteTemplateData> {
        Binding(
            get: {
                TemplateCoder.decode(CustomNoteTemplateData.self, from: note.templateData)
                ?? note.customCategory.flatMap { TemplateCoder.decode(CustomNoteTemplateData.self, from: $0.templateData) }
                ?? CustomNoteTemplateData.defaultTemplate
            },
            set: { newValue in
                note.templateData = TemplateCoder.encode(newValue)
                touch()
            }
        )
    }

    private func seedCustomTemplateIfNeeded() {
        guard TemplateCoder.decode(CustomNoteTemplateData.self, from: note.templateData) == nil else { return }
        note.templateData = TemplateCoder.encode(
            note.customCategory.flatMap { TemplateCoder.decode(CustomNoteTemplateData.self, from: $0.templateData) }
            ?? CustomNoteTemplateData.defaultTemplate
        )
        touch()
    }

    @ViewBuilder
    private func businessCardsSection() -> some View {
        let cards = note.businessCards ?? []
        if !cards.isEmpty {
            Section(String(localized: "nav.businessCards")) {
                ForEach(cards) { card in
                    Button {
                        selectedBusinessCardID = card.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name.isEmpty ? String(localized: "businessCard.name") : card.name)
                                    .font(.headline)
                                if !card.company.isEmpty {
                                    Text(card.company).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        let card = cards[i]
                        context.delete(card)
                    }
                    try? context.save()
                }
            }
        }
    }

    private func businessCard(with id: UUID) -> BusinessCard? {
        note.businessCards?.first { $0.id == id }
    }

    private func touch() {
        note.updatedAt = Date()
    }
}

private struct NoteCardScannerRequest: Identifiable {
    let id = UUID()
}

private struct LocationSearchRequest: Identifiable {
    let id = UUID()
    var onSelect: (String) -> Void
}

private struct ExhibitionPresetRequest: Identifiable {
    let id = UUID()
    var onSelect: (ExhibitionPreset) -> Void
}
