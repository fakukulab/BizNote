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
        var reminderIdentifier: String? = nil

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
    var locationLatitude: Double? = nil
    var locationLongitude: Double? = nil
    var isOnlineMeeting: Bool = false
    var onlineLink: String = ""
    var participants: [Participant] = []
    var agenda: String = ""
    var discussionPoints: [String] = []
    var decisions: [String] = []
    var actionItems: [ActionItem] = []

    struct Participant: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var name: String = ""
        var company: String = ""
        var jobTitle: String = ""
        var phone: String = ""
        var email: String = ""
        var linkedCardID: UUID? = nil

        init() {}

        enum CodingKeys: String, CodingKey {
            case id, name, company, jobTitle, phone, email, linkedCardID
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
            name = (try? c.decode(String.self, forKey: .name)) ?? ""
            company = (try? c.decode(String.self, forKey: .company)) ?? ""
            jobTitle = (try? c.decode(String.self, forKey: .jobTitle)) ?? ""
            phone = (try? c.decode(String.self, forKey: .phone)) ?? ""
            email = (try? c.decode(String.self, forKey: .email)) ?? ""
            linkedCardID = try? c.decodeIfPresent(UUID.self, forKey: .linkedCardID)
        }
    }

    struct ActionItem: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var task: String = ""
        var detail: String = ""
        var category: ExhibitionTemplateData.TaskItem.TaskCategory = .call
        var assignees: [String] = []
        var dueDate: Date = Date()
        var isCompleted: Bool = false
        var reminderIdentifier: String? = nil

        init() {}

        enum CodingKeys: String, CodingKey {
            case id, task, detail, category, assignees, dueDate, isCompleted, reminderIdentifier
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
            task = (try? c.decode(String.self, forKey: .task)) ?? ""
            detail = (try? c.decode(String.self, forKey: .detail)) ?? ""
            let decodedCategory = try? c.decode(ExhibitionTemplateData.TaskItem.TaskCategory.self, forKey: .category)
            category = decodedCategory == .followUp ? .call : (decodedCategory ?? .call)
            assignees = (try? c.decode([String].self, forKey: .assignees)) ?? []
            dueDate = (try? c.decode(Date.self, forKey: .dueDate)) ?? Date()
            isCompleted = (try? c.decode(Bool.self, forKey: .isCompleted)) ?? false
            reminderIdentifier = try? c.decodeIfPresent(String.self, forKey: .reminderIdentifier)
        }
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case meetingDate, location, locationLatitude, locationLongitude,
             isOnlineMeeting, onlineLink, participants, agenda,
             discussionPoints, decisions, actionItems
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meetingDate       = (try? c.decode(Date.self, forKey: .meetingDate)) ?? Date()
        location          = (try? c.decode(String.self, forKey: .location)) ?? ""
        locationLatitude  = try? c.decodeIfPresent(Double.self, forKey: .locationLatitude)
        locationLongitude = try? c.decodeIfPresent(Double.self, forKey: .locationLongitude)
        isOnlineMeeting   = (try? c.decode(Bool.self, forKey: .isOnlineMeeting)) ?? false
        onlineLink        = (try? c.decode(String.self, forKey: .onlineLink)) ?? ""
        participants      = (try? c.decode([Participant].self, forKey: .participants)) ?? []
        agenda            = (try? c.decode(String.self, forKey: .agenda)) ?? ""
        discussionPoints  = (try? c.decode([String].self, forKey: .discussionPoints)) ?? []
        decisions         = (try? c.decode([String].self, forKey: .decisions)) ?? []
        actionItems       = (try? c.decode([ActionItem].self, forKey: .actionItems)) ?? []
    }
}

struct ExhibitionTemplateData: Codable, Equatable {
    var exhibitionName: String = ""
    var eventStartDate: Date = Date()
    var eventEndDate: Date = Date()
    var venue: String = ""
    var organizer: String = ""
    var supervisor: String = ""
    var participationType: ParticipationType = .visitor
    var participatingDate: Date = Date()
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
        var jobTitle: String = ""
        var contactPhone: String = ""
        var contactEmail: String = ""
        var productsServices: String = ""
        var interestLevel: Int = 3
        var notes: String = ""
        var linkedCardID: UUID? = nil

        init() {}

        enum CodingKeys: String, CodingKey {
            case id, boothNumber, companyName, contactPerson, jobTitle,
                 contactPhone, contactEmail, productsServices, interestLevel,
                 notes, linkedCardID
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
            boothNumber = (try? c.decode(String.self, forKey: .boothNumber)) ?? ""
            companyName = (try? c.decode(String.self, forKey: .companyName)) ?? ""
            contactPerson = (try? c.decode(String.self, forKey: .contactPerson)) ?? ""
            jobTitle = (try? c.decode(String.self, forKey: .jobTitle)) ?? ""
            contactPhone = (try? c.decode(String.self, forKey: .contactPhone)) ?? ""
            contactEmail = (try? c.decode(String.self, forKey: .contactEmail)) ?? ""
            productsServices = (try? c.decode(String.self, forKey: .productsServices)) ?? ""
            interestLevel = (try? c.decode(Int.self, forKey: .interestLevel)) ?? 3
            notes = (try? c.decode(String.self, forKey: .notes)) ?? ""
            linkedCardID = try? c.decodeIfPresent(UUID.self, forKey: .linkedCardID)
        }
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
        var detail: String = ""
        var category: TaskCategory = .call
        var assignees: [String] = []
        var dueDate: Date = Date()
        var isCompleted: Bool = false
        var reminderIdentifier: String? = nil

        init() {}

        enum CodingKeys: String, CodingKey {
            case id, title, detail, category, assignees, dueDate, isCompleted, reminderIdentifier
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
            title = (try? c.decode(String.self, forKey: .title)) ?? ""
            detail = (try? c.decode(String.self, forKey: .detail)) ?? ""
            let decodedCategory = try? c.decode(TaskCategory.self, forKey: .category)
            category = decodedCategory == .followUp ? .call : (decodedCategory ?? .call)
            assignees = (try? c.decode([String].self, forKey: .assignees)) ?? []
            dueDate = (try? c.decode(Date.self, forKey: .dueDate)) ?? Date()
            isCompleted = (try? c.decode(Bool.self, forKey: .isCompleted)) ?? false
            reminderIdentifier = try? c.decodeIfPresent(String.self, forKey: .reminderIdentifier)
        }

        enum TaskCategory: String, Codable, CaseIterable, Identifiable {
            case call     = "call"
            case email    = "email"
            case followUp = "follow_up"
            case meeting  = "meeting"

            var id: String { rawValue }

            static var selectableCases: [TaskCategory] {
                [.call, .email, .meeting]
            }

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
        case exhibitionName, eventStartDate, eventEndDate, venue, organizer, supervisor,
             participationType, participatingDate, visitedBooths, contacts, tasks, presetID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exhibitionName    = (try? c.decode(String.self, forKey: .exhibitionName)) ?? ""
        eventStartDate    = (try? c.decode(Date.self, forKey: .eventStartDate)) ?? Date()
        eventEndDate      = (try? c.decode(Date.self, forKey: .eventEndDate)) ?? Date()
        venue             = (try? c.decode(String.self, forKey: .venue)) ?? ""
        organizer         = (try? c.decode(String.self, forKey: .organizer)) ?? ""
        supervisor        = (try? c.decode(String.self, forKey: .supervisor)) ?? ""
        participationType = (try? c.decode(ParticipationType.self, forKey: .participationType)) ?? .visitor
        participatingDate = (try? c.decode(Date.self, forKey: .participatingDate)) ?? Date()
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
