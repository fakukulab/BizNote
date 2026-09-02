import SwiftUI
import SwiftData
import PhotosUI

private struct ExhibitionPresetDraft {
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var venue: String = ""
    var organizer: String = ""
    var introduction: String = ""
    var exhibitItems: String = ""
    var supervisor: String = ""
    var contact: String = ""
    var homepage: String = ""
    var logoImagePath: String = ""

    init() {}

    init(preset: ExhibitionPreset) {
        name = preset.name
        startDate = preset.startDate
        endDate = preset.endDate
        venue = preset.venue
        organizer = preset.organizer
        introduction = preset.introduction
        exhibitItems = preset.exhibitItems
        supervisor = preset.supervisor
        contact = preset.contact
        homepage = preset.homepage
        logoImagePath = preset.logoImagePath
    }
}

struct ExhibitionDetailView: View {
    @Bindable var preset: ExhibitionPreset
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ExhibitionPresetDraft()
    @State private var logoItem: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var showDeleteConfirm = false
    @State private var isEditing = false

    var body: some View {
        Form {
            Section {
                logoEditor

                if isEditing {
                    TextField(String(localized: "exhibitions.name", defaultValue: "Event Name"), text: $draft.name)
                        .font(.headline)

                    HStack {
                        DatePicker("", selection: $draft.startDate, displayedComponents: .date)
                            .labelsHidden()
                        Text("-")
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(
                            get: { draft.endDate },
                            set: { draft.endDate = max($0, draft.startDate) }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    }

                    TextField(String(localized: "exhibitions.venue", defaultValue: "Venue"), text: $draft.venue)
                } else {
                    Text(preset.name.isEmpty ? String(localized: "note.untitled") : preset.name)
                        .font(.headline)
                    Label(preset.dateRangeDescription, systemImage: "calendar")
                        .foregroundStyle(.secondary)
                    if !preset.venue.isEmpty {
                        Label(preset.venue, systemImage: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(String(localized: "exhibitions.introduction", defaultValue: "Event Introduction")) {
                if isEditing {
                    TextEditor(text: $draft.introduction)
                        .frame(minHeight: editorHeight(for: draft.introduction, minimumLines: 3))
                } else {
                    Text(preset.introduction)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section(String(localized: "exhibitions.exhibitItems", defaultValue: "Exhibit Items")) {
                if isEditing {
                    TextEditor(text: $draft.exhibitItems)
                        .frame(minHeight: editorHeight(for: draft.exhibitItems, minimumLines: 3))
                } else {
                    Text(preset.exhibitItems)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                LabeledContent(String(localized: "exhibitions.organizer", defaultValue: "Host")) {
                    if isEditing {
                        TextField("", text: $draft.organizer)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(preset.organizer)
                    }
                }
                LabeledContent(String(localized: "exhibitions.supervisor", defaultValue: "Organizer")) {
                    if isEditing {
                        TextField("", text: $draft.supervisor)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(preset.supervisor)
                    }
                }
                LabeledContent(String(localized: "exhibitions.contact", defaultValue: "Contact")) {
                    if isEditing {
                        TextField("", text: $draft.contact)
                            .multilineTextAlignment(.trailing)
                    } else if let phoneURL {
                        Link(preset.contact, destination: phoneURL)
                    } else {
                        Text(preset.contact)
                    }
                }
            }

            Section(String(localized: "exhibitions.homepage", defaultValue: "Homepage")) {
                if isEditing {
                    TextField(String(localized: "exhibitions.homepage", defaultValue: "Homepage"), text: $draft.homepage)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    HStack {
                        Text(preset.homepage)
                        Spacer()
                        if let homepageURL {
                            Link(destination: homepageURL) {
                                Image(systemName: "safari")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(preset.name.isEmpty ? String(localized: "note.untitled") : preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) {
                        cancelEditing()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "action.save")) {
                        saveEditing()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(String(localized: "action.edit")) {
                        beginEditing()
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "exhibitions.delete.title", defaultValue: "Delete this event?"),
            isPresented: $showDeleteConfirm
        ) {
            Button(String(localized: "note.delete"), role: .destructive) {
                Task {
                    await CalendarReminderSyncService.shared.removeEvent(for: preset)
                    ExhibitionLogoStorage.remove(path: preset.logoImagePath)
                    context.delete(preset)
                    try? context.save()
                }
                dismiss()
            }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "exhibitions.delete.message", defaultValue: "This action cannot be undone."))
        }
        .onAppear {
            resetDraft()
            loadLogo()
        }
        .onChange(of: logoItem) { _, newValue in
            guard isEditing, let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let savedPath = ExhibitionLogoStorage.save(image, id: preset.id) {
                    draft.logoImagePath = savedPath
                    logoImage = image
                }
                logoItem = nil
            }
        }
    }

    private var logoEditor: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                if let logoImage {
                    Image(uiImage: logoImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if isEditing {
                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $logoItem, matching: .images) {
                        Label(String(localized: "exhibitions.image.upload", defaultValue: "Upload Image"), systemImage: "photo.badge.plus")
                            .font(.caption)
                    }

                    if !draft.logoImagePath.isEmpty {
                        Button(role: .destructive) {
                            ExhibitionLogoStorage.remove(path: draft.logoImagePath)
                            draft.logoImagePath = ""
                            logoImage = nil
                        } label: {
                            Label(String(localized: "exhibitions.image.remove", defaultValue: "Remove Image"), systemImage: "trash")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var homepageURL: URL? {
        let trimmed = preset.homepage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private var phoneURL: URL? {
        let digits = preset.contact.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    private func editorHeight(for text: String, minimumLines: Int) -> CGFloat {
        let lineCount = max(minimumLines, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        return CGFloat(lineCount) * 22 + 24
    }

    private func beginEditing() {
        resetDraft()
        isEditing = true
    }

    private func cancelEditing() {
        resetDraft()
        isEditing = false
    }

    private func saveEditing() {
        let oldLogoPath = preset.logoImagePath
        preset.name = draft.name
        preset.startDate = draft.startDate
        preset.endDate = max(draft.startDate, draft.endDate)
        preset.venue = draft.venue
        preset.organizer = draft.organizer
        preset.introduction = draft.introduction
        preset.exhibitItems = draft.exhibitItems
        preset.supervisor = draft.supervisor
        preset.contact = draft.contact
        preset.homepage = draft.homepage
        preset.logoImagePath = draft.logoImagePath
        if oldLogoPath != draft.logoImagePath {
            ExhibitionLogoStorage.remove(path: oldLogoPath)
        }
        try? context.save()
        Task { await CalendarReminderSyncService.shared.syncEvent(for: preset) }
        isEditing = false
    }

    private func resetDraft() {
        draft = ExhibitionPresetDraft(preset: preset)
        loadLogo()
    }

    private func loadLogo() {
        let path = isEditing ? draft.logoImagePath : preset.logoImagePath
        logoImage = ExhibitionLogoStorage.load(path: path)
    }
}

enum ExhibitionLogoStorage {
    static func directory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ExhibitionLogos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @discardableResult
    static func save(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.pngData() else { return nil }
        let filename = "\(id.uuidString).png"
        let url = directory().appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func load(path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: directory().appendingPathComponent(path).path)
    }

    static func remove(path: String) {
        guard !path.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory().appendingPathComponent(path))
    }
}
