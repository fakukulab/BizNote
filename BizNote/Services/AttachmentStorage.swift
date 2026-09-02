import Foundation

/// Stores arbitrary file attachments (for the custom note template's
/// attachments section) under Documents/Attachments, each inside its own
/// UUID-named folder so the original filename is preserved for display
/// while avoiding collisions between attachments that share a name.
enum AttachmentStorage {
    static func directory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// `sourceURL` is expected to be security-scoped (e.g. from a
    /// `.fileImporter` picker); the caller is responsible for calling
    /// `startAccessingSecurityScopedResource()` beforehand.
    @discardableResult
    static func saveAttachment(from sourceURL: URL) -> String? {
        let fm = FileManager.default
        let folderName = UUID().uuidString
        let folder = directory().appendingPathComponent(folderName, isDirectory: true)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(sourceURL.lastPathComponent)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)
            return "\(folderName)/\(sourceURL.lastPathComponent)"
        } catch {
            return nil
        }
    }

    static func fileURL(path: String) -> URL {
        directory().appendingPathComponent(path)
    }

    static func attachmentDisplayName(path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static func removeAttachment(path: String) {
        let folder = directory().appendingPathComponent(path).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
    }
}
