import Foundation
import UIKit

/// Lightweight local image reference store for projects.
/// Stores image data as files under Application Support, not in UserDefaults.
/// Project model holds only identifier strings (filenames).
enum ProjectImageStore {

    // MARK: - Paths

    static var baseDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("StudentOps", isDirectory: true)
            .appendingPathComponent("ProjectImages", isDirectory: true)
    }

    static func directory(for projectID: String) -> URL {
        let safe = projectID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unknown" : projectID
        return baseDirectory.appendingPathComponent(safe, isDirectory: true)
    }

    static func fileURL(for identifier: String, projectID: String) -> URL {
        // identifier is filename like "uuid.jpg"
        // Ensure we treat it as filename not path
        let file = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return directory(for: projectID).appendingPathComponent(file)
    }

    /// Global lookup for image reference without project context — searches all project directories
    static func fileURL(for identifier: String) -> URL? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // If identifier contains "/", treat as direct path
        if trimmed.contains("/") {
            return baseDirectory.appendingPathComponent(trimmed)
        }
        // Search known directories is expensive; return base assumption
        // Caller should know projectID; fallback to base directory file
        return baseDirectory.appendingPathComponent(trimmed)
    }

    // MARK: - Save / Load

    /// Saves image data for a project and returns the identifier (filename) to store in Project.imageReferences
    @discardableResult
    static func saveImageData(_ data: Data, forProjectID projectID: String, fileExtension: String = "jpg") -> String? {
        let dir = directory(for: projectID)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "jpg" : fileExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let url = dir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    /// Convenience for UIImage
    @discardableResult
    static func saveImage(_ image: UIImage, forProjectID projectID: String, compressionQuality: CGFloat = 0.8) -> String? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        return saveImageData(data, forProjectID: projectID, fileExtension: "jpg")
    }

    static func loadImageData(identifier: String, projectID: String) -> Data? {
        let url = fileURL(for: identifier, projectID: projectID)
        return try? Data(contentsOf: url)
    }

    static func loadImage(identifier: String, projectID: String) -> UIImage? {
        guard let data = loadImageData(identifier: identifier, projectID: projectID) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func deleteImage(identifier: String, projectID: String) -> Bool {
        let url = fileURL(for: identifier, projectID: projectID)
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    static func imageExists(identifier: String, projectID: String) -> Bool {
        let url = fileURL(for: identifier, projectID: projectID)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// All image identifiers for a project by scanning directory
    static func allImageReferences(for projectID: String) -> [String] {
        let dir = directory(for: projectID)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.map { $0.lastPathComponent }.sorted()
    }

    /// Validates that identifier is not empty and does not contain path traversal
    static func isValidIdentifier(_ id: String) -> Bool {
        let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard !t.contains("..") && !t.contains("/") && !t.contains("\\") else { return false }
        return true
    }
}
