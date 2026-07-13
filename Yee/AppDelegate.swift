import AppKit

extension Notification.Name {
    static let openImageURL    = Notification.Name("yee.openImageURL")
    static let openFolderURL   = Notification.Name("yee.openFolderURL")
    static let yeeMenuAction   = Notification.Name("yee.menuAction")
    static let yeeSortChanged  = Notification.Name("yee.sortChanged")
}

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Called when app is already running and user opens a file from Finder
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        dispatch(url: URL(fileURLWithPath: filename))
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        guard let first = filenames.first else { return }
        dispatch(url: URL(fileURLWithPath: first))
    }

    // Called on cold launch with a file — applicationDidFinishLaunching fires AFTER
    // openFile:, but we still need this for the case where the window isn't ready yet.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply startup preferences
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
        // Post immediately; ContentView will pick it up via onReceive.
        // If the window hasn't appeared yet, we retry after a short delay.
        NotificationCenter.default.post(name: name, object: url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NotificationCenter.default.post(name: name, object: url)
        }
    }
}
