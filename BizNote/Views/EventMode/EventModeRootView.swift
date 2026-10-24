import SwiftUI

struct EventModeRootView: View {
    @State private var selectedPreset: ExhibitionPreset?

    var body: some View {
        Group {
            if let selectedPreset {
                EventModeContainerView(preset: selectedPreset)
            } else {
                EventModeEntryView { preset in
                    EventModeSettings.activePresetID = preset.id
                    selectedPreset = preset
                }
            }
        }
    }
}
