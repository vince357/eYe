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
        "heic","heif","heics","tiff","tif","pdf","svg",
        "raw","cr2","cr3","nef","nrw","arw","srf","sr2",
        "dng","orf","ptx","pef","rw2","rwl","srw","raf",
        "3fr","mef","mos","mrw","erf","kdc","dcs","drf",
        "dcr","cap","iiq","tga","exr","pnm","pbm","pgm",
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

    func goNext()     { guard !files.isEmpty else { return }; currentIndex = (currentIndex + 1) % files.count; pendingRotation = 0 }
    func goPrevious() { guard !files.isEmpty else { return }; currentIndex = (currentIndex - 1 + files.count) % files.count; pendingRotation = 0 }
    func goFirst()    { currentIndex = 0; pendingRotation = 0 }
    func goLast()     { currentIndex = max(0, files.count - 1); pendingRotation = 0 }

    private var previousRandomIndex: Int?
    func goRandom() {
        guard files.count > 1 else { return }
        previousRandomIndex = currentIndex
        var next: Int
        repeat { next = Int.random(in: 0..<files.count) } while next == currentIndex
        currentIndex = next
        pendingRotation = 0
    }
    func goBackFromRandom() {
        if let p = previousRandomIndex { currentIndex = p; previousRandomIndex = nil }
        else { goPrevious() }
        pendingRotation = 0
    }

    // MARK: - Rotation (CW, 90° steps)

    func rotateCW() { pendingRotation = (pendingRotation + 90) % 360 }

    /// Lossless save using CGImageDestination, with a robust standard RGBA
    /// rendering context so it doesn't crash on indexed/paletted or unusual
    /// bit-depth PNGs (the previous implementation copied the source's raw
    /// bitmap info, which some PNG variants are incompatible with).
    func saveLosslessly(completion: @escaping (Bool, String) -> Void) {
        guard let file = currentFile else { completion(false, L("toast.noFile")); return }
        guard pendingRotation != 0 else { completion(false, L("toast.noRotation")); return }

        let url = file.url
        let rotationSteps = pendingRotation / 90

        DispatchQueue.global(qos: .userInitiated).async {
            guard let dataProvider = CGDataProvider(url: url as CFURL),
                  let source = CGImageSourceCreateWithDataProvider(dataProvider, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                DispatchQueue.main.async { completion(false, L("toast.saveFailed", "read error")) }
                return
            }

            guard let rotated = Self.rotatedCopy(of: cgImage, times: rotationSteps) else {
                DispatchQueue.main.async { completion(false, L("toast.saveFailed", "rotation error")) }
                return
            }

            let ext = url.pathExtension.lowercased()
            let uti: String
            switch ext {
            case "png","ico","bmp": uti = "public.png"
            case "tiff","tif":      uti = "public.tiff"
            case "gif":             uti = "com.compuserve.gif"
            case "jpg","jpeg":      uti = "public.jpeg"
            case "heic","heif":     uti = "public.heic"
            default:                uti = "public.png"
            }

            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti as CFString, 1, nil) else {
                DispatchQueue.main.async { completion(false, L("toast.saveFailed", "write error")) }
                return
            }

            let props: [String: Any] = (ext == "jpg" || ext == "jpeg")
                ? [kCGImageDestinationLossyCompressionQuality as String: 1.0]
                : [:]

            CGImageDestinationAddImage(dest, rotated, props as CFDictionary)
            let ok = CGImageDestinationFinalize(dest)

            DispatchQueue.main.async {
                if ok {
                    self.pendingRotation = 0
                    completion(true, L("toast.saved"))
                } else {
                    completion(false, L("toast.saveFailed", "finalize error"))
                }
            }
        }
    }

    /// Renders the image into a standard 8-bit RGBA context before rotating,
    /// so any source pixel format (indexed PNG, grayscale, 16-bit, CMYK, etc.)
    /// is normalized first. This is what prevents the crash reported on PNGs.
    private static func rotatedCopy(of image: CGImage, times: Int) -> CGImage? {
        let steps = ((times % 4) + 4) % 4
        var current = normalize(image)
        guard var result = current else { return nil }

        for _ in 0..<steps {
            let w = result.width, h = result.height
            guard let ctx = CGContext(
                data: nil,
                width: h,
                height: w,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }

            ctx.translateBy(x: CGFloat(h), y: 0)
            ctx.rotate(by: .pi / 2)
            ctx.draw(result, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
            guard let next = ctx.makeImage() else { return nil }
            result = next
        }
        current = result
        return current
    }

    private static func normalize(_ image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

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
            completion(true, L("toast.trashed", file.name))
        } catch {
            completion(false, L("toast.trashFailed", error.localizedDescription))
        }
    }
}
