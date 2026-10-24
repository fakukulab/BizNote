import SwiftData
import Foundation
import SwiftUI

@Model
final class Note {
    static let customCategoryRawValue = "custom"

    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = NoteCategory.workLog.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var content: String = ""
    var contentRTFData: String = ""
    var tags: [String] = []

    var templateData: String = "{}"

    @Relationship(deleteRule: .nullify, inverse: \BusinessCard.note)
    var businessCards: [BusinessCard]? = []

    @Relationship(deleteRule: .nullify)
    var customCategory: CustomCategory? = nil

    var attachmentPaths: [String] = []

    var isFavorite: Bool = false

    var category: NoteCategory {
        get { NoteCategory(rawValue: categoryRaw) ?? .workLog }
        set { categoryRaw = newValue.rawValue }
    }

    var isCustomCategory: Bool { categoryRaw == Note.customCategoryRawValue }

    var categorySelection: NoteCategorySelection {
        get {
            if isCustomCategory, let customCategory {
                return .custom(customCategory)
            }
            return .builtin(category)
        }
        set {
            switch newValue {
            case .builtin(let c):
                categoryRaw = c.rawValue
                customCategory = nil
            case .custom(let c):
                categoryRaw = Note.customCategoryRawValue
                customCategory = c
            }
        }
    }

    var categoryName: String { categorySelection.localizedName }
    var categoryIconName: String { categorySelection.systemIconName }
    var categoryAccentColor: Color { categorySelection.accentColor }

    /// The date recorded inside the note's own template content, used for
    /// template-aware cross references such as same-day meetings.
    var contentDate: Date {
        if isCustomCategory {
            return customTemplateDate ?? createdAt
        }

        switch category {
        case .workLog:
            guard templateDataContains("date") else { return createdAt }
            return TemplateCoder.decode(WorkLogTemplateData.self, from: templateData)?.date ?? createdAt
        case .meetingMinutes:
            guard templateDataContains("meetingDate") else { return createdAt }
            return TemplateCoder.decode(MeetingMinutesTemplateData.self, from: templateData)?.meetingDate ?? createdAt
        case .exhibition:
            guard templateDataContains("participatingDate") else { return createdAt }
            return TemplateCoder.decode(ExhibitionTemplateData.self, from: templateData)?.participatingDate ?? createdAt
        }
    }

    var listDate: Date {
        createdAt
    }

    private func templateDataContains(_ key: String) -> Bool {
        guard let data = templateData.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object[key] != nil
    }

    private var customTemplateDate: Date? {
        guard let data = TemplateCoder.decode(CustomNoteTemplateData.self, from: templateData),
              let dateText = data.sections.first(where: { $0.isEnabled && $0.kind == .date })?.text else {
            return nil
        }
        return ISO8601DateFormatter().date(from: dateText)
    }

    init(
        title: String = "",
        category: NoteCategory = .workLog,
        content: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.categoryRaw = category.rawValue
        self.content = content
        self.contentRTFData = ""
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = []
        self.templateData = "{}"
        self.businessCards = []
        self.customCategory = nil
        self.attachmentPaths = []
        self.isFavorite = false
    }

    init(title: String, customCategory: CustomCategory, content: String = "") {
        self.id = UUID()
        self.title = title
        self.categoryRaw = Note.customCategoryRawValue
        self.content = content
        self.contentRTFData = ""
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = []
        self.templateData = "{}"
        self.businessCards = []
        self.customCategory = customCategory
        self.attachmentPaths = []
        self.isFavorite = false
    }
}
