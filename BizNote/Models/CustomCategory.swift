import SwiftData
import Foundation
import SwiftUI
import UIKit

@Model
final class CustomCategory {
    var id: UUID = UUID()
    var name: String = ""
    var systemIconName: String = "folder.fill"
    var colorRed: Double = 0.486
    var colorGreen: Double = 0.227
    var colorBlue: Double = 0.929
    var createdAt: Date = Date()
    var templateData: String = TemplateCoder.encode(CustomNoteTemplateData.defaultTemplate)

    @Relationship(deleteRule: .nullify, inverse: \Note.customCategory)
    var notes: [Note]? = []

    var accentColor: Color {
        get { Color(red: colorRed, green: colorGreen, blue: colorBlue) }
        set {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(newValue).getRed(&r, green: &g, blue: &b, alpha: &a)
            colorRed = Double(r)
            colorGreen = Double(g)
            colorBlue = Double(b)
        }
    }

    init(
        name: String = "",
        systemIconName: String = "folder.fill",
        accentColor: Color = Color(red: 0.486, green: 0.227, blue: 0.929),
        templateData: String = TemplateCoder.encode(CustomNoteTemplateData.defaultTemplate)
    ) {
        self.id = UUID()
        self.name = name
        self.systemIconName = systemIconName
        self.createdAt = Date()
        self.templateData = templateData
        self.colorRed = 0.486
        self.colorGreen = 0.227
        self.colorBlue = 0.929
        self.accentColor = accentColor
    }
}

extension CustomCategory: Hashable {
    static func == (lhs: CustomCategory, rhs: CustomCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum NoteCategorySelection: Hashable {
    case builtin(NoteCategory)
    case custom(CustomCategory)

    var localizedName: String {
        switch self {
        case .builtin(let category): return category.localizedName
        case .custom(let category):  return category.name
        }
    }

    var systemIconName: String {
        switch self {
        case .builtin(let category): return category.systemIconName
        case .custom(let category):  return category.systemIconName
        }
    }

    var accentColor: Color {
        switch self {
        case .builtin(let category): return category.accentColor
        case .custom(let category):  return category.accentColor
        }
    }
}
