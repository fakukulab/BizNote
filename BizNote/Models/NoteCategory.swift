import Foundation
import SwiftUI

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case workLog        = "work_log"
    case meetingMinutes = "meeting_minutes"
    case exhibition     = "exhibition"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .workLog:        return String(localized: "category.workLog")
        case .meetingMinutes: return String(localized: "category.meetingMinutes")
        case .exhibition:     return String(localized: "category.exhibition")
        }
    }

    var systemIconName: String {
        switch self {
        case .workLog:        return "briefcase.fill"
        case .meetingMinutes: return "person.2.fill"
        case .exhibition:     return "building.columns.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .workLog:        return Color(red: 0.145, green: 0.388, blue: 0.922)
        case .meetingMinutes: return Color(red: 0.020, green: 0.588, blue: 0.412)
        case .exhibition:     return Color(red: 0.851, green: 0.467, blue: 0.024)
        }
    }
}
