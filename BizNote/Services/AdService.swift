import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Owns consent (UMP), AdMob setup and the interstitial lifecycle.
@MainActor
@Observable
final class AdService: NSObject, FullScreenContentDelegate {
    static let shared = AdService()

    /// Debug builds use Google's sample units so development taps never hit real ads.
    enum UnitID {
        #if DEBUG
        static let banner = "ca-app-pub-3940256099942544/2435281174"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        #else
        static let banner = "ca-app-pub-5901094490845157/1557972633"
        static let interstitial = "ca-app-pub-5901094490845157/8881928886"
        #endif
    }

    /// Every ad request is non-personalized (`npa=1`); the app does not use ATT.
    static func makeRequest() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    /// Minimum gap between two interstitials so repeated actions are not blocked by ads.
    private static let minimumInterval: TimeInterval = 60

    private var interstitial: InterstitialAd?
    private var isLoading = false
    private var lastShownAt: Date?
    private var dismissContinuation: CheckedContinuation<Void, Never>?

    /// True once consent allows ad requests. Ads must not be requested before this.
    private(set) var canRequestAds = false

    /// True where regulation requires an entry point to re-open the consent choices.
    private(set) var isPrivacyOptionsRequired = false

    @ObservationIgnored private var hasStarted = false

    /// Gathers consent (UMP form if required), asks for tracking permission (ATT), then starts the Mobile Ads SDK.
    /// Safe to call repeatedly; only the first call does work.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: Self.topViewController())
        } catch {
            // Consent could not be gathered; fall through and honour whatever status is stored.
        }
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required

        // Order recommended by Google: consent (UMP), then ATT, then start the SDK so that a
        // granted ATT permission is already in effect for the first ad request.
        if ConsentInformation.shared.canRequestAds {
            await requestTrackingAuthorizationIfNeeded()
        }
        startMobileAdsIfAllowed()
    }

    /// Shows the App Tracking Transparency prompt once. The system only presents it while the
    /// app is active, so wait briefly for that (e.g. right after a consent form is dismissed).
    private func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        for _ in 0..<20 where UIApplication.shared.applicationState != .active {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Re-opens the consent choices (Settings entry point required in some regions).
    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: Self.topViewController())
        } catch {
            // Nothing to recover; the previous choice stays in effect.
        }
        startMobileAdsIfAllowed()
    }

    private func startMobileAdsIfAllowed() {
        guard ConsentInformation.shared.canRequestAds, !canRequestAds else { return }
        MobileAds.shared.start(completionHandler: nil)
        canRequestAds = true
        loadInterstitial()
    }

    /// Shows an interstitial and returns once it is dismissed. Returns immediately
    /// when no ad is ready or the cooldown has not elapsed, so the caller's
    /// action is never blocked by ad availability.
    func showInterstitial() async {
        guard canRequestAds else { return }
        if let lastShownAt, Date().timeIntervalSince(lastShownAt) < Self.minimumInterval {
            return
        }
        guard let ad = interstitial, let presenter = Self.topViewController() else {
            loadInterstitial()
            return
        }
        interstitial = nil
        ad.fullScreenContentDelegate = self
        await withCheckedContinuation { continuation in
            dismissContinuation = continuation
            lastShownAt = Date()
            ad.present(from: presenter)
        }
        loadInterstitial()
    }

    private func loadInterstitial() {
        guard canRequestAds, interstitial == nil, !isLoading else { return }
        isLoading = true
        Task {
            do {
                interstitial = try await InterstitialAd.load(with: UnitID.interstitial, request: Self.makeRequest())
            } catch {
                interstitial = nil
            }
            isLoading = false
        }
    }

    private func finishPresentation() {
        dismissContinuation?.resume()
        dismissContinuation = nil
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finishPresentation()
    }

    // MARK: Presenter lookup

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Bottom banner: 728x90 leaderboard on iPad when the width allows it, otherwise the
/// smallest standard 320x50 banner. The banner is always laid out at its real size
/// (AdMob rejects a load into a zero-sized view), but the visible area stays collapsed
/// until an ad is received and while the keyboard is up, so it never covers typing.
struct AdBannerView: View {
    fileprivate enum Kind {
        case banner
        case leaderboard

        var adSize: AdSize { self == .leaderboard ? AdSizeLeaderboard : AdSizeBanner }
        var size: CGSize { adSize.size }
    }

    @State private var isLoaded = false
    @State private var isKeyboardVisible = false
    @State private var availableWidth: CGFloat = 0

    private var kind: Kind {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return isPad && availableWidth >= AdSizeLeaderboard.size.width ? .leaderboard : .banner
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .frame(height: 0)
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }

            // Wait for the first width measurement so the ad is loaded once, at its final size.
            if availableWidth > 0, AdService.shared.canRequestAds {
                AdBannerRepresentable(kind: kind, isLoaded: $isLoaded)
                    .id(kind)
                    .frame(width: kind.size.width, height: kind.size.height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isLoaded && !isKeyboardVisible ? kind.size.height : 0, alignment: .top)
        .clipped()
        .onChange(of: kind) { isLoaded = false }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) {
                isKeyboardVisible = true
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) {
                isKeyboardVisible = false
            }
        }
    }
}

private struct AdBannerRepresentable: UIViewRepresentable {
    let kind: AdBannerView.Kind
    @Binding var isLoaded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: kind.adSize)
        banner.adUnitID = AdService.UnitID.banner
        banner.rootViewController = AdService.topViewController()
        banner.delegate = context.coordinator
        banner.load(AdService.makeRequest())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var isLoaded: Bool

        init(isLoaded: Binding<Bool>) {
            _isLoaded = isLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            isLoaded = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            isLoaded = false
        }
    }
}
