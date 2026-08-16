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
    var createdAt: Date = Date()

    var dateRangeDescription: String {
        let start = startDate.formatted(date: .abbreviated, time: .omitted)
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return start
        }
        let end = endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) - \(end)"
    }

    init(
        name: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        venue: String = "",
        organizer: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.venue = venue
        self.organizer = organizer
        self.createdAt = Date()
    }
}
