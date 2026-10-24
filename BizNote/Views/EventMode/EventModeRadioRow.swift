import SwiftUI

/// A single-selection radio row, used for the "관심분야" and "자료 요청"
/// choices on the manual entry form.
struct EventModeRadioRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
