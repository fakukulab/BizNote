import Contacts
import Foundation

struct BusinessCardDuplicateCandidate: Identifiable, Sendable {
    enum Strength: String, Sendable {
        case strong
        case needsReview
        case newCandidate
    }

    let id: String
    let displayName: String
    let organizationName: String
    let score: Int
    let strength: Strength
    let reasons: [String]

    init(contact: CNContact, score: Int, reasons: [String]) {
        self.id = contact.identifier
        self.displayName = contact.displayName
        self.organizationName = contact.organizationName
        self.score = score
        self.reasons = reasons
        if score >= 90 {
            self.strength = .strong
        } else if score >= 60 {
            self.strength = .needsReview
        } else {
            self.strength = .newCandidate
        }
    }
}

enum BusinessCardDuplicateDetector {
    static func candidates(for draft: BusinessCardDraft, contacts: [CNContact]) -> [BusinessCardDuplicateCandidate] {
        contacts.compactMap { contact in
            let result = score(draft: draft, contact: contact)
            guard result.score >= 15 else { return nil }
            return BusinessCardDuplicateCandidate(contact: contact, score: result.score, reasons: result.reasons)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func score(draft: BusinessCardDraft, contact: CNContact) -> (score: Int, reasons: [String]) {
        var score = 0
        var reasons: [String] = []
        var usedStrongIdentity = false

        let draftEmail = normalizeEmail(draft.email)
        let contactEmails = contact.emailAddresses.map { normalizeEmail($0.value as String) }
        if !draftEmail.isEmpty, contactEmails.contains(draftEmail) {
            score += 100
            reasons.append("이메일 완전 일치")
            usedStrongIdentity = true
        }

        let draftPhones = [draft.phone, draft.officePhone].map(normalizePhone).filter { !$0.isEmpty }
        let contactPhones = contact.phoneNumbers.map { normalizePhone($0.value.stringValue) }.filter { !$0.isEmpty }
        if !draftPhones.isEmpty, !contactPhones.isEmpty, !Set(draftPhones).isDisjoint(with: Set(contactPhones)) {
            score += usedStrongIdentity ? 0 : 90
            reasons.append("전화번호 완전 일치")
            usedStrongIdentity = true
        }

        let draftName = normalizeName(draft.name)
        let contactName = normalizeName(contact.displayName)
        let draftCompany = normalizeCompany(draft.company)
        let contactCompany = normalizeCompany(contact.organizationName)
        let nameSimilar = isSimilar(draftName, contactName)
        let companySimilar = isSimilar(draftCompany, contactCompany)

        if !usedStrongIdentity, nameSimilar, companySimilar {
            score += 70
            reasons.append("이름과 회사 유사")
        } else {
            if nameSimilar {
                score += 35
                reasons.append("이름 유사")
            }
            if companySimilar {
                score += 20
                reasons.append("회사 유사")
            }
        }

        if websiteDomain(draft.website).isEmpty == false,
           websiteDomain(draft.website) == websiteDomain(contact.urlAddresses.first?.value as String? ?? "") {
            score += 15
            reasons.append("웹사이트 도메인 일치")
        }

        return (min(score, 100), reasons)
    }

    static func normalizePhone(_ value: String) -> String {
        var result = value.filter { $0.isNumber || $0 == "+" }
        if result.hasPrefix("00") {
            result.removeFirst(2)
            result = "+\(result)"
        }
        return result
    }

    static func normalizeEmail(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return trimmed.lowercased() }
        return "\(parts[0].lowercased())@\(parts[1].lowercased())"
    }

    static func normalizeName(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func normalizeCompany(_ value: String) -> String {
        var result = normalizeName(value)
        for suffix in ["co., ltd.", "co ltd", "inc.", "inc", "ltd.", "ltd", "llc", "corp.", "corp", "corporation", "주식회사", "(주)", "㈜"] {
            result = result.replacingOccurrences(of: suffix, with: "", options: [.caseInsensitive])
        }
        return result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func websiteDomain(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        var text = value.lowercased()
        if !text.contains("://") { text = "https://\(text)" }
        guard let host = URL(string: text)?.host(percentEncoded: false) else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func isSimilar(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        if lhs == rhs { return true }
        if lhs.count >= 4, rhs.count >= 4, (lhs.contains(rhs) || rhs.contains(lhs)) { return true }
        return jaccard(lhs, rhs) >= 0.72
    }

    private static func jaccard(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(lhs.map(String.init))
        let right = Set(rhs.map(String.init))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }
}
