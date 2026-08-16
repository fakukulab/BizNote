import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(subtitle)
        }
    }
}

#Preview {
    EmptyStateView(
        title: String(localized: "empty.noNotes"),
        subtitle: String(localized: "empty.startNew"),
        systemImage: "note.text"
    )
}
