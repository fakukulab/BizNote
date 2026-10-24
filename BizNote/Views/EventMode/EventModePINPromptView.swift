import SwiftUI

struct EventModePINPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric private var iconSize: CGFloat = 44
    @State private var input = ""
    @State private var showError = false

    var onComplete: (Bool) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.secondary)

                Text(String(localized: "eventMode.pin.prompt", defaultValue: "담당자 PIN을 입력하세요"))
                    .font(.headline)

                SecureField(String(localized: "eventMode.pin.placeholder", defaultValue: "PIN"), text: $input)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .frame(maxWidth: 200)
                    .textFieldStyle(.roundedBorder)

                if showError {
                    Text(String(localized: "eventMode.pin.error", defaultValue: "PIN이 일치하지 않습니다."))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(String(localized: "action.confirm", defaultValue: "확인")) {
                    if input == EventModeSettings.staffPIN {
                        onComplete(true)
                    } else {
                        showError = true
                        input = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.isEmpty)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
