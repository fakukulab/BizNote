import Foundation

private enum PhoneNumberKind {
    case mobile
    case office
    case fax
    case unlabeled
}

private struct LabeledPhoneNumber {
    let kind: PhoneNumberKind
    let number: String
}

private struct ParsedBusinessCardLine {
    let text: String
    let candidateTexts: [String]
    let confidence: Float
    let minX: Double
    let minY: Double
    let width: Double
    let height: Double
    let sourceIndex: Int

    var maxX: Double { minX + width }
    var midX: Double { minX + width / 2 }
    var midY: Double { minY + height / 2 }
    var isPositioned: Bool { width > 0 || height > 0 }

    var textsForParsing: [String] {
        ([text] + candidateTexts)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in
                if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                    result.append(value)
                }
            }
    }
}

final class BusinessCardParser {

    func parse(recognizedLines: [RecognizedLine], language: String = "ko") -> BusinessCardDraft {
        let usableLines = recognizedLines
            .filter { $0.confidence >= 0.2 && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                let yDifference = abs(lhs.midY - rhs.midY)
                if yDifference > 0.025 {
                    return lhs.midY > rhs.midY
                }
                return lhs.minX < rhs.minX
            }
            .enumerated()
            .map { index, line in
                ParsedBusinessCardLine(
                    text: line.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    candidateTexts: line.candidateTexts,
                    confidence: line.confidence,
                    minX: line.minX,
                    minY: line.minY,
                    width: line.width,
                    height: line.height,
                    sourceIndex: index
                )
            }

        return parse(lineCandidates: usableLines, language: language)
    }

    func parse(lines: [String], language: String = "ko") -> BusinessCardDraft {
        let lineCandidates = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, text in
                ParsedBusinessCardLine(
                    text: text,
                    candidateTexts: [],
                    confidence: 1,
                    minX: 0,
                    minY: 0,
                    width: 0,
                    height: 0,
                    sourceIndex: index
                )
            }

