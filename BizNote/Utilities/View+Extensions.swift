import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    @ViewBuilder
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            #endif
        }
    }

    /// Calls `action` once the enclosing push/presentation transition has
    /// fully finished animating. SwiftUI's `.onAppear` fires while a
    /// push/sheet transition can still be animating in; presenting a
    /// *nested* sheet during that window makes it open and immediately
    /// dismiss again. This waits for the real UIKit transition completion
    /// instead of guessing with a fixed delay.
    @ViewBuilder
    func onTransitionComplete(_ action: @escaping () -> Void) -> some View {
        #if canImport(UIKit)
        background(TransitionCompletionDetector(onComplete: action))
        #else
        self.onAppear(perform: action)
        #endif
    }
}

private struct SheetPresentationReadyKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether it's currently safe to present a nested sheet. False for the
    /// brief moment right after a screen appears via push or sheet
    /// presentation, until that transition has fully completed animating.
    var isReadyForSheetPresentation: Bool {
        get { self[SheetPresentationReadyKey.self] }
        set { self[SheetPresentationReadyKey.self] = newValue }
    }
}

#if canImport(UIKit)
private struct TransitionCompletionDetector: UIViewControllerRepresentable {
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> DetectorViewController {
        let vc = DetectorViewController()
        vc.onComplete = onComplete
        return vc
    }

    func updateUIViewController(_ uiViewController: DetectorViewController, context: Context) {}

    final class DetectorViewController: UIViewController {
        var onComplete: (() -> Void)?
        private var didFire = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !didFire else { return }
            if let coordinator = transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                    self?.scheduleFire()
                }
            } else {
                scheduleFire()
            }
        }

        // The transition coordinator's completion can fire a frame or two
        // before the presentation is actually settled on-device (this gap
        // is wider on real hardware than in the Simulator). Presenting a
        // nested sheet inside that gap causes it to open and immediately
        // dismiss, sometimes taking the parent sheet down with it. A short
        // buffer after "done" avoids racing that window.
        private func scheduleFire() {
            guard !didFire else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.fire()
            }
        }

        private func fire() {
            guard !didFire else { return }
            didFire = true
            onComplete?()
        }
    }
}
#endif
