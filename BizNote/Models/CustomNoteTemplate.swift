import Foundation

struct CustomNoteTemplateData: Codable, Equatable {
    var sections: [CustomNoteTemplateSection] = []

    static var defaultSections: [CustomNoteTemplateSection] {
        CustomNoteTemplateSection.Kind.addNoteCases.map { kind in
            CustomNoteTemplateSection(kind: kind, title: kind.defaultTitle, isEnabled: true)
        }
    }

    static var defaultTemplate: CustomNoteTemplateData {
        CustomNoteTemplateData(sections: defaultSections)
    }
}

struct CustomNoteTemplateSection: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: Kind
    var title: String
    var isEnabled: Bool = true
    var text: String = ""
    var tasks: [CustomNoteTask] = []
    var participants: [CustomNoteParticipant] = []
    var presetID: UUID? = nil

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case date
        case workItems
        case memo
        case location
        case followUp
        case eventName
        case contacts
        case taskBoard
        case achievement
        case attachments
        case participants
        case work
        case addEvent

        var id: String { rawValue }

        static var addNoteCases: [Kind] {
            [.date, .workItems, .memo, .location, .participants, .followUp, .eventName, .contacts]
        }

        var defaultTitle: String {
            switch self {
            case .date:
                return String(localized: "template.item.date", defaultValue: "Date")
            case .workItems:
                return String(localized: "template.item.workItems", defaultValue: "Work Items")
            case .memo:
                return String(localized: "template.item.memo", defaultValue: "Memo")
            case .location:
                return String(localized: "template.item.location", defaultValue: "Location")
            case .followUp:
                return String(localized: "template.item.followUp", defaultValue: "Follow-up")
            case .eventName:
                return String(localized: "template.item.eventName", defaultValue: "Event Name")
            case .contacts:
                return String(localized: "template.item.contacts", defaultValue: "Contacts")
            case .taskBoard:
                return String(localized: "customTemplate.taskBoard", defaultValue: "업무")
            case .achievement:
                return String(localized: "customTemplate.achievement", defaultValue: "성과")
            case .attachments:
                return String(localized: "customTemplate.attachments", defaultValue: "첨부파일")
            case .participants:
                return String(localized: "template.item.participants", defaultValue: "Participants")
            case .work:
                return String(localized: "customTemplate.work", defaultValue: "업무")
            case .addEvent:
                return String(localized: "customTemplate.addEvent", defaultValue: "행사추가")
            }
        }

        var systemImage: String {
            switch self {
            case .date:
                return "calendar"
            case .workItems:
                return "checklist"
            case .memo:
                return "note.text"
            case .location:
                return "mappin.and.ellipse"
            case .followUp:
                return "arrow.triangle.2.circlepath"
            case .eventName:
                return "calendar.badge.clock"
            case .contacts:
                return "person.crop.rectangle.stack"
            case .taskBoard:
                return "checklist"
            case .achievement:
                return "rosette"
            case .attachments:
                return "paperclip"
            case .participants:
                return "person.2.fill"
            case .work:
                return "doc.text.fill"
            case .addEvent:
                return "calendar.badge.plus"
            }
        }
    }
}

struct CustomNoteTask: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""
    var category: ExhibitionTemplateData.TaskItem.TaskCategory = .call
    var assignees: [String] = []
    var dueDate: Date = Date()
    var status: Status = .todo

    init(
        id: UUID = UUID(),
        title: String = "",
        detail: String = "",
        category: ExhibitionTemplateData.TaskItem.TaskCategory = .call,
        assignees: [String] = [],
        dueDate: Date = Date(),
        status: Status = .todo
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.assignees = assignees
        self.dueDate = dueDate
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id, title, detail, category, assignees, dueDate, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        detail = (try? c.decode(String.self, forKey: .detail)) ?? ""
        let decodedCategory = try? c.decode(ExhibitionTemplateData.TaskItem.TaskCategory.self, forKey: .category)
        category = decodedCategory == .followUp ? .call : (decodedCategory ?? .call)
        assignees = (try? c.decode([String].self, forKey: .assignees)) ?? []
        dueDate = (try? c.decode(Date.self, forKey: .dueDate)) ?? Date()
        status = (try? c.decode(Status.self, forKey: .status)) ?? .todo
    }

    enum Status: String, Codable, CaseIterable, Identifiable {
        case todo
        case inProgress
        case done

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .todo:
                return String(localized: "task.status.todo")
            case .inProgress:
                return String(localized: "task.status.inProgress")
            case .done:
                return String(localized: "task.status.done")
            }
        }
    }
}

struct CustomNoteParticipant: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var country: String = ""
    var name: String = ""
    var company: String = ""
    var jobTitle: String = ""
    var email: String = ""
    var phone: String = ""
    var memo: String = ""

    init(
        id: UUID = UUID(),
        country: String = "",
        name: String = "",
        company: String = "",
        jobTitle: String = "",
        email: String = "",
        phone: String = "",
        memo: String = ""
    ) {
        self.id = id
        self.country = country
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.email = email
        self.phone = phone
        self.memo = memo
    }

    enum CodingKeys: String, CodingKey {
        case id, country, name, company, jobTitle, email, phone, memo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        country = (try? c.decode(String.self, forKey: .country)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        company = (try? c.decode(String.self, forKey: .company)) ?? ""
        jobTitle = (try? c.decode(String.self, forKey: .jobTitle)) ?? ""
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        phone = (try? c.decode(String.self, forKey: .phone)) ?? ""
        memo = (try? c.decode(String.self, forKey: .memo)) ?? ""
    }
}
