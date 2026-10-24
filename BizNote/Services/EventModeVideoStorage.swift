import Foundation
import UniformTypeIdentifiers
import CoreTransferable

enum EventModeVideoStorage {
    static func directory() -> URL {
        let dir = URL.documentsDirectory.appending(path: "EventModeVideos", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for filename: String) -> URL {
        directory().appending(path: filename)
    }

    static func importVideo(from sourceURL: URL) throws -> String {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = directory().appending(path: filename)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return filename
    }

    static func remove(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }
}

/// `PhotosPicker` has no built-in support for loading a movie's file URL; this
/// `Transferable` wrapper is Apple's documented pattern for receiving a
/// security-scoped copy of the picked video, which we then move into our own
/// storage directory for offline, permission-free playback later.
struct EventModeTransferableMovie: Transferable {
    let importedFilename: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(EventModeVideoStorage.url(for: movie.importedFilename))
        } importing: { received in
            let filename = try EventModeVideoStorage.importVideo(from: received.file)
            return Self(importedFilename: filename)
        }
    }
}
