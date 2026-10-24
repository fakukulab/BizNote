import SwiftData
import Foundation
import SwiftUI

enum EventVisitorCollectionMethod: String, Codable, CaseIterable, Sendable {
    case manualInput
    case cardScan

    var localizedName: String {
        switch self {
        case .manualInput:
            String(localized: "eventMode.collectionMethod.manualInput", defaultValue: "직접 입력")
        case .cardScan:
            String(localized: "eventMode.collectionMethod.cardScan", defaultValue: "명함 스캔")
        }
    }
}

enum EventVisitorInterestArea: String, Codable, CaseIterable, Identifiable, Sendable {
    case academicProgram
    case exhibition
    case both

    var id: String { rawValue }

    var localizedName: String { localizedName(locale: .current) }

    // `String(localized:defaultValue:locale:)` ignores the `locale:` argument
    // at runtime; routing through `LocalizedStringResource` is what actually
    // honors it.
    func localizedName(locale: Locale) -> String {
        switch self {
        case .academicProgram:
            String(localized: LocalizedStringResource("eventMode.interestArea.academicProgram", defaultValue: "학술프로그램", locale: locale))
        case .exhibition:
            String(localized: LocalizedStringResource("eventMode.interestArea.exhibition", defaultValue: "전시회", locale: locale))
        case .both:
            String(localized: LocalizedStringResource("eventMode.interestArea.both", defaultValue: "모두", locale: locale))
        }
    }

    /// Icon/color pairing used wherever this needs to read as an unmistakable
    /// badge rather than plain text (visitor list and detail screens).
    var iconName: String {
        switch self {
        case .academicProgram: "graduationcap.fill"
        case .exhibition: "building.columns.fill"
        case .both: "star.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .academicProgram: .blue
        case .exhibition: .purple
        case .both: .indigo
        }
    }
}

struct EventVisitorDraft: Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String = ""
    var company: String = ""
    var jobTitle: String = ""
    var email: String = ""
    var mobile: String = ""
    var phone: String = ""
    var countryCode: String = ""
    var memo: String = ""
    var interestArea: EventVisitorInterestArea?
    var wantsMaterials: Bool?
    var cardImagePath: String = ""

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMobile: String { mobile.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isValid: Bool {
        !trimmedName.isEmpty && (!trimmedEmail.isEmpty || !trimmedMobile.isEmpty)
    }

    /// Merges the pages of a single scanned card (e.g. front + back) into one
    /// draft, preferring whichever page recognized each field and keeping the
    /// first page's image as the representative thumbnail.
    static func merging(businessCardDrafts drafts: [BusinessCardDraft], countryCode: String) -> EventVisitorDraft {
        var merged = EventVisitorDraft()
        merged.countryCode = countryCode

        func firstNonEmpty(_ pick: (BusinessCardDraft) -> String) -> String {
            for draft in drafts {
                let value = pick(draft).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            return ""
        }

        merged.name = firstNonEmpty { $0.name }
        merged.company = firstNonEmpty { $0.company }
        merged.jobTitle = firstNonEmpty { $0.jobTitle }
        merged.email = firstNonEmpty { $0.email }
        merged.mobile = firstNonEmpty { $0.phone }
        merged.phone = firstNonEmpty { $0.officePhone }
        merged.memo = drafts
            .map(\.memo)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        merged.cardImagePath = drafts.first { !$0.imagePath.isEmpty }?.imagePath ?? ""

        return merged
    }
}

@Model
final class EventVisitor {
    var id: UUID = UUID()
    var createdAt: Date = Date.now

    var name: String = ""
    var company: String = ""
    var jobTitle: String = ""
    var email: String = ""
    var mobile: String = ""
    var phone: String = ""
    var countryCode: String = ""
    var memo: String = ""
    var wantsMaterials: Bool?
    var cardImagePath: String = ""

    var collectionMethodRaw: String = EventVisitorCollectionMethod.manualInput.rawValue
    var interestAreaRaw: String?
    var consentAt: Date?

    var exhibitionPreset: ExhibitionPreset?

    var collectionMethod: EventVisitorCollectionMethod {
        get { EventVisitorCollectionMethod(rawValue: collectionMethodRaw) ?? .manualInput }
        set { collectionMethodRaw = newValue.rawValue }
    }

    var interestArea: EventVisitorInterestArea? {
        get { interestAreaRaw.flatMap(EventVisitorInterestArea.init(rawValue:)) }
        set { interestAreaRaw = newValue?.rawValue }
    }

    init() {
        self.id = UUID()
        self.createdAt = .now
    }

    func isDuplicateCandidate(in visitors: [EventVisitor]) -> Bool {
        visitors.contains { other in
            other.id != id &&
            ((!email.isEmpty && other.email == email) || (!mobile.isEmpty && other.mobile == mobile))
        }
    }

    /// Groups visitors that share a non-empty email or mobile number.
    static func duplicateGroups(in visitors: [EventVisitor]) -> [[EventVisitor]] {
        var groups: [[EventVisitor]] = []
        var consumedIDs = Set<UUID>()

        for visitor in visitors {
            guard !consumedIDs.contains(visitor.id) else { continue }
            let matches = visitors.filter { other in
                !consumedIDs.contains(other.id) &&
                other.id != visitor.id &&
                ((!visitor.email.isEmpty && other.email == visitor.email) ||
                 (!visitor.mobile.isEmpty && other.mobile == visitor.mobile))
            }
            guard !matches.isEmpty else { continue }

            let group = ([visitor] + matches).sorted { $0.createdAt < $1.createdAt }
            for member in group { consumedIDs.insert(member.id) }
            groups.append(group)
        }

        return groups
    }

    /// Folds another visitor's fields into this one, keeping existing
    /// non-empty values and preferring the earliest registration time.
    func absorb(_ other: EventVisitor) {
        if name.isEmpty { name = other.name }
        if company.isEmpty { company = other.company }
        if jobTitle.isEmpty { jobTitle = other.jobTitle }
        if email.isEmpty { email = other.email }
        if mobile.isEmpty { mobile = other.mobile }
        if phone.isEmpty { phone = other.phone }
        if countryCode.isEmpty { countryCode = other.countryCode }
        if cardImagePath.isEmpty { cardImagePath = other.cardImagePath }
        if interestArea == nil { interestArea = other.interestArea }
        if wantsMaterials == nil {
            wantsMaterials = other.wantsMaterials
        } else if other.wantsMaterials == true {
            wantsMaterials = true
        }

        let combinedMemo = [memo, other.memo]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        memo = combinedMemo.joined(separator: "\n")

        if other.createdAt < createdAt {
            createdAt = other.createdAt
        }
        if other.consentAt != nil, consentAt == nil {
            consentAt = other.consentAt
        }
    }

    convenience init(
        draft: EventVisitorDraft,
        collectionMethod: EventVisitorCollectionMethod = .manualInput,
        consentAt: Date? = nil,
        exhibitionPreset: ExhibitionPreset? = nil
    ) {
        self.init()
        self.id = draft.id
        self.name = draft.trimmedName
        self.company = draft.company.trimmingCharacters(in: .whitespacesAndNewlines)
        self.jobTitle = draft.jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = draft.trimmedEmail
        self.mobile = draft.trimmedMobile
        self.phone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        self.countryCode = draft.countryCode
        self.memo = draft.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        self.wantsMaterials = draft.wantsMaterials
        self.cardImagePath = draft.cardImagePath
        self.collectionMethodRaw = collectionMethod.rawValue
        self.interestAreaRaw = draft.interestArea?.rawValue
        self.consentAt = consentAt
        self.exhibitionPreset = exhibitionPreset
    }
}
