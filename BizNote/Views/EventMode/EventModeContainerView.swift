import SwiftUI
import UIKit
import LocalAuthentication

enum EventModeTab: Hashable {
    case collection
    case visitorList
    case settings
}

struct EventModeContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preset: ExhibitionPreset

    @State private var tab: EventModeTab = .collection
    @State private var isStaffUnlocked = false
    @State private var showPINPrompt = false
    @State private var showExitConfirm = false

    var body: some View {
        ZStack {
            Group {
                switch tab {
                case .collection:
                    EventModeCollectionView(preset: preset)
                case .visitorList:
                    NavigationStack { EventModeVisitorListView(preset: preset) }
                case .settings:
                    NavigationStack { EventModeSettingsView() }
                }
            }

            VStack {
                if isStaffUnlocked {
                    staffToolbar
                }
                Spacer()
            }

            cornerUnlockTrigger
        }
        .statusBarHidden(!isStaffUnlocked)
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $showPINPrompt) {
            EventModePINPromptView { success in
                showPINPrompt = false
                guard success else { return }
                isStaffUnlocked = true
                tab = .visitorList
            }
        }
        .confirmationDialog(
            String(localized: "eventMode.exit.title", defaultValue: "행사 모드를 종료할까요?"),
            isPresented: $showExitConfirm
        ) {
            Button(String(localized: "eventMode.exit.confirm", defaultValue: "종료"), role: .destructive) {
                dismiss()
            }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        }
    }

    private var staffToolbar: some View {
        HStack(spacing: 16) {
            Picker(String(localized: "eventMode.tab.picker", defaultValue: "화면 전환"), selection: $tab) {
                Text(String(localized: "eventMode.tab.collection", defaultValue: "수집 화면")).tag(EventModeTab.collection)
                Text(String(localized: "eventMode.tab.visitorList", defaultValue: "방문객 목록")).tag(EventModeTab.visitorList)
                Text(String(localized: "eventMode.tab.settings", defaultValue: "설정")).tag(EventModeTab.settings)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            Button(role: .destructive) {
                showExitConfirm = true
            } label: {
                Label(String(localized: "eventMode.exit.button", defaultValue: "행사 모드 종료"), systemImage: "xmark.circle.fill")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .onChange(of: tab) { _, newTab in
            if newTab == .collection {
                isStaffUnlocked = false
            }
        }
    }

    private var cornerUnlockTrigger: some View {
        VStack {
            HStack {
                Spacer()
                // Deliberately faint so visitors don't notice it, but a recognizable "info"
                // shape (rather than a fully invisible hotspot) so staff can reliably find
                // and tap it without having to memorize an exact blind spot.
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.gray.opacity(0.45))
                    .frame(width: 72, height: 72)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleCornerUnlock()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(String(localized: "eventMode.staff.unlock", defaultValue: "담당자 잠금 해제"))
            }
            Spacer()
        }
        .opacity(isStaffUnlocked ? 0 : 1)
        .allowsHitTesting(!isStaffUnlocked)
    }

    private func handleCornerUnlock() {
        guard let pin = EventModeSettings.staffPIN, !pin.isEmpty else {
            isStaffUnlocked = true
            tab = .visitorList
            return
        }

        if EventModeSettings.isBiometricUnlockEnabled {
            attemptBiometricUnlock()
        } else {
            showPINPrompt = true
        }
    }

    private func attemptBiometricUnlock() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            showPINPrompt = true
            return
        }

        let reason = String(localized: "eventMode.biometric.reason", defaultValue: "담당자 화면 잠금을 해제합니다")
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            Task { @MainActor in
                if success {
                    isStaffUnlocked = true
                    tab = .visitorList
                } else {
                    showPINPrompt = true
                }
            }
        }
    }
}
