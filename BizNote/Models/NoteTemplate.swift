import Foundation

struct WorkLogTemplateData: Codable, Equatable {
    var date: Date = Date()
    var workItems: [WorkItem] = []
    var achievements: String = ""
    var issues: String = ""
    var nextTodos: String = ""

    struct WorkItem: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var task: String = ""
        var status: TaskStatus = .inProgress
        var duration: Double = 0

        enum TaskStatus: String, Codable, CaseIterable, Identifiable {
            case todo = "todo"
            case inProgress = "in_progress"
            case done = "done"

            var id: String { rawValue }

            var localizedName: String {
                switch self {
                case .todo:       return String(localized: "task.status.todo")
                case .inProgress: return String(localized: "task.status.inProgress")
                case .done:       return String(localized: "task.status.done")
                }
            }
        }
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case date, workItems, achievements, issues, nextTodos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date         = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        workItems    = (try? c.decode([WorkItem].self, forKey: .workItems)) ?? []
        achievements = (try? c.decode(String.self, forKey: .achievements)) ?? ""
        issues       = (try? c.decode(String.self, forKey: .issues)) ?? ""
        nextTodos    = (try? c.decode(String.self, forKey: .nextTodos)) ?? ""
    }
}

struct MeetingMinutesTemplateData: Codable, Equatable {
    var meetingDate: Date = Date()
    var location: String = ""
    var participants: [String] = []
    var agenda: String = ""
    var discussionPoints: [String] = []
    var decisions: [String] = []
    var actionItems: [ActionItem] = []

    struct ActionItem: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var task: String = ""
        var assignee: String = ""
        var dueDate: Date = Date()
        var isCompleted: Bool = false
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case meetingDate, location, participants, agenda,
             discussionPoints, decisions, actionItems
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meetingDate      = (try? c.decode(Date.self, forKey: .meetingDate)) ?? Date()
        location         = (try? c.decode(String.self, forKey: .location)) ?? ""
        participants     = (try? c.decode([String].self, forKey: .participants)) ?? []
        agenda           = (try? c.decode(String.self, forKey: .agenda)) ?? ""
        discussionPoints = (try? c.decode([String].self, forKey: .discussionPoints)) ?? []
        decisions        = (try? c.decode([String].self, forKey: .decisions)) ?? []
        actionItems      = (try? c.decode([ActionItem].self, forKey: .actionItems)) ?? []
    }
}

struct ExhibitionTemplateData: Codable, Equatable {
    var exhibitionName: String = ""
    var participatingDate: Date = Date()
    var venue: String = ""
    var organizer: String = ""
    var participationType: ParticipationType = .visitor
    var visitedBooths: [VisitedBooth] = []
    var contacts: [Contact] = []
    var tasks: [TaskItem] = []
    var presetID: UUID? = nil

    enum ParticipationType: String, Codable, CaseIterable, Identifiable {
        case visitor  = "visitor"
        case exhibitor = "exhibitor"

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .visitor:  return String(localized: "template.exhibition.type.visitor")
            case .exhibitor: return String(localized: "template.exhibition.type.exhibitor")
            }
        }
    }

    struct VisitedBooth: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var boothNumber: String = ""
        var companyName: String = ""
        var contactPerson: String = ""
        var contactPhone: String = ""
        var contactEmail: String = ""
        var productsServices: String = ""
        var interestLevel: Int = 3
        var notes: String = ""
        var linkedCardID: UUID? = nil
    }

    struct Contact: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var country: String = ""
        var name: String = ""
        var company: String = ""
        var jobTitle: String = ""
        var email: String = ""
        var phone: String = ""
        var memo: String = ""
        var linkedCardID: UUID? = nil
    }

    struct TaskItem: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var title: String = ""
        var category: TaskCategory = .followUp
        var dueDate: Date = Date()
        var isCompleted: Bool = false

        enum TaskCategory: String, Codable, CaseIterable, Identifiable {
            case call     = "call"
            case email    = "email"
            case followUp = "follow_up"
            case meeting  = "meeting"

            var id: String { rawValue }

            var localizedName: String {
                switch self {
                case .call:     return String(localized: "task.category.call")
                case .email:    return String(localized: "task.category.email")
                case .followUp: return String(localized: "task.category.followUp")
                case .meeting:  return String(localized: "task.category.meeting")
                }
            }

            var systemImage: String {
                switch self {
                case .call:     return "phone.fill"
                case .email:    return "envelope.fill"
                case .followUp: return "arrow.triangle.2.circlepath"
                case .meeting:  return "person.2.fill"
                }
            }
        }
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case exhibitionName, participatingDate, venue, organizer,
             participationType, visitedBooths, contacts, tasks, presetID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exhibitionName    = (try? c.decode(String.self, forKey: .exhibitionName)) ?? ""
        participatingDate = (try? c.decode(Date.self, forKey: .participatingDate)) ?? Date()
        venue             = (try? c.decode(String.self, forKey: .venue)) ?? ""
        organizer         = (try? c.decode(String.self, forKey: .organizer)) ?? ""
        participationType = (try? c.decode(ParticipationType.self, forKey: .participationType)) ?? .visitor
        visitedBooths     = (try? c.decode([VisitedBooth].self, forKey: .visitedBooths)) ?? []
        contacts          = (try? c.decode([Contact].self, forKey: .contacts)) ?? []
        tasks             = (try? c.decode([TaskItem].self, forKey: .tasks)) ?? []
        presetID          = try? c.decodeIfPresent(UUID.self, forKey: .presetID)
    }
}

enum TemplateCoder {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func encode<T: Codable>(_ value: T) -> String {
        (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func decode<T: Codable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
