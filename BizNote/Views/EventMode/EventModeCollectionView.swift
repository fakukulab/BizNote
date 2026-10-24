import SwiftUI

private enum EventModeCollectionSheet: Identifiable {
    case scan
    case manualEntry(EventVisitorDraft?, EventVisitorCollectionMethod)

    var id: String {
        switch self {
        case .scan: "scan"
        case .manualEntry: "manualEntry"
        }
    }
}

struct EventModeCollectionView: View {
    @Bindable var preset: ExhibitionPreset

    @State private var activeSheet: EventModeCollectionSheet?
    @State private var playback = EventModePlaybackController()
    @State private var promoVideoFilenames = EventModeSettings.promoVideoFilenames
    @ScaledMetric private var placeholderIconSize: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if !promoVideoFilenames.isEmpty {
                    EventModePromoVideoView(player: playback.player)
                        .ignoresSafeArea()
                } else {
                    Color(.secondarySystemBackground)
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: placeholderIconSize))
                            .foregroundStyle(.secondary)
                        Text(preset.name.isEmpty ? EventModeSettings.localized("note.untitled", defaultValue: "제목 없음") : preset.name)
                            .font(.title.bold())
                        Text(EventModeSettings.localized("eventMode.collection.placeholder", defaultValue: "명함을 등록해 주세요"))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                EventModeCollectionButton(
                    title: EventModeSettings.localized("eventMode.collection.scanCard", defaultValue: "명함 스캔"),
                    systemImage: "camera.viewfinder"
                ) {
                    activeSheet = .scan
                }

                Divider()

                EventModeCollectionButton(
                    title: EventModeSettings.localized("eventMode.collection.manualInput", defaultValue: "직접 입력"),
                    systemImage: "character.cursor.ibeam"
                ) {
                    activeSheet = .manualEntry(nil, .manualInput)
                }
            }
            .frame(height: 140)
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            switch sheet {
            case .scan:
                EventModeCardScanFlow(
                    onScanned: { draft in
                        activeSheet = .manualEntry(draft, .cardScan)
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            case .manualEntry(let draft, let method):
                EventModeManualEntryView(
                    preset: preset,
                    initialDraft: draft,
                    initialCollectionMethod: method
                )
            }
        }
        .onAppear {
            promoVideoFilenames = EventModeSettings.promoVideoFilenames
            playback.configure(filenames: promoVideoFilenames)
            playback.startObservingLoop()
            playback.play()
        }
        .onDisappear {
            playback.pause()
            playback.stopObservingLoop()
        }
        .onChange(of: activeSheet == nil) { _, isNoSheetPresented in
            if isNoSheetPresented {
                promoVideoFilenames = EventModeSettings.promoVideoFilenames
                playback.configure(filenames: promoVideoFilenames)
                playback.play()
            } else {
                playback.pause()
            }
        }
    }
}
