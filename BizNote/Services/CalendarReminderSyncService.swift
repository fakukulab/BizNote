import EventKit
import Foundation

@MainActor
final class CalendarReminderSyncService {
    static let shared = CalendarReminderSyncService()

    struct Destination: Identifiable, Equatable {
        let id: String
        let title: String
        let sourceTitle: String
    }

    private let eventStore = EKEventStore()
    private let defaults = UserDefaults.standard
    private let calendarIdentifierKey = "integration.selectedEventCalendarIdentifier"
    private let reminderListIdentifierKey = "integration.selectedReminderListIdentifier"

    private init() {}

    func eventCalendars(requestAccess: Bool) async -> [Destination] {
        guard await hasEventAccess(requestIfNeeded: requestAccess) else { return [] }
        return destinations(for: .event)
    }

    func reminderLists(requestAccess: Bool) async -> [Destination] {
        guard await hasReminderAccess(requestIfNeeded: requestAccess) else { return [] }
        return destinations(for: .reminder)
    }

    func syncEvent(for preset: ExhibitionPreset) async {
        guard defaults.bool(forKey: "integration.syncEventsWithCalendar"),
              await hasEventAccess(requestIfNeeded: true),
              let calendar = selectedCalendar(for: .event, identifierKey: calendarIdentifierKey) else { return }

        let event = preset.calendarEventIdentifier
            .flatMap { eventStore.event(withIdentifier: $0) }
            ?? EKEvent(eventStore: eventStore)

        event.calendar = calendar
        event.title = preset.name.isEmpty ? String(localized: "note.untitled") : preset.name
        event.startDate = Calendar.current.startOfDay(for: preset.startDate)
        event.endDate = allDayEndDate(for: preset.endDate)
        event.isAllDay = true
        event.location = preset.venue
        event.notes = eventNotes(for: preset)

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            preset.calendarEventIdentifier = event.eventIdentifier
        } catch {
            eventStore.reset()
        }
    }

    func removeEvent(for preset: ExhibitionPreset) async {
        guard let identifier = preset.calendarEventIdentifier,
              await hasEventAccess(requestIfNeeded: false),
              let event = eventStore.event(withIdentifier: identifier) else { return }
        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            eventStore.reset()
        }
    }

    func syncReminder(
        title: String,
        detail: String,
        assignees: [String],
        dueDate: Date,
        isCompleted: Bool,
        existingIdentifier: String?
    ) async -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              defaults.bool(forKey: "integration.syncTasksWithReminders"),
              await hasReminderAccess(requestIfNeeded: true),
              let list = selectedCalendar(for: .reminder, identifierKey: reminderListIdentifierKey) else {
            return existingIdentifier
        }

        let reminder = existingIdentifier
            .flatMap { eventStore.calendarItem(withIdentifier: $0) as? EKReminder }
            ?? EKReminder(eventStore: eventStore)

        reminder.calendar = list
        reminder.title = trimmedTitle
        reminder.notes = reminderNotes(detail: detail, assignees: assignees)
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.isCompleted = isCompleted

        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            eventStore.reset()
            return existingIdentifier
        }
    }

    private func destinations(for entityType: EKEntityType) -> [Destination] {
        let calendars = eventStore.calendars(for: entityType)
            .filter(\.allowsContentModifications)
            .filter { isICloudSource($0.source) }

        return calendars
            .sorted {
                let sourceCompare = $0.source.title.localizedStandardCompare($1.source.title)
                if sourceCompare != .orderedSame { return sourceCompare == .orderedAscending }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            .map { Destination(id: $0.calendarIdentifier, title: $0.title, sourceTitle: $0.source.title) }
    }

    private func selectedCalendar(for entityType: EKEntityType, identifierKey: String) -> EKCalendar? {
        let selectedIdentifier = defaults.string(forKey: identifierKey) ?? ""
        if !selectedIdentifier.isEmpty,
           let calendar = eventStore.calendar(withIdentifier: selectedIdentifier),
           calendar.allowsContentModifications {
            return calendar
        }

        let calendars = eventStore.calendars(for: entityType)
            .filter(\.allowsContentModifications)
            .filter { isICloudSource($0.source) }

        return calendars.first
    }

    private func hasEventAccess(requestIfNeeded: Bool) async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return true
        case .notDetermined where requestIfNeeded:
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func hasReminderAccess(requestIfNeeded: Bool) async -> Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized:
            return true
        case .notDetermined where requestIfNeeded:
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func isICloudSource(_ source: EKSource) -> Bool {
        source.sourceType == .calDAV && source.title.localizedCaseInsensitiveContains("iCloud")
    }

    private func allDayEndDate(for endDate: Date) -> Date {
        let startOfEndDate = Calendar.current.startOfDay(for: endDate)
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfEndDate) ?? startOfEndDate
    }

    private func eventNotes(for preset: ExhibitionPreset) -> String {
        [
            preset.introduction.isEmpty ? nil : "\(String(localized: "exhibitions.introduction", defaultValue: "Event Introduction")): \(preset.introduction)",
            preset.exhibitItems.isEmpty ? nil : "\(String(localized: "exhibitions.exhibitItems", defaultValue: "Exhibit Items")): \(preset.exhibitItems)",
            preset.organizer.isEmpty ? nil : "\(String(localized: "exhibitions.organizer", defaultValue: "Host")): \(preset.organizer)",
            preset.supervisor.isEmpty ? nil : "\(String(localized: "exhibitions.supervisor", defaultValue: "Organizer")): \(preset.supervisor)",
            preset.contact.isEmpty ? nil : "\(String(localized: "exhibitions.contact", defaultValue: "Contact")): \(preset.contact)",
            preset.homepage.isEmpty ? nil : "\(String(localized: "exhibitions.homepage", defaultValue: "Homepage")): \(preset.homepage)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private func reminderNotes(detail: String, assignees: [String]) -> String {
        [
            detail.isEmpty ? nil : detail,
            assignees.isEmpty ? nil : "\(String(localized: "template.taskForm.assignee", defaultValue: "담당자")): \(assignees.joined(separator: ", "))"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}
