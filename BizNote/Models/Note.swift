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

    /// The date shown in note lists — the date recorded inside the note's own
    /// template content (work log date, meeting date, exhibition date) rather
    /// than the note's last-modified timestamp, so it stays in sync whenever
    /// that in-note date is edited.
    var contentDate: Date {
        if isCustomCategory {
            return customTemplateDate ?? updatedAt
        }

        switch category {
        case .workLog:
            return TemplateCoder.decode(WorkLogTemplateData.self, from: templateData)?.date ?? updatedAt
        case .meetingMinutes:
            return TemplateCoder.decode(MeetingMinutesTemplateData.self, from: templateData)?.meetingDate ?? updatedAt
        case .exhibition:
            return TemplateCoder.decode(ExhibitionTemplateData.self, from: templateData)?.participatingDate ?? updatedAt
        }
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
