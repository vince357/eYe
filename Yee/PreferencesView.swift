import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var languageChangedSinceOpen = false

    var body: some View {
        Form {
            Section {
                Picker(L("prefs.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.bottom, 4)

            Section(L("prefs.section.opening")) {
                Toggle(L("prefs.openFullScreen"), isOn: $settings.openFullScreenByDefault)
                Toggle(L("prefs.alwaysFit"), isOn: $settings.alwaysFitOnOpen)
                Toggle(L("prefs.includeSubfolders"), isOn: $settings.includeSubfolders)
            }
            .padding(.bottom, 4)

            Section(L("prefs.section.interface")) {
                Toggle(L("prefs.showStatusBar"), isOn: $settings.showStatusBar)
            }
            .padding(.bottom, 4)

            Section(L("prefs.section.fitting")) {
                Toggle(L("menu.shrinkH"), isOn: $settings.shrinkHorizontal)
                Toggle(L("menu.shrinkV"), isOn: $settings.shrinkVertical)
                Toggle(L("menu.stretchH"), isOn: $settings.stretchHorizontal)
                Toggle(L("menu.stretchV"), isOn: $settings.stretchVertical)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onDisappear { settings.save() }
        .onChange(of: settings.language) { newValue in
            settings.save()
            // Our own UI (menus, toasts, alerts) already updates instantly via
            // L(). But standard macOS-supplied menu items (Quit/Hide/
            // Services/Window/Help…) are localized by AppKit itself from the
            // system's own resources, resolved once at process launch based
            // on the "AppleLanguages" preference — they can't be hot-swapped.
            // Setting it here means a relaunch will pick up the new language
            // for those too, without affecting our own instantly-updating
            // strings.
            UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
            promptRestartIfNeeded()
        }
        .onChange(of: settings.openFullScreenByDefault) { _ in settings.save() }
        .onChange(of: settings.alwaysFitOnOpen) { _ in settings.save() }
        .onChange(of: settings.includeSubfolders) { _ in
            settings.save()
            NotificationCenter.default.post(name: .yeeSortChanged, object: nil)
        }
        .onChange(of: settings.showStatusBar) { _ in settings.save() }
        .onChange(of: settings.shrinkHorizontal) { _ in settings.save() }
        .onChange(of: settings.shrinkVertical) { _ in settings.save() }
        .onChange(of: settings.stretchHorizontal) { _ in settings.save() }
        .onChange(of: settings.stretchVertical) { _ in settings.save() }
    }

    private func promptRestartIfNeeded() {
        let alert = NSAlert()
        alert.messageText = L("prefs.restartTitle")
        alert.informativeText = L("prefs.restartMessage")
        alert.addButton(withTitle: L("prefs.restartLater"))
        alert.alertStyle = .informational
        alert.runModal()
    }
}
