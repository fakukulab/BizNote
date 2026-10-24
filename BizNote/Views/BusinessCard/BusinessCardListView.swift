import SwiftUI
import SwiftData

struct BusinessCardListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]

    private let selectedCardID: Binding<UUID?>?

    @State private var searchText: String = ""
    
    init(selectedCardID: Binding<UUID?>? = nil) {
        self.selectedCardID = selectedCardID
    }
    @State private var activeSheet: BusinessCardListSheet?
    @State private var savedCardSelection: SavedBusinessCardSelection?
    @State private var pendingSavedCardSelection: SavedBusinessCardSelection?
    @State private var recentlySavedCards: [BusinessCard] = []
    @State private var saveErrorMessage: String?

    private var visibleCards: [BusinessCard] {
        let queriedIDs = Set(cards.map(\.id))
        return cards + recentlySavedCards.filter { !queriedIDs.contains($0.id) }
    }

    private var filtered: [BusinessCard] {
        guard !searchText.isEmpty else { return visibleCards }
        return visibleCards.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.company.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.contains(searchText)
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    String(localized: "businessCard.empty"),
                    systemImage: "person.crop.rectangle",
                    description: Text(String(localized: "action.scanCard"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { card in
                    if let selectedCardID {
                        Button {
                            selectedCardID.wrappedValue = card.id
                        } label: {
                            BusinessCardRowView(card: card)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            selectedCardID.wrappedValue == card.id ? Color.accentColor.opacity(0.12) : nil
                        )
                    } else {
                        NavigationLink(value: BusinessCardListDestination.card(card.id)) {
                            BusinessCardRowView(card: card)
                        }
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        let card = filtered[i]
                        context.delete(card)
                    }
                    try? context.save()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "nav.businessCards"))
        .searchable(text: $searchText)
        .navigationDestination(item: $savedCardSelection) { selection in
            if let card = cards.first(where: { $0.id == selection.id }) {
                BusinessCardResultView(card: card, attachedNote: card.note)
            } else {
                ContentUnavailableView(
                    String(localized: "businessCard.empty"),
                    systemImage: "person.crop.rectangle"
                )
            }
        }
        .navigationDestination(for: BusinessCardListDestination.self) { destination in
            switch destination {
            case .card(let id):
                if let card = visibleCards.first(where: { $0.id == id }) {
                    BusinessCardResultView(card: card, attachedNote: card.note)
                } else {
                    ContentUnavailableView(
                        String(localized: "businessCard.empty"),
                        systemImage: "person.crop.rectangle"
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        activeSheet = .scanner
                    } label: {
                        Label(String(localized: "action.scanCard"), systemImage: "camera.viewfinder")
                    }
                    Button {
                        activeSheet = .exporter
                    } label: {
                        Label(String(localized: "action.export"), systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .scanner:
                BusinessCardScanFlow { drafts in
                    let savedCards = try saveBusinessCardDrafts(drafts)
                    recentlySavedCards = savedCards
                    searchText = ""
                    if let firstID = savedCards.first?.id {
                        pendingSavedCardSelection = SavedBusinessCardSelection(id: firstID)
                    }
                } onComplete: {
                    activeSheet = nil
                    guard let selection = pendingSavedCardSelection else { return }
                    pendingSavedCardSelection = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        if let selectedCardID {
                            selectedCardID.wrappedValue = selection.id
                        } else {
                            savedCardSelection = selection
                        }
                    }
                }
            case .exporter:
                NavigationStack { ExportView() }
            }
        }
        .onChange(of: cards.map(\.id)) { _, _ in
            let queriedIDs = Set(cards.map(\.id))
            recentlySavedCards.removeAll { queriedIDs.contains($0.id) }
        }
        .alert(String(localized: "businessCard.saveFailed"), isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button(String(localized: "action.done"), role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    @MainActor
    private func saveBusinessCardDrafts(_ drafts: [BusinessCardDraft]) throws -> [BusinessCard] {
        let savedCards = drafts.map { $0.makeBusinessCard() }
        for card in savedCards {
            context.insert(card)
        }

        do {
            try context.save()
        } catch {
            saveErrorMessage = error.localizedDescription
            throw error
        }

        let savedIDs = Set(savedCards.map(\.id))
        let persistedIDs = Set((try? context.fetch(FetchDescriptor<BusinessCard>()))?.map(\.id) ?? [])
        let missingIDs = savedIDs.subtracting(persistedIDs)
        if !missingIDs.isEmpty {
            let message = String(localized: "businessCard.saveFailed", defaultValue: "Failed to save the business card.")
            saveErrorMessage = message
            throw BusinessCardListSaveError.persistenceVerificationFailed
        }

        return savedCards
    }
}

private enum BusinessCardListSheet: Identifiable {
    case scanner
    case exporter

    var id: Self { self }
}

private enum BusinessCardListSaveError: LocalizedError {
    case persistenceVerificationFailed

    var errorDescription: String? {
        String(localized: "businessCard.saveFailed", defaultValue: "Failed to save the business card.")
    }
}

private enum BusinessCardListDestination: Hashable {
    case card(UUID)
}

private struct SavedBusinessCardSelection: Identifiable, Hashable {
    let id: UUID
}

struct BusinessCardRowView: View {
    let card: BusinessCard

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(initials)
                    .font(.headline)
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(card.name.isEmpty ? String(localized: "businessCard.name") : card.name)
                    .font(.headline)
                if !card.jobTitle.isEmpty || !card.company.isEmpty {
                    HStack(spacing: 6) {
                        if !card.company.isEmpty {
                            Text(card.company).font(.subheadline)
                        }
                        if !card.jobTitle.isEmpty {
                            Text(card.jobTitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !card.phone.isEmpty {
                    Text(card.phone).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var initials: String {
        let name = card.name.isEmpty ? "?" : card.name
        return String(name.prefix(1))
    }
}
