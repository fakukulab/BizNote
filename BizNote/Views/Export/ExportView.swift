import SwiftUI
import SwiftData
import UIKit

enum ExportTarget: String, CaseIterable, Identifiable {
    case businessCards
    case notes
    case all

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .businessCards: return String(localized: "export.businessCards")
        case .notes:         return String(localized: "export.notes")
        case .all:           return String(localized: "export.all")
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var allNotes: [Note]
    @Query private var allCards: [BusinessCard]
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    @State private var target: ExportTarget = .all
    @State private var categoryFilter: NoteCategorySelection? = nil
    @State private var useDateFilter: Bool = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    @State private var sharePayload: ExportSharePayload?
    @State private var errorMessage: String?
    @State private var isReadyForSheets: Bool = false
    @State private var pendingExport: Bool = false

    var body: some View {
        Form {
            Section(String(localized: "export.target")) {
                Picker(String(localized: "export.target"), selection: $target) {
                    ForEach(ExportTarget.allCases) { t in
                        Text(t.localizedName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "note.category")) {
                Picker(String(localized: "note.category"), selection: $categoryFilter) {
                    Text(String(localized: "export.all")).tag(NoteCategorySelection?.none)
                    ForEach(NoteCategory.allCases) { c in
                        Text(c.localizedName).tag(NoteCategorySelection?.some(.builtin(c)))
                    }
                    ForEach(customCategories) { c in
                        Text(c.name).tag(NoteCategorySelection?.some(.custom(c)))
                    }
                }
                .pickerStyle(.menu)
                .disabled(target == .businessCards)
            }

            Section(String(localized: "export.dateRange")) {
                Toggle(String(localized: "export.dateRange"), isOn: $useDateFilter)
                if useDateFilter {
                    DatePicker(String(localized: "export.startDate"),
                               selection: $startDate, displayedComponents: .date)
                    DatePicker(String(localized: "export.endDate"),
                               selection: $endDate, displayedComponents: .date)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    if isReadyForSheets {
                        runExport()
                    } else {
                        pendingExport = true
                    }
                } label: {
                    Text(String(localized: "export.run"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(String(localized: "export.title"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "action.cancel")) { dismiss() }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.urls)
        }
        .onTransitionComplete {
            isReadyForSheets = true
            if pendingExport {
                pendingExport = false
                runExport()
            }
        }
    }

    private func runExport() {
        errorMessage = nil
        sharePayload = nil

        var urls: [URL] = []
        let service = ExcelExportService()

        do {
            let filteredNotes = filter(allNotes) { $0.createdAt }
            let filteredCards = filter(allCards) { $0.createdAt }

            if target == .notes || target == .all {
                let notes = categoryFilter != nil
                    ? filteredNotes.filter { $0.categorySelection == categoryFilter }
                    : filteredNotes
                if !notes.isEmpty {
                    let url = try service.exportNotes(notes)
                    urls.append(url)
                }
            }
            if target == .businessCards || target == .all {
                if !filteredCards.isEmpty {
                    let url = try service.exportBusinessCards(filteredCards)
                    urls.append(url)
                }
            }

            guard !urls.isEmpty else {
                errorMessage = String(localized: "export.noData")
                return
            }

            sharePayload = ExportSharePayload(urls: urls)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func filter<T>(_ items: [T], dateKey: (T) -> Date) -> [T] {
        guard useDateFilter else { return items }
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        return items.filter {
            let d = dateKey($0)
            return d >= start && d <= end
        }
    }
}

private struct ExportSharePayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // On iPad, UIActivityViewController is always presented as a popover;
        // without an anchor it fails to show (or silently no-ops on some
        // actions like "Save to Files") even though we present it modally.
        if let popover = controller.popoverPresentationController {
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            popover.sourceView = keyWindow
            popover.sourceRect = CGRect(
                x: (keyWindow?.bounds.midX) ?? 0,
                y: (keyWindow?.bounds.midY) ?? 0,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
