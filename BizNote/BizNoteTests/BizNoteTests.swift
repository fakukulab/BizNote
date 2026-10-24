//
//  BizNoteTests.swift
//  BizNoteTests
//
//  Created by Kim Jyun on 10/8/26.
//

import Testing
import Foundation
@testable import BizNote

struct EventVisitorDraftTests {
    @Test func isValidRequiresNameAndEmailOrMobile() {
        var draft = EventVisitorDraft()
        #expect(!draft.isValid)

        draft.name = "홍길동"
        #expect(!draft.isValid)

        draft.email = "hong@example.com"
        #expect(draft.isValid)

        draft.email = ""
        draft.mobile = "010-1234-5678"
        #expect(draft.isValid)
    }

    @Test func mergingBusinessCardDraftsPrefersFirstNonEmptyValuePerField() {
        var front = BusinessCardDraft()
        front.name = "홍길동"
        front.email = "hong@example.com"
        front.imagePath = "front.jpg"

        var back = BusinessCardDraft()
        back.phone = "010-1111-2222"
        back.officePhone = "02-123-4567"
        back.memo = "뒷면 메모"

        let merged = EventVisitorDraft.merging(businessCardDrafts: [front, back], countryCode: "KR")

        #expect(merged.name == "홍길동")
        #expect(merged.email == "hong@example.com")
        #expect(merged.mobile == "010-1111-2222")
        #expect(merged.phone == "02-123-4567")
        #expect(merged.cardImagePath == "front.jpg")
        #expect(merged.countryCode == "KR")
        #expect(merged.memo == "뒷면 메모")
    }

    @Test func mergingBusinessCardDraftsCombinesMemoFromAllPages() {
        var front = BusinessCardDraft()
        front.memo = "앞면"
        var back = BusinessCardDraft()
        back.memo = "뒷면"

        let merged = EventVisitorDraft.merging(businessCardDrafts: [front, back], countryCode: "")

        #expect(merged.memo == "앞면\n뒷면")
    }
}

struct EventVisitorDuplicateTests {
    @Test func duplicateGroupsFindsVisitorsSharingEmail() {
        let first = EventVisitor()
        first.name = "A"
        first.email = "same@example.com"

        let second = EventVisitor()
        second.name = "B"
        second.email = "same@example.com"

        let unrelated = EventVisitor()
        unrelated.name = "C"
        unrelated.email = "different@example.com"

        let groups = EventVisitor.duplicateGroups(in: [first, second, unrelated])

        #expect(groups.count == 1)
        #expect(groups[0].count == 2)
        #expect(Set(groups[0].map(\.name)) == ["A", "B"])
    }

    @Test func duplicateGroupsFindsVisitorsSharingMobile() {
        let first = EventVisitor()
        first.mobile = "010-0000-0000"

        let second = EventVisitor()
        second.mobile = "010-0000-0000"

        let groups = EventVisitor.duplicateGroups(in: [first, second])

        #expect(groups.count == 1)
        #expect(groups[0].count == 2)
    }

    @Test func duplicateGroupsIgnoresVisitorsWithNoSharedContactInfo() {
        let first = EventVisitor()
        first.email = "one@example.com"
        let second = EventVisitor()
        second.email = "two@example.com"

        #expect(EventVisitor.duplicateGroups(in: [first, second]).isEmpty)
    }

    @Test func absorbFillsEmptyFieldsWithoutOverwritingExistingOnes() {
        let primary = EventVisitor()
        primary.name = "홍길동"
        primary.email = "hong@example.com"

        let other = EventVisitor()
        other.name = "다른이름"
        other.company = "비즈노트"
        other.mobile = "010-9999-8888"

        primary.absorb(other)

        #expect(primary.name == "홍길동")
        #expect(primary.email == "hong@example.com")
        #expect(primary.company == "비즈노트")
        #expect(primary.mobile == "010-9999-8888")
    }

    @Test func absorbCombinesMemoAndPrefersTrueForWantsMaterials() {
        let primary = EventVisitor()
        primary.memo = "메모1"
        primary.wantsMaterials = false

        let other = EventVisitor()
        other.memo = "메모2"
        other.wantsMaterials = true

        primary.absorb(other)

        #expect(primary.memo == "메모1\n메모2")
        #expect(primary.wantsMaterials == true)
    }

    @Test func absorbKeepsEarlierCreatedAt() {
        let earlier = Date.now.addingTimeInterval(-3600)
        let primary = EventVisitor()
        primary.createdAt = .now

        let other = EventVisitor()
        other.createdAt = earlier

        primary.absorb(other)

        #expect(primary.createdAt == earlier)
    }
}

struct EventModeOCRTests {
    @Test func recognitionLanguagesPutsPreferredLanguageFirstWithoutDuplicates() {
        let languages = EventModeOCR.recognitionLanguages(prioritizing: .japanese)

        #expect(languages.first == "ja-JP")
        #expect(languages.count == EventModeOCR.baseRecognitionLanguages.count)
        #expect(Set(languages) == Set(EventModeOCR.baseRecognitionLanguages))
    }

    @Test func recognitionLanguagesMapsKazakhToRussianModel() {
        let languages = EventModeOCR.recognitionLanguages(prioritizing: .kazakh)
        #expect(languages.first == "ru-RU")
    }
}

struct EventCountryTests {
    @Test func matchingFindsCountryByLocalizedNameOrCode() {
        let locale = Locale(identifier: "en")
        let byName = EventCountry.matching("South Korea", locale: locale)
        #expect(byName.contains { $0.code == "KR" })

        let byCode = EventCountry.matching("KR", locale: locale)
        #expect(byCode.contains { $0.code == "KR" })
    }

    @Test func matchingWithEmptyQueryPinsCommonCountriesFirst() {
        let results = EventCountry.matching("", locale: .current)
        let pinnedPrefix = results.prefix(EventCountry.pinnedCodes.count).map(\.code)
        #expect(pinnedPrefix == EventCountry.pinnedCodes)
    }
}
