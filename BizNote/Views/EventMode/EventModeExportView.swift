import SwiftUI

private enum EventModeExportRange: Hashable {
    case all
    case filtered
    case selected
}

struct EventModeExportView: View {
    let preset: ExhibitionPreset
    let allVisitors: [EventVisitor]
    let filteredVisitors: [EventVisitor]
    let selectedVisitors: [EventVisitor]

    @Environment(\.dismiss) private var dismiss

    @State private var range: EventModeExportRange = .all
    @State private var format: SpreadsheetFormat = .xlsx
    @State private var includeCardImagesZip = false
    @State private var errorMessage: String?
    @State private var isExporting = false
    @State private var sharePayload: EventModeExportSharePayload?

    var body: some View {
        Form {
            Section(String(localized: "export.target")) {
                Picker(String(localized: "export.target"), selection: $range) {
                    Text(String(format: String(localized: "eventMode.export.range.all", defaultValue: "전체 (%lld)"), allVisitors.count))
                        .tag(EventModeExportRange.all)
                    Text(String(format: String(localized: "eventMode.export.range.filtered", defaultValue: "현재 필터 결과 (%lld)"), filteredVisitors.count))
                        .tag(EventModeExportRange.filtered)
                    Text(String(format: String(localized: "eventMode.export.range.selected", defaultValue: "선택 항목 (%lld)"), selectedVisitors.count))
                        .tag(EventModeExportRange.selected)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section(String(localized: "eventMode.export.format", defaultValue: "파일 형식")) {
                Picker(String(localized: "eventMode.export.format", defaultValue: "파일 형식"), selection: $format) {
                    ForEach(SpreadsheetFormat.allCases) { format in
                        Text(format.localizedName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            if format != .pdf, visitorsToExport.contains(where: { !$0.cardImagePath.isEmpty }) {
                Section {
                    Toggle(isOn: $includeCardImagesZip) {
                        Text(String(localized: "eventMode.export.includeCardImages", defaultValue: "명함 이미지 ZIP 함께 내보내기"))
                    }
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
                    guard !isExporting else { return }
                    isExporting = true
                    Task {
                        await AdService.shared.showInterstitial()
                        runExport()
                        isExporting = false
                    }
                } label: {
                    Text(String(localized: "export.run"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
        .navigationTitle(String(localized: "action.export"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "action.cancel")) { dismiss() }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.urls)
        }
    }

    private var visitorsToExport: [EventVisitor] {
        switch range {
        case .all: allVisitors
        case .filtered: filteredVisitors
        case .selected: selectedVisitors
        }
    }

    private func runExport() {
        errorMessage = nil
        guard !visitorsToExport.isEmpty else {
            errorMessage = String(localized: "export.noData")
            return
        }
        do {
            let service = ExcelExportService()
            var urls = [try service.exportEventVisitors(
                visitorsToExport,
                format: format,
                eventName: preset.name
            )]
            if format != .pdf, includeCardImagesZip,
               let zipURL = try service.exportEventVisitorCardImagesZip(visitorsToExport, eventName: preset.name) {
                urls.append(zipURL)
            }
            sharePayload = EventModeExportSharePayload(urls: urls)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EventModeExportSharePayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}
