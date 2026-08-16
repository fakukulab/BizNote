import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context

    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    @State private var cardScannerRequest: NoteCardScannerRequest?
    @State private var locationSearchRequest: LocationSearchRequest?
    @State private var exhibitionPresetRequest: ExhibitionPresetRequest?
    @State private var tagsText: String = ""
    @State private var initializedTagsText: Bool = false
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
                TextField(
                    String(localized: "note.content"),
                    text: $note.content,
                    axis: .vertical
                )
                .lineLimit(6...20)
                .onChange(of: note.content) { _, _ in touch() }
            }

            businessCardsSection()

            Section(String(localized: "note.tags")) {
                TextField(String(localized: "note.tagsPlaceholder"), text: $tagsText)
                    .onChange(of: tagsText) { _, newValue in
                        note.tags = newValue
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        touch()
                    }
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
        .environment(\.isReadyForSheetPresentation, isReadyForSheets)
        .onTransitionComplete { isReadyForSheets = true }
        .onAppear {
            if !initializedTagsText {
                tagsText = note.tags.joined(separator: ", ")
                initializedTagsText = true
            }
        }
    }

    @ViewBuilder
    private func categoryTemplateSection() -> some View {
        if note.isCustomCategory {
            EmptyView()
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

    @ViewBuilder
    private func businessCardsSection() -> some View {
        let cards = note.businessCards ?? []
        if !cards.isEmpty {
            Section(String(localized: "nav.businessCards")) {
                ForEach(cards) { card in
                    NavigationLink {
                        BusinessCardResultView(card: card, attachedNote: note)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.name.isEmpty ? String(localized: "businessCard.name") : card.name)
                                .font(.headline)
                            if !card.company.isEmpty {
                                Text(card.company).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
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
