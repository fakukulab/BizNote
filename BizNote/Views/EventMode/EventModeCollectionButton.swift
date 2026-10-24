import SwiftUI

/// One of the two large touch targets on the collection screen
/// ("명함 스캔" / "직접 입력").
struct EventModeCollectionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @ScaledMetric private var iconSize: CGFloat = 32

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize))
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: EventModeDesign.collectionButtonMinHeight)
        }
        .buttonStyle(.plain)
        .background(Color.accentColor.opacity(0.1))
    }
}
