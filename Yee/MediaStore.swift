import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

enum MediaKind: Int, Comparable {
    case image = 0, video = 1, other = 2
    static func < (lhs: MediaKind, rhs: MediaKind) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct MediaFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
    var dateModified: Date
    var fileSize: Int
    var kind: MediaKind

    init(url: URL) {
        self.url = url
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        self.dateModified = attrs[.modificationDate] as? Date ?? .distantPast
        self.fileSize     = attrs[.size] as? Int ?? 0
        let ext = url.pathExtension.lowercased()
        if MediaStore.imageExtensions.contains(ext) { self.kind = .image }
        else if MediaStore.videoExtensions.contains(ext) { self.kind = .video }
        else { self.kind = .other }
    }

    static func == (lhs: MediaFile, rhs: MediaFile) -> Bool { lhs.url == rhs.url }
}

class MediaStore: ObservableObject {
    @Published var files: [MediaFile] = []
    @Published var currentIndex: Int = 0
    @Published var currentFolderURL: URL?
    @Published var pendingRotation: Int = 0
    @Published var lastOpenWasEmpty: Bool = false   // true if user opened a file/folder with 0 supported media

    private let settings = AppSettings.shared

    static let imageExtensions: Set<String> = [
        "jpg","jpeg","png","gif","webp","bmp","ico",
        "heic","heif","heics","tiff","tif","svg",
        "tga","exr","pnm","pbm","pgm",
        "ppm","hdr","pic","psd","sgi","cur","xbm"
    ]

    static let videoExtensions: Set<String> = [
        "mp4","mov","m4v","avi","mkv","webm","mpg","mpeg","wmv","flv","3gp"
    ]

    static var allExtensions: Set<String> { imageExtensions.union(videoExtensions) }

    var currentFile: MediaFile? {
        guard !files.isEmpty, files.indices.contains(currentIndex) else { return nil }
        return files[currentIndex]
    }

    // MARK: - Load

    func openFile(url: URL) {
        let folder = url.deletingLastPathComponent()
        loadFolder(folder)
        if let idx = files.firstIndex(where: { $0.url == url }) { currentIndex = idx }
        pendingRotation = 0
    }

    func openFolder(url: URL) {
        loadFolder(url)
        currentIndex = 0
        pendingRotation = 0
    }

    func reload() {
        guard let f = currentFolderURL else { return }
        let cur = currentFile?.url
        loadFolder(f)
        if let u = cur, let idx = files.firstIndex(where: { $0.url == u }) { currentIndex = idx }
    }

    private func loadFolder(_ folder: URL) {
        currentFolderURL = folder
        let fm = FileManager.default
        var collected: [URL] = []

        if settings.includeSubfolders {
            if let e = fm.enumerator(at: folder,
                                     includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles]) {
                for case let url as URL in e {
                    let isDir = (try? url.resourceValues(forKeys:[.isDirectoryKey]))?.isDirectory ?? false
                    if !isDir && Self.allExtensions.contains(url.pathExtension.lowercased()) {
                        collected.append(url)
                    }
                }
            }
        } else {
            if let contents = try? fm.contentsOfDirectory(at: folder,
                                                           includingPropertiesForKeys: [],
                                                           options: [.skipsHiddenFiles]) {
                collected = contents.filter { Self.allExtensions.contains($0.pathExtension.lowercased()) }
            }
        }
        files = collected.map { MediaFile(url: $0) }
        lastOpenWasEmpty = files.isEmpty
        // The list's index mapping just changed entirely (reload/sort/toggle):
        // any stored random-history indices would now silently point at the
        // wrong files, so invalidate it here rather than in every caller.
        resetRandomHistory()
        sortFiles()
    }

    func sortFiles() {
        let cur = currentFile?.url
        let asc = settings.sortDirection == .ascending
        switch settings.sortKey {
        case .name:
            files.sort { asc
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        case .dateModified:
            files.sort { asc ? $0.dateModified < $1.dateModified : $0.dateModified > $1.dateModified }
        case .size:
            files.sort { asc ? $0.fileSize < $1.fileSize : $0.fileSize > $1.fileSize }
        case .fileType:
            files.sort {
                if $0.kind != $1.kind { return asc ? $0.kind < $1.kind : $0.kind > $1.kind }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
        if let u = cur, let idx = files.firstIndex(where: { $0.url == u }) { currentIndex = idx }
    }

    // MARK: - Navigation (all loop)

    func goNext()     { guard !files.isEmpty else { return }; currentIndex = (currentIndex + 1) % files.count; pendingRotation = 0; resetRandomHistory() }
    func goPrevious() { guard !files.isEmpty else { return }; currentIndex = (currentIndex - 1 + files.count) % files.count; pendingRotation = 0; resetRandomHistory() }
    func goFirst()    { currentIndex = 0; pendingRotation = 0; resetRandomHistory() }
    func goLast()     { currentIndex = max(0, files.count - 1); pendingRotation = 0; resetRandomHistory() }

    private var randomHistory: [Int] = []
    private var randomHistoryPos: Int = -1

    private func resetRandomHistory() {
        randomHistory = []
        randomHistoryPos = -1
    }

    /// R: builds a linear history like browser back/forward. Replays forward
    /// through previously-visited random picks if we've stepped back with
    /// Shift+R without going further since; only draws a genuinely new
    /// random image once we're at the end of that history.
    func goRandom() {
        guard files.count > 1 else { return }
        if randomHistory.isEmpty {
            randomHistory = [currentIndex]
            randomHistoryPos = 0
        }
        if randomHistoryPos < randomHistory.count - 1 {
            randomHistoryPos += 1
            currentIndex = randomHistory[randomHistoryPos]
        } else {
            var next: Int
            repeat { next = Int.random(in: 0..<files.count) } while next == currentIndex
            randomHistory.append(next)
            randomHistoryPos = randomHistory.count - 1
            currentIndex = next
        }
        pendingRotation = 0
    }

    /// Shift+R: steps back one entry in the same history, all the way to the
    /// original starting image.
    func goBackFromRandom() {
        guard randomHistoryPos > 0 else { return }
        randomHistoryPos -= 1
        currentIndex = randomHistory[randomHistoryPos]
        pendingRotation = 0
    }

    // MARK: - Rotation (CW, 90° steps) — visual only, not persisted to disk.
    func rotateCW() { pendingRotation = (pendingRotation + 90) % 360 }

    // MARK: - Finder

    func revealInFinder() {
        guard let url = currentFile?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Trash

    func deleteCurrentFile(completion: @escaping (Bool, String) -> Void) {
        guard let file = currentFile else { completion(false, L("toast.noFile")); return }
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            let idx = currentIndex
            files.removeAll { $0.url == file.url }
            currentIndex = files.isEmpty ? 0 : min(idx, files.count - 1)
            pendingRotation = 0
            resetRandomHistory()
            completion(true, L("toast.trashed", file.name))
        } catch {
            completion(false, L("toast.trashFailed", error.localizedDescription))
        }
    }
}
