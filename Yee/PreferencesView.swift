import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings = AppSettings.shared

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

            Section(L("prefs.section.opening")) {
                Toggle(L("prefs.openFullScreen"), isOn: $settings.openFullScreenByDefault)
                Toggle(L("prefs.alwaysFit"), isOn: $settings.alwaysFitOnOpen)
                Toggle(L("prefs.includeSubfolders"), isOn: $settings.includeSubfolders)
            }

            Section(L("prefs.section.interface")) {
                Toggle(L("prefs.showStatusBar"), isOn: $settings.showStatusBar)
            }

            Section(L("prefs.section.fitting")) {
                Toggle(L("menu.shrinkH"), isOn: $settings.shrinkHorizontal)
                Toggle(L("menu.shrinkV"), isOn: $settings.shrinkVertical)
                Toggle(L("menu.stretchH"), isOn: $settings.stretchHorizontal)
                Toggle(L("menu.stretchV"), isOn: $settings.stretchVertical)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onDisappear { settings.save() }
        .onChange(of: settings.language) { _ in settings.save() }
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
}
