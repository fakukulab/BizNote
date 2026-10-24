import SwiftUI

struct EventCountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @Binding var selection: String
    var locale: Locale = .current

    var body: some View {
        NavigationStack {
            List {
                ForEach(EventCountry.matching(query, locale: locale)) { country in
                    Button {
                        selection = country.code
                        dismiss()
                    } label: {
                        HStack {
                            Text(country.localizedName(locale: locale))
                                .foregroundStyle(.primary)
                            if let dialCode = country.dialCode {
                                Text(dialCode)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            if country.code == selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: String(localized: LocalizedStringResource("search.prompt", defaultValue: "Search", locale: locale)))
            .navigationTitle(String(localized: LocalizedStringResource("eventMode.country.pickerTitle", defaultValue: "국가 선택", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("action.cancel", defaultValue: "취소", locale: locale))) { dismiss() }
                }
            }
        }
    }
}
