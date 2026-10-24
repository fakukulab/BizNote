import Foundation

/// Shared layout constants for the Event Mode feature, so repeated values
/// (corner radius, minimum touch target) stay consistent and easy to adjust
/// in one place.
enum EventModeDesign {
    /// Corner radius used for business-card image previews/thumbnails.
    static let cardImageCornerRadius: CGFloat = 12

    /// Apple's minimum recommended tap target size.
    static let minimumTapTarget: CGFloat = 44

    /// Height of the two large collection-screen buttons, per the event-mode
    /// spec's requirement that they be easy to tap on a kiosk iPad.
    static let collectionButtonMinHeight: CGFloat = 88
}
