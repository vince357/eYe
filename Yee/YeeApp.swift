import SwiftUI
import AppKit

@main
struct YeeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .commands {
            YeeCommands()
        }

        // Preferences window
        Settings {
            PreferencesView()
        }

        // Help window
        Window("Yee Help", id: "help") {
            HelpView()
        }
    }
}