        return parse(lineCandidates: lineCandidates, language: language)
    }

    private func parse(lineCandidates: [ParsedBusinessCardLine], language: String) -> BusinessCardDraft {
        var card = BusinessCardDraft()
        card.scannedLanguage = language

        var remaining = lineCandidates

        if let extraction = extractEmail(from: remaining) {
            card.email = extraction.value
        }

        if let extraction = extractWebsite(from: remaining) {
            card.website = extraction.value
            removeLine(at: extraction.index, from: &remaining)
        }

        assignPhoneNumbers(from: &remaining, to: &card)
        parsePersonalInfo(from: remaining, into: &card, language: language)

        card.name = normalizedStoredName(card.name)
        card.fax = ""
        card.address = ""
        return card
    }

    private func extractEmail(from lines: [ParsedBusinessCardLine]) -> (value: String, index: Int)? {
        let pattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for (index, line) in lines.enumerated() {
            for text in line.textsForParsing {
                let normalizedLine = normalizeEmailCandidate(text)
                let range = NSRange(normalizedLine.startIndex..., in: normalizedLine)
                if let match = regex.firstMatch(in: normalizedLine, range: range),
                   let swiftRange = Range(match.range, in: normalizedLine) {
                    return (String(normalizedLine[swiftRange]), index)
                }
            }
        }
        return nil
    }

    private func extractWebsite(from lines: [ParsedBusinessCardLine]) -> (value: String, index: Int)? {
        let pattern = #"(?:https://|www\.)[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%\-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let labeledPattern = #"(?i)(?:^|[\s|/])w(?:eb|ebsite)?\.?\s*[:：]?\s*([A-Za-z0-9][A-Za-z0-9.\-]+\.[A-Za-z]{2,}(?:/[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%\-]*)?)"#
        let labeledRegex = try? NSRegularExpression(pattern: labeledPattern)

        for (index, line) in lines.enumerated() {
            for text in line.textsForParsing {
                let normalizedLine = normalizeURLCandidate(text)
                let range = NSRange(normalizedLine.startIndex..., in: normalizedLine)
                if let match = regex.firstMatch(in: normalizedLine, range: range),
                   let swiftRange = Range(match.range, in: normalizedLine),
                   let website = normalizedWebsite(from: String(normalizedLine[swiftRange])) {
                    return (website, index)
                }

                let labeledRange = NSRange(text.startIndex..., in: text)
                if let match = labeledRegex?.firstMatch(in: text, range: labeledRange),
                   match.numberOfRanges > 1,
                   let swiftRange = Range(match.range(at: 1), in: text),
                   let website = normalizedWebsite(from: String(text[swiftRange]), forceHTTPS: true) {
                    return (website, index)
                }
            }
        }
        return nil
    }

    private func normalizedWebsite(from value: String, forceHTTPS: Bool = false) -> String? {
        var website = normalizeURLCandidate(value)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)]}"))
        guard !website.localizedCaseInsensitiveContains("@"),
              !isStandaloneEmailDomain(website, email: nil) else {
            return nil
        }

        if website.lowercased().hasPrefix("www.") || forceHTTPS {
            website = "https://" + website
        }
        return website
    }

    private func removeLine(at index: Int, from lines: inout [ParsedBusinessCardLine]) {
        guard lines.indices.contains(index) else { return }
        lines.remove(at: index)
    }

    private func assignPhoneNumbers(from lines: inout [ParsedBusinessCardLine], to card: inout BusinessCardDraft) {
        var mobileCandidates: [String] = []
        var officeCandidates: [String] = []
        var unlabeledCandidates: [String] = []
        var indicesToRemove: Set<Int> = []

        for (index, line) in lines.enumerated() {
            let phones = line.textsForParsing.flatMap { extractPhoneNumbers(from: $0) }
            guard !phones.isEmpty else { continue }

            for phone in phones {
                switch phone.kind {
                case .fax:
                    break
                case .mobile:
                    mobileCandidates.append(phone.number)
                case .office:
                    officeCandidates.append(phone.number)
                case .unlabeled:
                    if isMobileNumber(phone.number) {
                        mobileCandidates.append(phone.number)
                    } else {
                        unlabeledCandidates.append(phone.number)
                    }
                }
            }
            indicesToRemove.insert(index)
        }

        if card.phone.isEmpty {
            card.phone = uniquePhoneNumbers(mobileCandidates + unlabeledCandidates).first ?? ""
        }

        if card.officePhone.isEmpty {
            let remainingUnlabeled = uniquePhoneNumbers(unlabeledCandidates).filter { $0 != card.phone }
            card.officePhone = uniquePhoneNumbers(officeCandidates + remainingUnlabeled).first ?? ""
        }

        for index in indicesToRemove.sorted(by: >) {
            lines.remove(at: index)
        }
    }

    private func extractPhoneNumbers(from line: String) -> [LabeledPhoneNumber] {
        let normalizedLine = normalizePhoneCandidate(line.replacingOccurrences(of: "：", with: ":"))
        let phonePattern = #"(?:\+\s*\d[\d\s\-]{6,}\d|0\d[\d\s\-]{6,}\d)"#
        guard let regex = try? NSRegularExpression(pattern: phonePattern) else { return [] }

        let nsRange = NSRange(normalizedLine.startIndex..., in: normalizedLine)
        let matches = regex.matches(in: normalizedLine, range: nsRange)
        return matches.compactMap { match in
            guard let phoneRange = Range(match.range, in: normalizedLine) else { return nil }
            let number = String(normalizedLine[phoneRange])
                .replacingOccurrences(of: #"[\s]+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let labelContext = phoneLabelContext(
                in: line.replacingOccurrences(of: "：", with: ":"),
                beforeOffset: normalizedLine.distance(from: normalizedLine.startIndex, to: phoneRange.lowerBound)
            )
            let kind: PhoneNumberKind

            if hasFaxLabel(labelContext) {
                kind = .fax
            } else if hasMobileLabel(labelContext) || isMobileNumber(number) {
                kind = .mobile
            } else if hasOfficeLabel(labelContext) {
                kind = .office
            } else {
                kind = .unlabeled
            }
            return LabeledPhoneNumber(kind: kind, number: number)
        }
    }

    private func phoneLabelContext(in line: String, before index: String.Index) -> String {
        let prefixDistance = line.distance(from: line.startIndex, to: index)
        let prefixStart = line.index(line.startIndex, offsetBy: max(0, prefixDistance - 24))
        return String(line[prefixStart..<index])
    }

    private func phoneLabelContext(in line: String, beforeOffset offset: Int) -> String {
        let safeOffset = min(max(offset, 0), line.count)
        let index = line.index(line.startIndex, offsetBy: safeOffset)
        return phoneLabelContext(in: line, before: index)
    }

    private func parsePersonalInfo(
        from lines: [ParsedBusinessCardLine],
        into card: inout BusinessCardDraft,
        language: String
    ) {
        var remaining = lines.filter { line in
            !line.textsForParsing.contains(where: isContactLine)
        }

        parseSplitTitleAndDepartment(from: remaining, into: &card, language: language)

        if card.jobTitle.isEmpty, let title = bestTitleLine(from: remaining, language: language) {
            card.jobTitle = title.value
        }

        if card.name.isEmpty, let name = bestNameLine(from: remaining, title: card.jobTitle, email: card.email, language: language) {
            card.name = name
        }

        if card.department.isEmpty, let department = bestDepartmentLine(from: remaining, language: language) {
            card.department = department.value
        }

        if card.company.isEmpty, let company = bestCompanyLine(from: remaining) {
            card.company = company.value
        }

        removePersonalInfoValues([card.name, card.jobTitle, card.department, card.company], from: &remaining)
        let memoLines = remaining
            .map(\.text)
            .filter { !looksLikeAddressLine($0) && !looksLikeWebsiteLine($0) }
        card.memo = memoLines.joined(separator: "\n")
    }

    private func parseSplitTitleAndDepartment(
        from lines: [ParsedBusinessCardLine],
        into card: inout BusinessCardDraft,
        language: String
    ) {
        guard card.jobTitle.isEmpty || card.department.isEmpty else { return }

        for line in lines where !isExcludedPersonalCandidate(line, allowCompany: false) {
            for text in line.textsForParsing where text.contains("/") || text.contains("|") {
                let parts = text
                    .split(whereSeparator: { $0 == "/" || $0 == "|" })
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard parts.count == 2 else { continue }

                let firstScore = titleTextScore(parts[0], language: language)
                let secondScore = titleTextScore(parts[1], language: language)
                let titlePart: String
                let departmentPart: String

                if firstScore != secondScore {
                    titlePart = firstScore > secondScore ? parts[0] : parts[1]
                    departmentPart = firstScore > secondScore ? parts[1] : parts[0]
                } else {
                    let firstWords = wordCount(parts[0])
                    let secondWords = wordCount(parts[1])
                    if firstWords != secondWords {
                        titlePart = firstWords < secondWords ? parts[0] : parts[1]
                        departmentPart = firstWords < secondWords ? parts[1] : parts[0]
                    } else {
                        titlePart = parts[0].count <= parts[1].count ? parts[0] : parts[1]
                        departmentPart = parts[0].count <= parts[1].count ? parts[1] : parts[0]
                    }
                }

                if card.jobTitle.isEmpty {
                    card.jobTitle = titlePart
                }
                if card.department.isEmpty {
                    card.department = departmentPart
                }
                return
            }
        }
    }

    private func bestTitleLine(from lines: [ParsedBusinessCardLine], language: String) -> (value: String, line: ParsedBusinessCardLine)? {
        lines.compactMap { line -> (String, ParsedBusinessCardLine, Double)? in
            guard !isExcludedPersonalCandidate(line, allowCompany: false) else { return nil }
            let scoredTexts = line.textsForParsing.map { ($0, titleTextScore($0, language: language)) }
            guard let best = scoredTexts.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
            return (best.0, line, best.1 + positionScore(line))
        }
        .max(by: { $0.2 < $1.2 })
        .map { ($0.0, $0.1) }
    }

    private func bestNameLine(
        from lines: [ParsedBusinessCardLine],
        title: String,
        email: String,
        language: String
    ) -> String? {
        let titleLine = lines.first { line in
            line.textsForParsing.contains { $0.caseInsensitiveCompare(title) == .orderedSame }
        } ?? bestTitleLine(from: lines, language: language)?.line

        return lines.compactMap { line -> (String, Double)? in
            guard !isExcludedPersonalCandidate(line, allowCompany: false) else { return nil }
            let scoredTexts = line.textsForParsing.map { text in
                (text, nameTextScore(text, email: email) + adjacencyScore(line, titleLine: titleLine))
            }
            guard let best = scoredTexts.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
            return best
        }
        .max(by: { $0.1 < $1.1 })?
        .0
    }

    private func bestDepartmentLine(from lines: [ParsedBusinessCardLine], language: String) -> (value: String, line: ParsedBusinessCardLine)? {
        lines.compactMap { line -> (String, ParsedBusinessCardLine, Double)? in
            guard !isExcludedPersonalCandidate(line, allowCompany: false) else { return nil }
            let scoredTexts = line.textsForParsing.map { ($0, departmentTextScore($0)) }
            guard let best = scoredTexts.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
            guard titleTextScore(best.0, language: language) <= best.1 else { return nil }
            return (best.0, line, best.1 + positionScore(line))
        }
        .max(by: { $0.2 < $1.2 })
        .map { ($0.0, $0.1) }
    }

    private func bestCompanyLine(from lines: [ParsedBusinessCardLine]) -> (value: String, line: ParsedBusinessCardLine)? {
        lines.compactMap { line -> (String, ParsedBusinessCardLine, Double)? in
            guard !line.textsForParsing.contains(where: looksLikeAddressLine),
                  !line.textsForParsing.contains(where: isContactLine) else {
                return nil
            }
            let scoredTexts = line.textsForParsing.map { ($0, companyTextScore($0, line: line)) }
            guard let best = scoredTexts.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
            return (best.0, line, best.1)
        }
        .max(by: { $0.2 < $1.2 })
        .map { ($0.0, $0.1) }
    }

    private func removePersonalInfoValues(_ values: [String], from lines: inout [ParsedBusinessCardLine]) {
        let normalizedValues = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        lines.removeAll { line in
            line.textsForParsing.contains {
                normalizedValues.contains($0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        }
    }

    private func titleTextScore(_ text: String, language: String) -> Double {
        guard !looksLikeAddressLine(text), !isContactLine(text), !looksLikeWebsiteLine(text), !isCompanyLine(text) else {
            return 0
        }

        var score = 0.0
        let keywords = titleKeywords(for: language)
        for keyword in keywords where text.localizedCaseInsensitiveContains(keyword) {
            score += keyword.count <= 2 ? 1.8 : 2.2
        }
        if wordCount(text) <= 4 {
            score += 0.35
        }
        if text.count <= 24 {
            score += 0.25
        }
        return score
    }

    private func departmentTextScore(_ text: String) -> Double {
        guard !looksLikeAddressLine(text), !isContactLine(text), !looksLikeWebsiteLine(text), !isCompanyLine(text) else {
            return 0
        }

        var score = 0.0
        for keyword in departmentKeywords where text.localizedCaseInsensitiveContains(keyword) {
            score += 1.8
        }
        if wordCount(text) <= 6 {
            score += 0.2
        }
        return score
    }

    private func companyTextScore(_ text: String, line: ParsedBusinessCardLine) -> Double {
        guard !looksLikeAddressLine(text), !isContactLine(text), !looksLikeWebsiteLine(text) else {
            return 0
        }

        var score = 0.0
        for keyword in companyKeywords where text.localizedCaseInsensitiveContains(keyword) {
            score += 2.2
        }
        guard score > 0 else { return 0 }

        score += min(Double(text.count) * 0.025, 0.45)
        score += min(line.height * 2.2, 0.45)
        score += line.midY > 0.55 ? 0.25 : 0
        score += Double(line.confidence) * 0.25
        return score
    }

    private func nameTextScore(_ text: String, email: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !isCompanyLine(trimmed),
              !isDepartmentLine(trimmed),
              titleTextScore(trimmed, language: "ko") == 0,
              !looksLikeAddressLine(trimmed),
              !isContactLine(trimmed),
              !looksLikeWebsiteLine(trimmed) else {
            return 0
        }

        var score = 0.0
        if looksLikeSpacedKoreanName(trimmed) {
            score += 4.0
        }
        if trimmed.range(of: #"^[가-힣]{2,5}$"#, options: .regularExpression) != nil {
            score += 2.2
        }
        if trimmed.range(of: #"^[A-Z][A-Za-z]+(\s+[A-Z][A-Za-z]+){0,3}$"#, options: .regularExpression) != nil,
           trimmed.count <= 32 {
            score += 1.7
        }
        if trimmed.range(of: #"^[一-鿿]{2,4}$"#, options: .regularExpression) != nil {
            score += 1.5
        }
        if emailLocalPart(email).contains(normalizedNameForComparison(trimmed)) {
            score += 0.7
        }
        if trimmed.count <= 12 {
            score += 0.35
        }
        return score
    }

    private func adjacencyScore(_ line: ParsedBusinessCardLine, titleLine: ParsedBusinessCardLine?) -> Double {
        guard let titleLine else { return 0 }

        if line.sourceIndex == titleLine.sourceIndex - 1 {
            return 2.4
        }
        if line.isPositioned && titleLine.isPositioned {
            let sameVisualLine = abs(line.midY - titleLine.midY) < max(line.height, titleLine.height) * 0.8
            if sameVisualLine && line.maxX <= titleLine.minX + 0.03 {
                return 2.2
            }
            let directlyAbove = line.midY > titleLine.midY &&
                abs(line.midX - titleLine.midX) < 0.25 &&
                abs(line.midY - titleLine.midY) < 0.16
            if directlyAbove {
                return 1.8
            }
        }
        return 0
    }

    private func positionScore(_ line: ParsedBusinessCardLine) -> Double {
        Double(line.confidence) * 0.25 + min(line.height * 1.4, 0.3)
    }

    private func isExcludedPersonalCandidate(_ line: ParsedBusinessCardLine, allowCompany: Bool) -> Bool {
        let texts = line.textsForParsing
        if texts.contains(where: isContactLine) {
            return false
        }
        if texts.contains(where: looksLikeWebsiteLine) || texts.contains(where: looksLikeAddressLine) {
            return true
        }
        if !allowCompany && isLikelyTopLeftLogo(line) {
            return true
        }
        return false
    }

    private func isLikelyTopLeftLogo(_ line: ParsedBusinessCardLine) -> Bool {
        guard line.isPositioned else { return false }
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return line.minX < 0.22 &&
            line.midY > 0.68 &&
            (line.height > 0.055 || text.count <= 5)
    }

    private func isContactLine(_ line: String) -> Bool {
        extractPhoneNumbers(from: line).isEmpty == false ||
            normalizeEmailCandidate(line).contains("@") ||
            looksLikeWebsiteLine(line)
    }

    private func looksLikeWebsiteLine(_ line: String) -> Bool {
        let normalized = normalizeURLCandidate(line).lowercased()
        return normalized.hasPrefix("www.") ||
            normalized.hasPrefix("https://") ||
            normalized.contains(" www.") ||
            normalized.contains(" https://") ||
            line.range(
                of: #"(?i)(?:^|[\s|/])w(?:eb|ebsite)?\.?\s*[:：]?\s*[A-Za-z0-9][A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
                options: .regularExpression
            ) != nil
    }

    private func looksLikeAddressLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 6 else { return false }
        let keywords = [
            "서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종", "경기", "강원",
            "충청", "전라", "경상", "제주", "로", "길", "번지", "층", "호",
            "address", "addr.", "suite", "street", "st.", "road", "rd.", "avenue", "ave."
        ]
        let hasAddressKeyword = keywords.contains { trimmed.localizedCaseInsensitiveContains($0) }
        let hasPostalPattern = trimmed.range(of: #"\b\d{3}-?\d{3}\b"#, options: .regularExpression) != nil
        return hasAddressKeyword && (trimmed.count >= 10 || hasPostalPattern)
    }

    private func isCompanyLine(_ line: String) -> Bool {
        companyKeywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    private func isDepartmentLine(_ line: String) -> Bool {
        departmentKeywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    private func hasFaxLabel(_ line: String) -> Bool {
        containsAny(line, keywords: [
            "fax", "facsimile", "팩스", "f.", "f:"
        ])
    }

    private func hasMobileLabel(_ line: String) -> Bool {
        containsAny(line, keywords: [
            "mobile", "cell", "cellphone", "cell phone", "mob", "m.", "m:", "h/p", "hp",
            "휴대폰", "핸드폰", "모바일", "휴대전화"
        ])
    }

    private func hasOfficeLabel(_ line: String) -> Bool {
        containsAny(line, keywords: [
            "tel", "telephone", "phone", "office", "direct", "work", "t.", "t:",
            "대표", "대표전화", "전화", "사무실", "회사전화", "직통"
        ])
    }

    private func containsAny(_ line: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            line.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func normalizeEmailCandidate(_ text: String) -> String {
        var normalized = text
            .replacingOccurrences(of: "＠", with: "@")
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "ㆍ", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: ".c0m", with: ".com", options: .caseInsensitive)
            .replacingOccurrences(of: ".cOm", with: ".com", options: .caseInsensitive)
            .replacingOccurrences(of: ".co.kr", with: ".co.kr", options: .caseInsensitive)

        normalized = normalized.replacingOccurrences(
            of: #"(?i)^\s*(?:e-mail|email|mail|e|이메일)\s*[:：.\-]?\s*"#,
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)\s+at\s+"#,
            with: "@",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)\s+dot\s+"#,
            with: ".",
            options: .regularExpression
        )
        return normalized.replacingOccurrences(of: " ", with: "")
    }

    private func normalizeURLCandidate(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "wvvw", with: "www", options: .caseInsensitive)
            .replacingOccurrences(of: "vvww", with: "www", options: .caseInsensitive)
            .replacingOccurrences(of: ".c0m", with: ".com", options: .caseInsensitive)
            .replacingOccurrences(of: ".cOm", with: ".com", options: .caseInsensitive)
            .replacingOccurrences(of: "www,", with: "www.", options: .caseInsensitive)
    }

    private func normalizePhoneCandidate(_ text: String) -> String {
        text
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "l", with: "1")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "s", with: "5")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }

    private func isMobileNumber(_ phone: String) -> Bool {
        let normalized = phone
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        return normalized.hasPrefix("010") || normalized.hasPrefix("+8210") || normalized.hasPrefix("+82010")
    }

    private func uniquePhoneNumbers(_ phones: [String]) -> [String] {
        phones.reduce(into: [String]()) { result, phone in
            let comparable = phone.replacingOccurrences(of: #"[\s\-]"#, with: "", options: .regularExpression)
            if !result.contains(where: { $0.replacingOccurrences(of: #"[\s\-]"#, with: "", options: .regularExpression) == comparable }) {
                result.append(phone)
            }
        }
    }

    private func isStandaloneEmailDomain(_ website: String, email: String?) -> Bool {
        guard let email, let domain = email.split(separator: "@").last else { return false }
        return website.caseInsensitiveCompare(String(domain)) == .orderedSame
    }

    private func wordCount(_ text: String) -> Int {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == "|" })
        return max(words.count, 1)
    }

    private func looksLikeSpacedKoreanName(_ text: String) -> Bool {
        text.range(of: #"^[가-힣]\s+[가-힣]\s+[가-힣]$"#, options: .regularExpression) != nil ||
            text.range(of: #"^[가-힣]\s+[가-힣]{2}$"#, options: .regularExpression) != nil
    }

    private func normalizedStoredName(_ text: String) -> String {
        if looksLikeSpacedKoreanName(text) {
            return text.replacingOccurrences(of: " ", with: "")
        }
        return text
    }

    private func normalizedNameForComparison(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    private func emailLocalPart(_ email: String) -> String {
        email.split(separator: "@").first.map { String($0).lowercased() } ?? ""
    }

    private func titleKeywords(for language: String) -> [String] {
        var keywords = titleKeywordsEN
        if language == "ko" { keywords += titleKeywordsKO }
        if language == "zh" { keywords += titleKeywordsZH }
        return keywords
    }

    private var titleKeywordsKO: [String] {
        [
            "대표", "이사", "부장", "과장", "차장", "팀장", "대리", "주임", "사원",
            "사장", "회장", "본부장", "실장", "선임", "책임", "수석", "연구원",
            "매니저"
        ]
    }

    private var titleKeywordsEN: [String] {
        [
            "CEO", "Director", "Manager", "President", "VP", "Senior", "Lead",
            "Engineer", "Consultant", "Analyst", "Officer", "Head", "Chief",
            "Chairman", "Chair"
        ]
    }

    private var titleKeywordsZH: [String] {
        ["总经理", "经理", "主任", "部长", "总监", "董事长", "副总"]
    }

    private var companyKeywords: [String] {
        [
            "주식회사", "유한회사", "협회", "(주)", "㈜", "|주|", "Inc.", "Inc",
            "Corp.", "Corporation", "Ltd.", "LTD", "LLC", "Co.,,", "Co.,",
            "Co.", "Company", "Group", "GmbH", "株式会社", "有限公司", "股份公司"
        ]
    }

    private var departmentKeywords: [String] {
        [
            "팀", "부", "본부", "실", "센터", "연구소", "사업부", "부문", "지사",
            "Department", "Division", "Team", "Dept", "Group", "Lab"
        ]
    }
}
