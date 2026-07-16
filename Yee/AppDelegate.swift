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

    /// Identifier tagged onto every main content window (see ContentView's
    /// onAppear) so we can tell them apart from the Preferences/About/Help
    /// windows when enforcing single-window mode.
    static let mainWindowID = NSUserInterfaceItemIdentifier("YeeMainWindow")

    /// When "single window" mode is on, Finder/Dock can still cause macOS to
    /// spin up an extra window per open request (a side effect of declaring
    /// CFBundleDocumentTypes alongside a WindowGroup scene). Rather than
    /// fight that at the source, we let it happen and then merge back down
    /// to one window shortly after — whichever is frontmost survives, since
    /// it's the one that just received the newly-opened file.
    static func enforceSingleWindowIfNeeded() {
        guard AppSettings.shared.singleWindowMode else { return }
        let mainWindows = NSApp.windows.filter { $0.identifier == mainWindowID }
        guard mainWindows.count > 1 else { return }
        let keeper = (NSApp.keyWindow.flatMap { mainWindows.contains($0) ? $0 : nil })
            ?? mainWindows.last!
        for w in mainWindows where w !== keeper {
            w.close()
        }
    }

    private func dispatch(url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let name: Notification.Name = isDir.boolValue ? .openFolderURL : .openImageURL

        Self.pendingURL = url
        NotificationCenter.default.post(name: name, object: url)

        for attempt in 1...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.25) {
                Self.enforceSingleWindowIfNeeded()
            }
        }
    }
}
