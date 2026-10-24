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
            .flatMap { candidate in
                [candidate] + candidate
                    .split(whereSeparator: { "|•·".contains($0) })
                    .map(String.init)
            }
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
            card.fieldConfidence["email"] = Double(remaining[extraction.index].confidence)
            removeLine(at: extraction.index, from: &remaining)
        }

        if let extraction = extractWebsite(from: remaining) {
            card.website = extraction.value
            card.fieldConfidence["website"] = Double(remaining[extraction.index].confidence)
            removeLine(at: extraction.index, from: &remaining)
        }

        assignPhoneNumbers(from: &remaining, to: &card)
        if let address = extractAddress(from: remaining) {
            card.address = address
        }
        parsePersonalInfo(from: remaining, into: &card, language: language)
        inferCompanyFromDomainIfNeeded(card: &card)

        card.name = normalizedStoredName(card.name)
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
                    return (correctedEmail(String(normalizedLine[swiftRange])), index)
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

        website = correctedURLDomain(website)
        if website.lowercased().hasPrefix("www.") || forceHTTPS {
            website = "https://" + website
        }
        return website
    }

    private func extractAddress(from lines: [ParsedBusinessCardLine]) -> String? {
        var addressLines: [String] = []
        for line in lines {
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if looksLikeAddressLine(text) {
                addressLines.append(text)
            } else if !addressLines.isEmpty,
                      addressLines.count < 3,
                      text.range(of: #"(?i)^(?:\d{3,6}|[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}|[A-Z]\d[A-Z]\s?\d[A-Z]\d)|(?:\d+F|\d+층|\d+호|Suite|Ste\.?|#)"#, options: .regularExpression) != nil {
                addressLines.append(text)
            }
        }

        guard !addressLines.isEmpty else { return nil }
        return addressLines.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeLine(at index: Int, from lines: inout [ParsedBusinessCardLine]) {
        guard lines.indices.contains(index) else { return }
        lines.remove(at: index)
    }

    private func assignPhoneNumbers(from lines: inout [ParsedBusinessCardLine], to card: inout BusinessCardDraft) {
        var mobileCandidates: [(number: String, confidence: Float)] = []
        var officeCandidates: [(number: String, confidence: Float)] = []
        var unlabeledCandidates: [(number: String, confidence: Float)] = []
        var indicesToRemove: Set<Int> = []

        for (index, line) in lines.enumerated() {
            let phones = line.textsForParsing.flatMap { extractPhoneNumbers(from: $0) }
            guard !phones.isEmpty else { continue }

            for phone in phones {
                switch phone.kind {
                case .fax:
                    continue
                case .mobile:
                    mobileCandidates.append((phone.number, line.confidence))
                case .office:
                    officeCandidates.append((phone.number, line.confidence))
                case .unlabeled:
                    if isMobileNumber(phone.number) {
                        mobileCandidates.append((phone.number, line.confidence))
                    } else {
                        unlabeledCandidates.append((phone.number, line.confidence))
                    }
                }
            }
            indicesToRemove.insert(index)
        }

        if card.phone.isEmpty, let best = uniquePhoneCandidates(mobileCandidates + unlabeledCandidates).first {
            card.phone = best.number
            card.fieldConfidence["phone"] = Double(best.confidence)
        }

        if card.officePhone.isEmpty {
            let remainingUnlabeled = uniquePhoneCandidates(unlabeledCandidates).filter { $0.number != card.phone }
            if let best = uniquePhoneCandidates(officeCandidates + remainingUnlabeled).first {
                card.officePhone = best.number
                card.fieldConfidence["officePhone"] = Double(best.confidence)
            }
        }

        for index in indicesToRemove.sorted(by: >) {
            lines.remove(at: index)
        }
    }

    private func extractPhoneNumbers(from line: String) -> [LabeledPhoneNumber] {
        let originalLine = line.replacingOccurrences(of: "：", with: ":")
        let normalizedLine = normalizePhoneCandidate(originalLine)
        let patterns = [
            #"(?:\+82[-\s]?)?0?1[016789][-\s)]?\d{3,4}[-\s]?\d{4}(?:\s*(?:내선|ext\.?|x)\s*\d{1,5})?"#,
            #"(?:\+82[-\s]?)?0?(?:2|3[1-3]|4[1-4]|5[1-5]|6[1-4]|70|50\d|80)[-\s)]?\d{3,4}[-\s]?\d{4}(?:\s*(?:내선|ext\.?|x)\s*\d{1,5})?"#,
            #"1[568]\d{2}[-\s]?\d{4}"#,
            #"(?:\+?1[-\s]?)?\(?[2-9]\d{2}\)?[-\s]?\d{3}[-\s]?\d{4}(?:\s*(?:x|ext\.?)\s*\d{1,5})?"#,
            #"\+\d{1,3}[\s-]?(?:\(0\)[\s-]?)?\d[\d\s-]{6,14}\d(?:\s*(?:x|ext\.?)\s*\d{1,5})?"#
        ]

        var results: [LabeledPhoneNumber] = []
        var seenRanges: [NSRange] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let nsRange = NSRange(normalizedLine.startIndex..., in: normalizedLine)
            for match in regex.matches(in: normalizedLine, range: nsRange) {
                guard !seenRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                      let phoneRange = Range(match.range, in: normalizedLine) else { continue }
                seenRanges.append(match.range)

                let rawNumber = String(normalizedLine[phoneRange])
                let number = normalizedPhoneNumber(rawNumber)
                guard !number.isEmpty else { continue }
                let labelContext = phoneLabelContext(
                    in: originalLine,
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
                results.append(LabeledPhoneNumber(kind: kind, number: number))
            }
        }
        return results
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

        parseBilingualName(from: remaining, into: &card)
        parseAttachedNameAndTitle(from: remaining, into: &card, language: language)
        parseSplitTitleAndDepartment(from: remaining, into: &card, language: language)

        if card.jobTitle.isEmpty, let title = bestTitleLine(from: remaining, language: language) {
            card.jobTitle = title.value
            card.fieldConfidence["jobTitle"] = Double(title.line.confidence)
        }

        if card.name.isEmpty, let name = bestNameLine(from: remaining, title: card.jobTitle, email: card.email, language: language) {
            card.name = name.value
            card.fieldConfidence["name"] = Double(name.confidence)
        }

        if card.department.isEmpty, let department = bestDepartmentLine(from: remaining, language: language) {
            card.department = department.value
            card.fieldConfidence["department"] = Double(department.line.confidence)
        }

        if card.company.isEmpty, let company = bestCompanyLine(from: remaining) {
            card.company = company.value
            card.fieldConfidence["company"] = Double(company.line.confidence)
        }

        removePersonalInfoValues([card.name, card.jobTitle, card.department, card.company], from: &remaining)
        let memoLines = remaining
            .map(\.text)
            .filter { !looksLikeAddressLine($0) && !looksLikeWebsiteLine($0) }
        card.memo = memoLines.joined(separator: "\n")
    }

    private func parseBilingualName(
        from lines: [ParsedBusinessCardLine],
        into card: inout BusinessCardDraft
    ) {
        guard card.name.isEmpty else { return }
        for line in lines where !isExcludedPersonalCandidate(line, allowCompany: false) {
            for text in [line.text] + line.candidateTexts where text.contains("|") {
                let parts = text
                    .split(separator: "|")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard parts.count == 2 else { continue }

                let koreanName = parts.first { isKoreanName($0) }
                let englishName = parts.first { isEnglishName($0) }
                if let koreanName, englishName != nil {
                    card.name = koreanName
                    return
                }
            }
        }
    }

    private func parseAttachedNameAndTitle(
        from lines: [ParsedBusinessCardLine],
        into card: inout BusinessCardDraft,
        language: String
    ) {
        guard card.name.isEmpty || card.jobTitle.isEmpty else { return }
        let titleAlternation = titleKeywords(for: language)
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        guard !titleAlternation.isEmpty else { return }

        let patterns = [
            #"^([가-힣]{2,5})\s*("# + titleAlternation + #")$"#,
            #"^("# + titleAlternation + #")\s*([가-힣]{2,5})$"#
        ]
        for line in lines where !isExcludedPersonalCandidate(line, allowCompany: false) {
            for text in line.textsForParsing {
                for (patternIndex, pattern) in patterns.enumerated() {
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                    let range = NSRange(text.startIndex..., in: text)
                    guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges == 3 else { continue }
                    let nameRangeIndex = patternIndex == 0 ? 1 : 2
                    let titleRangeIndex = patternIndex == 0 ? 2 : 1
                    if card.name.isEmpty, let nameRange = Range(match.range(at: nameRangeIndex), in: text) {
                        card.name = String(text[nameRange])
                    }
                    if card.jobTitle.isEmpty, let titleRange = Range(match.range(at: titleRangeIndex), in: text) {
                        card.jobTitle = String(text[titleRange])
                    }
                    return
                }
            }
        }
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

                if text.contains("|") && shouldPreferShortSideAsTitle(parts[0], parts[1]) {
                    titlePart = parts[0].count <= parts[1].count ? parts[0] : parts[1]
                    departmentPart = parts[0].count <= parts[1].count ? parts[1] : parts[0]
                } else if firstScore != secondScore {
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
    ) -> (value: String, confidence: Float)? {
        let titleLine = lines.first { line in
            line.textsForParsing.contains { $0.caseInsensitiveCompare(title) == .orderedSame }
        } ?? bestTitleLine(from: lines, language: language)?.line

        return lines.compactMap { line -> (String, Double, Float)? in
            guard !isExcludedPersonalCandidate(line, allowCompany: false) else { return nil }
            let scoredTexts = line.textsForParsing.map { text in
                (text, nameTextScore(text, email: email) + adjacencyScore(line, titleLine: titleLine))
            }
            guard let best = scoredTexts.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
            return (best.0, best.1, line.confidence)
        }
        .max(by: { $0.1 < $1.1 })
        .map { (value: $0.0, confidence: $0.2) }
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
        if score == 0, isLikelyLogoCompanyPlacement(line) {
            score += 1.45
        }
        guard score > 0 else { return 0 }

        score += min(Double(text.count) * 0.025, 0.45)
        score += min(line.height * 2.2, 0.45)
        score += line.midY > 0.55 ? 0.25 : 0
        score += isNearTopCorner(line) ? 0.45 : 0
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

    private func isLikelyLogoCompanyPlacement(_ line: ParsedBusinessCardLine) -> Bool {
        guard line.isPositioned else { return false }
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2,
              !isDepartmentLine(text),
              titleTextScore(text, language: "ko") == 0,
              nameTextScore(text, email: "") < 1.5 else {
            return false
        }

        let topCorner = line.midY > 0.68 && (line.minX < 0.26 || line.maxX > 0.74)
        let leftAttachedLogo = line.minX < 0.16 && line.width <= 0.5 && line.sourceIndex <= 5
        return topCorner || leftAttachedLogo
    }

    private func isNearTopCorner(_ line: ParsedBusinessCardLine) -> Bool {
        guard line.isPositioned else { return false }
        return line.midY > 0.68 && (line.minX < 0.22 || line.maxX > 0.78)
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
            "서울", "서울시", "서울특별시", "부산", "대구", "인천", "광주", "대전", "울산", "세종", "세종특별자치시",
            "경기", "경기도", "강원", "강원특별자치도", "충청", "전라", "전북특별자치도", "경상", "제주", "제주특별자치도",
            "로", "길", "번지", "층", "호", "빌딩", "타워", "센터",
            "address", "addr.", "suite", "ste.", "floor", "fl.", "street", "st.", "road", "rd.", "avenue", "ave.",
            "blvd", "drive", "dr.", "lane", "ln.", "way", "pkwy", "po box", "p.o. box"
        ]
        let hasAddressKeyword = keywords.contains { trimmed.localizedCaseInsensitiveContains($0) }
        let hasPostalPattern = trimmed.range(of: #"\b(?:\d{5}|\d{3}-\d{3}|\d{5}-\d{4}|[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}|[A-Z]\d[A-Z]\s?\d[A-Z]\d)\b"#, options: .regularExpression) != nil
        let hasUSCityStateZip = trimmed.range(of: #"[A-Za-z .'-]+,\s*[A-Z]{2}\s+\d{5}(?:-\d{4})?"#, options: .regularExpression) != nil
        return (hasAddressKeyword && trimmed.count >= 8) || hasPostalPattern || hasUSCityStateZip
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
        ]) || hasShortPhoneLabel(line, labels: ["M"])
    }

    private func hasOfficeLabel(_ line: String) -> Bool {
        containsAny(line, keywords: [
            "tel", "telephone", "phone", "office", "direct", "work", "t.", "t:",
            "대표", "대표전화", "전화", "사무실", "회사전화", "직통"
        ]) || hasShortPhoneLabel(line, labels: ["T", "Tel"])
    }

    private func containsAny(_ line: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            line.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func hasShortPhoneLabel(_ line: String, labels: [String]) -> Bool {
        labels.contains { label in
            let escaped = NSRegularExpression.escapedPattern(for: label)
            return line.range(
                of: #"(?i)(?:^|[^A-Za-z0-9가-힣])"# + escaped + #"\s*[.:：-]?\s*$"#,
                options: .regularExpression
            ) != nil
        }
    }

    private func normalizeEmailCandidate(_ text: String) -> String {
        var normalized = text
            .replacingOccurrences(of: "＠", with: "@")
            .replacingOccurrences(of: "©", with: "@")
            .replacingOccurrences(of: "®", with: "@")
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
            of: #"(?i)\s*\(?\s*at\s*\)?\s*"#,
            with: "@",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)\s*\(?\s*dot\s*\)?\s*"#,
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
            .replacingOccurrences(of: "vv", with: "w", options: .caseInsensitive)
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
            .replacingOccurrences(of: "|", with: "1")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "s", with: "5")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "Z", with: "2")
            .replacingOccurrences(of: "z", with: "2")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "·", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }

    private func normalizedPhoneNumber(_ value: String) -> String {
        var number = value
            .replacingOccurrences(of: #"(?i)\s*(?:내선|ext\.?|x)\s*\d{1,5}\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        number = number.replacingOccurrences(of: #"\((0)\)"#, with: "", options: .regularExpression)
        number = number.replacingOccurrences(of: #"(?i)^\+82[-\s]?0?"#, with: "0", options: .regularExpression)
        number = number.replacingOccurrences(of: #"(?<=\d)[\s]+(?=\d)"#, with: "-", options: .regularExpression)
        number = number.replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
        return number.trimmingCharacters(in: CharacterSet(charactersIn: " -"))
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

    private func uniquePhoneCandidates(
        _ phones: [(number: String, confidence: Float)]
    ) -> [(number: String, confidence: Float)] {
        phones.reduce(into: [(number: String, confidence: Float)]()) { result, phone in
            let comparable = phone.number.replacingOccurrences(of: #"[\s\-]"#, with: "", options: .regularExpression)
            if !result.contains(where: { $0.number.replacingOccurrences(of: #"[\s\-]"#, with: "", options: .regularExpression) == comparable }) {
                result.append(phone)
            }
        }
    }

    private func isStandaloneEmailDomain(_ website: String, email: String?) -> Bool {
        guard let email, let domain = email.split(separator: "@").last else { return false }
        return website.caseInsensitiveCompare(String(domain)) == .orderedSame
    }

    private func correctedEmail(_ value: String) -> String {
        let parts = value.lowercased().split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return value.lowercased() }
        return "\(parts[0])@\(correctedDomain(parts[1]))"
    }

    private func correctedURLDomain(_ value: String) -> String {
        guard let dotRange = value.range(of: ".", options: .backwards) else { return value }
        let prefix = String(value[..<dotRange.lowerBound])
        let suffix = String(value[dotRange.lowerBound...])
        return prefix + correctedTLD(suffix)
    }

    private func correctedDomain(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)]}"))
        if let close = domainWhitelist.min(by: { editDistance(trimmed, $0) < editDistance(trimmed, $1) }),
           editDistance(trimmed, close) <= 2 {
            return close
        }

        guard let dotRange = trimmed.range(of: ".", options: .backwards) else { return trimmed }
        let prefix = String(trimmed[..<dotRange.lowerBound])
        let suffix = String(trimmed[dotRange.lowerBound...])
        return prefix + correctedTLD(suffix)
    }

    private func correctedTLD(_ value: String) -> String {
        let lowercased = value.lowercased()
        if let close = tldWhitelist.min(by: { editDistance(lowercased, $0) < editDistance(lowercased, $1) }),
           editDistance(lowercased, close) <= 1 {
            return close
        }
        return lowercased
    }

    private func inferCompanyFromDomainIfNeeded(card: inout BusinessCardDraft) {
        guard card.company.isEmpty else { return }
        let domainSource = card.email.split(separator: "@").last.map(String.init) ?? websiteHost(card.website)
        guard let domain = domainSource?.lowercased(), !domain.isEmpty else { return }
        let base = domain
            .replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
            .split(separator: ".")
            .first
            .map(String.init) ?? ""
        guard base.count >= 3, !consumerEmailDomains.contains(domain) else { return }
        card.company = base.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    private func websiteHost(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        var text = value
        if !text.contains("://") { text = "https://\(text)" }
        return URL(string: text)?.host(percentEncoded: false)
    }

    private func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0...right.count)
        for (i, leftChar) in left.enumerated() {
            var current = [i + 1]
            for (j, rightChar) in right.enumerated() {
                current.append(min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + (leftChar == rightChar ? 0 : 1)
                ))
            }
            previous = current
        }
        return previous.last ?? max(lhs.count, rhs.count)
    }

    private func shouldPreferShortSideAsTitle(_ first: String, _ second: String) -> Bool {
        let firstDepartmentScore = departmentTextScore(first)
        let secondDepartmentScore = departmentTextScore(second)
        let firstTitleScore = titleTextScore(first, language: "ko")
        let secondTitleScore = titleTextScore(second, language: "ko")

        if firstTitleScore > 0, secondDepartmentScore > 0 { return true }
        if secondTitleScore > 0, firstDepartmentScore > 0 { return true }

        let shorter = min(first.count, second.count)
        let longer = max(first.count, second.count)
        return shorter <= 12 && longer >= shorter + 3
    }

    private func isKoreanName(_ text: String) -> Bool {
        let normalized = text.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        return normalized.range(of: #"^[가-힣]{2,4}$"#, options: .regularExpression) != nil
    }

    private func isEnglishName(_ text: String) -> Bool {
        text.range(
            of: #"^(?:[A-Z][a-z]+|[A-Z]{2,})(?:[-\s]+(?:[A-Z][a-z]+|[A-Z]{2,})){1,3}$"#,
            options: .regularExpression
        ) != nil
    }

    private func wordCount(_ text: String) -> Int {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == "|" })
        return max(words.count, 1)
    }

    private func looksLikeSpacedKoreanName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^[가-힣]+(?:\s+[가-힣]+)+$"#, options: .regularExpression) != nil else {
            return false
        }
        let compact = trimmed.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        return compact.range(of: #"^[가-힣]{2,4}$"#, options: .regularExpression) != nil
    }

    private func normalizedStoredName(_ text: String) -> String {
        if looksLikeSpacedKoreanName(text) {
            return text.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
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
            "대표이사", "대표", "회장", "사장", "부사장", "전무", "상무", "이사", "본부장", "실장",
            "팀장", "부장", "차장", "과장", "대리", "주임", "사원", "수석", "책임", "선임", "연구원",
            "프로", "매니저", "리더", "실무관", "보건복지식약관", "경제과 실무관"
        ]
    }

    private var titleKeywordsEN: [String] {
        [
            "Chief Executive Officer", "Chief Financial Officer", "Chief Technology Officer", "Chief Operating Officer", "Chief Marketing Officer",
            "CEO", "CFO", "CTO", "COO", "CMO", "President", "Vice President", "VP", "SVP", "EVP", "AVP",
            "Managing Director", "Director", "General Manager", "Manager", "Mgr", "Head of", "Head", "Lead", "Principal",
            "Partner", "Associate", "Senior", "Sr.", "Engineer", "Eng.", "Consultant", "Specialist", "Analyst",
            "Coordinator", "Founder", "Co-Founder", "Owner", "Officer", "Chairman", "Chair"
        ]
    }

    private var titleKeywordsZH: [String] {
        ["总经理", "经理", "主任", "部长", "总监", "董事长", "副总"]
    }

    private var companyKeywords: [String] {
        [
            "주식회사", "유한회사", "재단법인", "사단법인", "협회", "(주)", "㈜", "|주|", "(유)", "(추)", "㈐",
            "Inc.", "Inc", "Corp.", "Corporation", "Ltd.", "Limited", "LTD", "PLC", "LLC", "L.L.C.", "LLP", "LP",
            "Co.,,", "Co.,", "Co.", "Company", "Group", "GmbH", "AG", "S.A.", "S.L.", "B.V.", "N.V.",
            "Pty Ltd", "Pte. Ltd.", "K.K.", "株式会社", "有限公司", "股份公司",
            "주아랍에미리트 대한민국대사관", "주아랍에미리트 대사관", "한국콘텐츠진흥원", "KOTRA", "Kotra", "KOCCA"
        ]
    }

    private var departmentKeywords: [String] {
        [
            "팀", "부", "본부", "실", "센터", "연구소", "사업부", "부문", "지사", "그룹",
            "Department", "Division", "Team", "Dept", "Group", "Office of", "Lab", "Laboratory"
        ]
    }

    private var domainWhitelist: [String] {
        [
            "naver.com", "daum.net", "hanmail.net", "kakao.com", "nate.com", "gmail.com",
            "outlook.com", "hotmail.com", "icloud.com", "korea.kr"
        ]
    }

    private var consumerEmailDomains: Set<String> {
        Set(domainWhitelist + ["yahoo.com", "live.com", "me.com"])
    }

    private var tldWhitelist: [String] {
        [
            ".com", ".net", ".org", ".io", ".co", ".ai", ".edu", ".gov", ".kr", ".co.kr", ".or.kr",
            ".go.kr", ".ac.kr", ".re.kr", ".ne.kr", ".co.uk", ".com.au", ".de", ".jp", ".cn", ".sg"
        ]
    }
}
