import SwiftUI

struct EventModePINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var showMismatchError = false

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "eventMode.pinSetup.new", defaultValue: "새 PIN (4자리 이상)"), text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField(String(localized: "eventMode.pinSetup.confirm", defaultValue: "PIN 확인"), text: $confirmPIN)
                        .keyboardType(.numberPad)
                }
                if showMismatchError {
                    Section {
                        Label(
                            String(localized: "eventMode.pinSetup.mismatch", defaultValue: "PIN이 일치하지 않거나 너무 짧습니다."),
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "eventMode.settings.pin.setup", defaultValue: "PIN 설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                }
            }
        }
    }

    private func save() {
        guard newPIN.count >= 4, newPIN == confirmPIN else {
            showMismatchError = true
            return
        }
        EventModeSettings.staffPIN = newPIN
        onComplete()
        dismiss()
    }
}
