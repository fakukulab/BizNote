import Foundation
import AVFoundation

/// Owns the promo-video playback queue for the collection screen. This holds
/// no state that SwiftUI needs to observe for re-rendering — the view only
/// ever reads `player` once to hand it to `AVPlayerLayer` — so it is a plain
/// reference type cached via `@State`, not an `ObservableObject`.
@MainActor
final class EventModePlaybackController {
    let player = AVQueuePlayer()

    private var filenames: [String] = []
    private var endObserver: NSObjectProtocol?

    func configure(filenames: [String]) {
        guard filenames != self.filenames else { return }
        self.filenames = filenames
        rebuildQueue()
    }

    func play() {
        guard !filenames.isEmpty else { return }
        if player.items().isEmpty {
            rebuildQueue()
        }
        applyMuteSetting()
        player.play()
    }

    /// Re-reads the mute setting so a change made in Settings takes effect
    /// immediately when returning to the collection screen, without needing
    /// to rebuild the playback queue.
    func applyMuteSetting() {
        let muted = EventModeSettings.isPromoVideoMuted
        player.isMuted = muted
        guard !muted else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func pause() {
        player.pause()
    }

    func startObservingLoop() {
        stopObservingLoop()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.player.items().count <= 1 {
                    self.rebuildQueue()
                    self.player.play()
                }
            }
        }
    }

    func stopObservingLoop() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func rebuildQueue() {
        player.removeAllItems()
        for filename in filenames {
            player.insert(AVPlayerItem(url: EventModeVideoStorage.url(for: filename)), after: nil)
        }
        applyMuteSetting()
    }
}
