import SwiftData
import Foundation

@Model
final class ExhibitionPreset {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var venue: String = ""
    var organizer: String = ""
    var field: String = ""
    var introduction: String = ""
    var exhibitItems: String = ""
    var supervisor: String = ""
    var contact: String = ""
    var homepage: String = ""
    var logoImagePath: String = ""
    var createdAt: Date = Date()
    var calendarEventIdentifier: String? = nil

    var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        let start = formatter.string(from: startDate)
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return start
        }
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }

    var compactDateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        let start = formatter.string(from: startDate)
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return start
        }
        return "\(start)-\(formatter.string(from: endDate))"
    }

    init(
        name: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        venue: String = "",
        organizer: String = "",
        field: String = "",
        introduction: String = "",
        exhibitItems: String = "",
        supervisor: String = "",
        contact: String = "",
        homepage: String = "",
        logoImagePath: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.venue = venue
        self.organizer = organizer
        self.field = field
        self.introduction = introduction
        self.exhibitItems = exhibitItems
        self.supervisor = supervisor
        self.contact = contact
        self.homepage = homepage
        self.logoImagePath = logoImagePath
        self.createdAt = Date()
    }
}
