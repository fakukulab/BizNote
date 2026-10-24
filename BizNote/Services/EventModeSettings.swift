import Foundation

enum EventModeLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case russian = "ru"
    case kazakh = "kk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        case .japanese: return "日本語"
        case .chineseSimplified: return "中文(简体)"
        case .chineseTraditional: return "中文(繁體)"
        case .russian: return "Русский"
        case .kazakh: return "Қазақша"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Vision's `VNRecognizeTextRequest` has no dedicated Kazakh model, so Kazakh
    /// cards are recognized using the Cyrillic-based Russian model instead (per
    /// the event-mode spec's own note on this limitation).
    var ocrRecognitionLanguage: String {
        switch self {
        case .korean: "ko-KR"
        case .english: "en-US"
        case .japanese: "ja-JP"
        case .chineseSimplified: "zh-Hans"
        case .chineseTraditional: "zh-Hant"
        case .russian, .kazakh: "ru-RU"
        }
    }
}

enum EventModeOCR {
    static let baseRecognitionLanguages = ["ko-KR", "en-US", "ja-JP", "zh-Hans", "zh-Hant", "ru-RU"]

    static func recognitionLanguages(prioritizing language: EventModeLanguage) -> [String] {
        let preferred = language.ocrRecognitionLanguage
        return [preferred] + baseRecognitionLanguages.filter { $0 != preferred }
    }
}

enum EventModeSettings {
    static let visitorLanguageKey = "eventMode.visitorLanguage"
    static let defaultCountryCodeKey = "eventMode.defaultCountryCode"
    static let consentTextKey = "eventMode.consentText"
    static let activePresetIDKey = "eventMode.activePresetID"
    static let promoVideoFilenamesKey = "eventMode.promoVideoFilenames"
    static let promoVideoMutedKey = "eventMode.promoVideoMuted"
    static let biometricUnlockEnabledKey = "eventMode.biometricUnlockEnabled"

    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            visitorLanguageKey: EventModeLanguage.korean.rawValue,
            defaultCountryCodeKey: "KR",
            promoVideoMutedKey: true
        ])
    }

    /// The localized default consent text for a given visitor language.
    /// `String(localized:defaultValue:locale:)` silently ignores the
    /// `locale:` argument at runtime (verified: it always resolves against
    /// `Bundle.main.preferredLocalizations` instead). Going through
    /// `LocalizedStringResource` explicitly is the mechanism that actually
    /// honors the requested locale.
    static func localizedConsentText(for language: EventModeLanguage) -> String {
        String(localized: LocalizedStringResource(
            "eventMode.consent.defaultText",
            defaultValue: "입력하신 개인정보는 본 행사의 리드 관리 목적으로만 사용되며, 별도 요청이 없는 한 안전하게 보관됩니다.",
            locale: language.locale
        ))
    }

    static var defaultConsentText: String { localizedConsentText(for: .korean) }

    static var visitorLanguage: EventModeLanguage {
        get { EventModeLanguage(rawValue: defaults.string(forKey: visitorLanguageKey) ?? "") ?? .korean }
        set { defaults.set(newValue.rawValue, forKey: visitorLanguageKey) }
    }

    static var defaultCountryCode: String {
        get { defaults.string(forKey: defaultCountryCodeKey) ?? "KR" }
        set { defaults.set(newValue, forKey: defaultCountryCodeKey) }
    }

    /// The PIN gates access to visitors' personal information, so it is
    /// stored in the Keychain rather than `UserDefaults`.
    static var staffPIN: String? {
        get { EventModeKeychain.staffPIN }
        set { EventModeKeychain.staffPIN = newValue }
    }

    /// A staff-authored override of the consent text, in Korean (the language
    /// the settings editor is shown in). `nil` means "use the localized
    /// default for whichever language is selected."
    static var consentTextOverride: String? {
        get { defaults.string(forKey: consentTextKey) }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                defaults.set(newValue, forKey: consentTextKey)
            } else {
                defaults.removeObject(forKey: consentTextKey)
            }
        }
    }

    /// The consent text shown to visitors. The staff override only applies
    /// when the visitor language is Korean (the language it was written
    /// in); every other language always shows the localized default, since
    /// a free-text override can't be auto-translated reliably.
    static var consentText: String {
        if visitorLanguage == .korean, let override = consentTextOverride {
            return override
        }
        return localizedConsentText(for: visitorLanguage)
    }

    static var activePresetID: UUID? {
        get { defaults.string(forKey: activePresetIDKey).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: activePresetIDKey) }
    }

    static var promoVideoFilenames: [String] {
        get { defaults.stringArray(forKey: promoVideoFilenamesKey) ?? [] }
        set { defaults.set(newValue, forKey: promoVideoFilenamesKey) }
    }

    static var isPromoVideoMuted: Bool {
        get { defaults.bool(forKey: promoVideoMutedKey) }
        set { defaults.set(newValue, forKey: promoVideoMutedKey) }
    }

    static var isBiometricUnlockEnabled: Bool {
        get { defaults.bool(forKey: biometricUnlockEnabledKey) }
        set { defaults.set(newValue, forKey: biometricUnlockEnabledKey) }
    }

    /// `String(localized:)` resolves against the app/system locale, not SwiftUI's
    /// `\.locale` environment, so visitor-facing screens must request the
    /// selected visitor language explicitly through this helper instead.
    /// Must go through `LocalizedStringResource` — the `locale:` argument on
    /// `String(localized:defaultValue:locale:)` itself is silently ignored
    /// at runtime (confirmed via RunCodeSnippet).
    static func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, defaultValue: defaultValue, locale: visitorLanguage.locale))
    }
}
