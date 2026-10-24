import Foundation

struct EventCountry: Identifiable, Hashable, Sendable {
    let code: String

    var id: String { code }

    var localizedName: String { localizedName(locale: .current) }

    func localizedName(locale: Locale) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    var dialCode: String? { EventCountry.dialCodes[code] }

    static let pinnedCodes = ["KR", "US", "JP", "CN", "TW", "RU", "KZ"]

    static let dialCodes: [String: String] = [
        "KR": "+82", "US": "+1", "JP": "+81", "CN": "+86", "TW": "+886",
        "HK": "+852", "MO": "+853", "SG": "+65", "MY": "+60", "TH": "+66",
        "VN": "+84", "ID": "+62", "PH": "+63", "IN": "+91", "RU": "+7",
        "KZ": "+7", "UZ": "+998", "MN": "+976", "GB": "+44", "DE": "+49",
        "FR": "+33", "IT": "+39", "ES": "+34", "NL": "+31", "CH": "+41",
        "CA": "+1", "AU": "+61", "NZ": "+64", "AE": "+971", "SA": "+966",
        "QA": "+974", "TR": "+90", "BR": "+55", "MX": "+52"
    ]

    static var all: [EventCountry] { all(locale: .current) }

    static func all(locale: Locale) -> [EventCountry] {
        NSLocale.isoCountryCodes
            .map { EventCountry(code: $0) }
            .filter { !$0.localizedName(locale: locale).isEmpty && $0.localizedName(locale: locale) != $0.code }
            .sorted { $0.localizedName(locale: locale).localizedStandardCompare($1.localizedName(locale: locale)) == .orderedAscending }
    }

    static var pinned: [EventCountry] {
        pinnedCodes.map { EventCountry(code: $0) }
    }

    static func matching(_ query: String, locale: Locale = .current) -> [EventCountry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let allCountries = all(locale: locale)
        guard !trimmed.isEmpty else { return pinned + allCountries.filter { !pinnedCodes.contains($0.code) } }
        return allCountries.filter {
            $0.localizedName(locale: locale).localizedStandardContains(trimmed) ||
            $0.code.localizedStandardContains(trimmed)
        }
    }
}
