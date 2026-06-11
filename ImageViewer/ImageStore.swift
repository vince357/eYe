import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

enum SortOrder: String, CaseIterable, Identifiable {
    case name         = "Nom"
    case dateCreated  = "Date d'enregistrement"
    case dateModified = "Date de modification"
    case size         = "Poids"
    var id: String { rawValue }
}

struct ImageFile: Identifiable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
    var dateCreated: Date
    var dateModified: Date
    var fileSize: Int

    init(url: URL) {
        self.url = url
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        self.dateCreated  = attrs[.creationDate]  as? Date ?? Date.distantPast
        self.dateModified = attrs[.modificationDate] as? Date ?? Date.distantPast
        self.fileSize     = attrs[.size] as? Int ?? 0
    }
}

class ImageStore: ObservableObject {
    @Published var images: [ImageFile] = []
    @Published var currentIndex: Int = 0
    @Published var sortOrder: SortOrder = .name { didSet { sortImages() } }
    @Published var includeSubfolders: Bool = false { didSet { reloadCurrentFolder() } }
    @Published var currentFolderURL: URL?
    @Published var rotationAngle: Double = 0   // cumulative degrees, multiple of 90

    // All formats natively supported by ImageIO / NSImage on macOS
    static let supportedExtensions: Set<String> = [
        // Common
        "jpg","jpeg","png","gif","webp","bmp","ico",
        // Apple
        "heic","heif","heics",
        // TIFF family
        "tiff","tif",
        // Vector / PDF
        "pdf","svg",
        // RAW cameras
        "raw","cr2","cr3","nef","nrw","arw","srf","sr2",
        "dng","orf","ptx","pef","rw2","rwl","srw","raf",
        "3fr","mef","mos","mrw","erf","kdc","dcs","drf",
        "dcr","cap","iiq","fts","fit","fits",
        // Others
        "tga","exr","pnm","pbm","pgm","ppm","hdr","pic",
        "psd","sgi","cur","xbm"
    ]

    var currentImage: ImageFile? {
        guard !images.isEmpty, images.indices.contains(currentIndex) else { return nil }
        return images[currentIndex]
    }

    // MARK: - Navigation

    func openImage(url: URL) {
        let folder = url.deletingLastPathComponent()
        loadFolder(folder)
        if let idx = images.firstIndex(where: { $0.url == url }) {
            currentIndex = idx
        }
        rotationAngle = 0
    }

    func reloadCurrentFolder() {
        guard let folder = currentFolderURL else { return }
        let current = currentImage?.url
        loadFolder(folder)
        if let url = current, let idx = images.firstIndex(where: { $0.url == url }) {
            currentIndex = idx
        }
    }

    func loadFolder(_ folder: URL) {
        currentFolderURL = folder
        let fm = FileManager.default

        var collected: [URL] = []

        if includeSubfolders {
            guard let enumerator = fm.enumerator(
                at: folder,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            for case let url as URL in enumerator {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if !isDir && Self.supportedExtensions.contains(url.pathExtension.lowercased()) {
                    collected.append(url)
                }
            }
        } else {
            guard let contents = try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            collected = contents.filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
        }

        images = collected.map { ImageFile(url: $0) }
        sortImages()
    }

    func sortImages() {
        let current = currentImage?.url
        switch sortOrder {
        case .name:
            images.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .dateCreated:
            images.sort { $0.dateCreated < $1.dateCreated }
        case .dateModified:
            images.sort { $0.dateModified < $1.dateModified }
        case .size:
            images.sort { $0.fileSize < $1.fileSize }
        }
        if let url = current, let idx = images.firstIndex(where: { $0.url == url }) {
            currentIndex = idx
        }
    }

    func goNext() {
        guard !images.isEmpty else { return }
        currentIndex = (currentIndex + 1) % images.count   // loop
        rotationAngle = 0
    }

    func goPrevious() {
        guard !images.isEmpty else { return }
        currentIndex = (currentIndex - 1 + images.count) % images.count   // loop
        rotationAngle = 0
    }

    func goFirst() {
        currentIndex = 0
        rotationAngle = 0
    }

    func goRandom() {
        guard images.count > 1 else { return }
        var next: Int
        repeat { next = Int.random(in: 0..<images.count) } while next == currentIndex
        currentIndex = next
        rotationAngle = 0
    }

    // MARK: - Rotation

    func rotateLeft() {
        rotationAngle -= 90
    }

    // MARK: - Save rotated

    func saveRotated(completion: @escaping (Bool, String) -> Void) {
        guard let imgFile = currentImage else {
            completion(false, "Aucune image sélectionnée."); return
        }
        let angle = rotationAngle.truncatingRemainder(dividingBy: 360)
        guard angle != 0 else {
            completion(false, "Aucune rotation appliquée."); return
        }

        guard let src = NSImage(contentsOf: imgFile.url) else {
            completion(false, "Impossible de lire l'image."); return
        }

        let rotated = src.rotated(by: angle)
        let ext = imgFile.url.pathExtension.lowercased()

        // Determine file type
        let fileType: NSBitmapImageRep.FileType
        switch ext {
        case "png","svg","ico": fileType = .png
        case "bmp":             fileType = .bmp
        case "gif":             fileType = .gif
        case "tiff","tif":      fileType = .tiff
        default:                fileType = .jpeg
        }

        guard let tiffData = rotated.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let data = rep.representation(using: fileType, properties: [.compressionFactor: 0.92]) else {
            completion(false, "Erreur lors de la conversion."); return
        }

        do {
            try data.write(to: imgFile.url)
            rotationAngle = 0
            completion(true, "Image sauvegardée.")
        } catch {
            completion(false, "Erreur écriture : \(error.localizedDescription)")
        }
    }

    // MARK: - Finder / Editor

    func revealInFinder() {
        guard let url = currentImage?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openInDefaultEditor() {
        guard let url = currentImage?.url else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - NSImage rotation helper
extension NSImage {
    func rotated(by degrees: Double) -> NSImage {
        let radians = CGFloat(degrees) * .pi / 180
        // After rotation, width/height may swap
        let absRad = abs(radians)
        let newSize: CGSize
        // For multiples of 90°, swap dimensions accordingly
        let normalized = Int(degrees.truncatingRemainder(dividingBy: 360) + 360) % 360
        if normalized == 90 || normalized == 270 {
            newSize = CGSize(width: size.height, height: size.width)
        } else {
            newSize = size
        }
        let result = NSImage(size: newSize)
        result.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        transform.rotate(byDegrees: -degrees)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        result.unlockFocus()
        return result
    }
}
