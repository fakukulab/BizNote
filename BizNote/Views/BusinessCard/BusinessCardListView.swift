import SwiftUI
import SwiftData

struct BusinessCardListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]

    @State private var searchText: String = ""
    @State private var activeSheet: BusinessCardListSheet?

    var filtered: [BusinessCard] {
        guard !searchText.isEmpty else { return cards }
        return cards.filter {
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
                    NavigationLink {
                        BusinessCardResultView(card: card, attachedNote: card.note)
                    } label: {
                        BusinessCardRowView(card: card)
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
                BusinessCardScanFlow {
                    let card = $0.makeBusinessCard()
                    context.insert(card)
                    try context.save()
                } onComplete: {
                    activeSheet = nil
                }
            case .exporter:
                NavigationStack { ExportView() }
            }
        }
    }
}

private enum BusinessCardListSheet: Identifiable {
    case scanner
    case exporter

    var id: Self { self }
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
