import SwiftData
import Foundation

struct BusinessCardDraft: Sendable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var scannedLanguage: String = "ko"

    var name: String = ""
    var namePhonetic: String = ""
    var company: String = ""
    var department: String = ""
    var jobTitle: String = ""
    var email: String = ""
    var phone: String = ""
    var officePhone: String = ""
    var fax: String = ""
    var address: String = ""
    var website: String = ""
    var memo: String = ""

    var imagePath: String = ""

    func makeBusinessCard() -> BusinessCard {
        let card = BusinessCard()
        card.id = id
        card.createdAt = createdAt
        card.scannedLanguage = scannedLanguage
        card.name = name
        card.namePhonetic = namePhonetic
        card.company = company
        card.department = department
        card.jobTitle = jobTitle
        card.email = email
        card.phone = phone
        card.officePhone = officePhone
        card.fax = fax
        card.address = address
        card.website = website
        card.memo = memo
        card.imagePath = imagePath
        return card
    }
}

@Model
final class BusinessCard {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var scannedLanguage: String = "ko"

    var name: String = ""
    var namePhonetic: String = ""
    var company: String = ""
    var department: String = ""
    var jobTitle: String = ""
    var email: String = ""
    var phone: String = ""
    var officePhone: String = ""
    var fax: String = ""
    var address: String = ""
    var website: String = ""
    var memo: String = ""

    var imagePath: String = ""

    var note: Note?

    init() {
        self.id = UUID()
        self.createdAt = Date()
    }
}
