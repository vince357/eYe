import AppKit

extension Notification.Name {
    static let openImageURL    = Notification.Name("yee.openImageURL")
    static let openFolderURL   = Notification.Name("yee.openFolderURL")
    static let yeeMenuAction   = Notification.Name("yee.menuAction")
    static let yeeSortChanged  = Notification.Name("yee.sortChanged")
}

class AppDelegate: NSObject, NSApplicationDelegate {

    /// Set immediately when Finder/Dock hands us a file/folder to open.
    /// ContentView polls this a few times after appearing (see ContentView's
    /// consumePendingURLIfNeeded), which removes the launch-timing race that
    /// made cold-launch "open with" and Dock drops unreliable before.
    static var pendingURL: URL?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Modern hook (macOS 10.13+) — the one Finder/LaunchServices
    // actually uses for a plain SwiftUI-lifecycle app (no NSDocument).
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        dispatch(url: first)
    }

    // MARK: - Legacy hooks kept as a fallback (harmless if unused)
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        dispatch(url: URL(fileURLWithPath: filename))
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        guard let first = filenames.first else { return }
        dispatch(url: URL(fileURLWithPath: first))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppSettings.shared.openFullScreenByDefault {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.mainWindow?.toggleFullScreen(nil)
            }
        }
    }

    private func dispatch(url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let name: Notification.Name = isDir.boolValue ? .openFolderURL : .openImageURL

        Self.pendingURL = url
        NotificationCenter.default.post(name: name, object: url)
    }
}
