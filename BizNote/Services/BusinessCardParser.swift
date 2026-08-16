import Foundation

final class BusinessCardParser {

    func parse(lines: [String], language: String = "ko") -> BusinessCardDraft {
        var card = BusinessCardDraft()
        card.scannedLanguage = language

        var remaining = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let email = extractPattern(
            #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            from: &remaining
        ) {
            card.email = email
        }

        if let website = extractPattern(
            #"(https?://|www\.)[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+"#,
            from: &remaining
        ) {
            card.website = website
        }

        if let faxLine = extractLine(
            containing: [#"(?i)fax"#, "팩스", "傳真", "传真"],
            from: &remaining
        ) {
            card.fax = extractPhoneNumber(from: faxLine) ?? faxLine
        }

        let phonePattern = #"(?:\+82[-\s]?|\+1[-\s]?|\+86[-\s]?|0)\d{1,3}[-\s]?\d{3,4}[-\s]?\d{4}"#
        let phones = extractAllPatterns(phonePattern, from: &remaining)

        var mobiles: [String] = []
        var offices: [String] = []
        for p in phones {
            let normalized = p.replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
            if normalized.hasPrefix("010") || normalized.hasPrefix("+8210") {
                mobiles.append(p)
            } else {
                offices.append(p)
            }
        }
        if mobiles.isEmpty && !offices.isEmpty {
            card.phone = offices.removeFirst()
        } else if let m = mobiles.first {
            card.phone = m
        }
        if let o = offices.first { card.officePhone = o }

        parsePersonalInfo(from: remaining, into: &card, language: language)

        return card
    }

    private func extractPattern(_ pattern: String, from lines: inout [String]) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let swiftRange = Range(match.range, in: line) {
                let result = String(line[swiftRange])
                let remainder = line.replacingCharacters(in: swiftRange, with: "")
                    .trimmingCharacters(in: .whitespaces)
                if remainder.isEmpty {
                    lines.remove(at: index)
                } else {
                    lines[index] = remainder
                }
                return result
            }
        }
        return nil
    }

    private func extractAllPatterns(_ pattern: String, from lines: inout [String]) -> [String] {
        var results: [String] = []
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return results }
        var indicesToRemove: [Int] = []
        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, range: range)
            var remainder = line
            for match in matches.reversed() {
                if let swiftRange = Range(match.range, in: line) {
                    results.append(String(line[swiftRange]))
                    if let remRange = Range(match.range, in: remainder) {
                        remainder = remainder.replacingCharacters(in: remRange, with: "")
                    }
                }
            }
            let cleaned = remainder.trimmingCharacters(in: .whitespaces)
            if cleaned.isEmpty {
                indicesToRemove.append(index)
            } else {
                lines[index] = cleaned
            }
        }
        for i in indicesToRemove.reversed() { lines.remove(at: i) }
        return results
    }

    private func extractLine(containing keywords: [String], from lines: inout [String]) -> String? {
        for (index, line) in lines.enumerated() {
            for keyword in keywords {
                if line.range(of: keyword, options: [.regularExpression, .caseInsensitive]) != nil {
                    lines.remove(at: index)
                    return line
                }
            }
        }
        return nil
    }

    private func extractPhoneNumber(from line: String) -> String? {
        let pattern = #"(?:\+\d{1,3}[-\s]?|0)\d{1,3}[-\s]?\d{3,4}[-\s]?\d{4}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        if let match = regex.firstMatch(in: line, range: range),
           let swiftRange = Range(match.range, in: line) {
            return String(line[swiftRange])
        }
        return nil
    }

    private func parsePersonalInfo(from lines: [String], into card: inout BusinessCardDraft, language: String) {
        let titleKeywords_ko = ["대표", "이사", "부장", "과장", "차장", "팀장", "대리",
                                "주임", "사원", "사장", "회장", "본부장", "실장",
                                "선임", "책임", "수석", "연구원", "매니저"]
        let titleKeywords_en = ["CEO", "Director", "Manager", "President", "VP",
                                "Senior", "Lead", "Engineer", "Consultant", "Analyst",
                                "Officer", "Head", "Chief"]
        let titleKeywords_zh = ["总经理", "经理", "主任", "部长", "总监", "董事长", "副总"]

        var titleKeywords = titleKeywords_en
        if language == "ko" { titleKeywords += titleKeywords_ko }
        if language == "zh" { titleKeywords += titleKeywords_zh }

        let companyKeywords = ["주식회사", "(주)", "㈜", "Inc.", "Inc", "Co.,", "Co.",
                              "Ltd.", "LTD", "Corp.", "Corporation", "GmbH",
                              "有限公司", "股份公司", "株式会社"]
        let deptKeywords = ["팀", "본부", "사업부", "부문", "센터", "연구소", "지사",
                           "Division", "Department", "Dept", "Group", "Lab"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if card.jobTitle.isEmpty,
               titleKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                card.jobTitle = trimmed
                continue
            }

            if card.company.isEmpty,
               companyKeywords.contains(where: { trimmed.contains($0) }) {
                card.company = trimmed
                continue
            }

            if card.department.isEmpty,
               deptKeywords.contains(where: { trimmed.contains($0) }) {
                card.department = trimmed
                continue
            }

            if card.name.isEmpty {
                let koreanNamePattern = #"^[가-힣]{2,5}$"#
                let englishNamePattern = #"^[A-Z][A-Za-z]+(\s+[A-Z][A-Za-z]+){1,3}$"#
                let chineseNamePattern = #"^[一-鿿]{2,4}$"#
                if trimmed.range(of: koreanNamePattern, options: .regularExpression) != nil ||
                   trimmed.range(of: englishNamePattern, options: .regularExpression) != nil ||
                   trimmed.range(of: chineseNamePattern, options: .regularExpression) != nil {
                    card.name = trimmed
                    continue
                }
            }

            if card.address.isEmpty && trimmed.count > 10 {
                card.address = trimmed
                continue
            }

            if !card.memo.isEmpty { card.memo += "\n" }
            card.memo += trimmed
        }
    }
}
