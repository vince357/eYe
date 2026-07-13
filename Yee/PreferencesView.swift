import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Ouverture") {
                Toggle("Ouvrir en plein écran par défaut", isOn: $settings.openFullScreenByDefault)
                Toggle("Toujours ajuster les images à l'ouverture", isOn: $settings.alwaysFitOnOpen)
                Toggle("Inclure les sous-dossiers", isOn: $settings.includeSubfolders)
            }

            Section("Interface") {
                Toggle("Afficher la barre de statut", isOn: $settings.showStatusBar)
            }

            Section("Options d'ajustement") {
                Toggle("Réduire horizontalement", isOn: $settings.shrinkHorizontal)
                Toggle("Réduire verticalement", isOn: $settings.shrinkVertical)
                Toggle("Étirer horizontalement", isOn: $settings.stretchHorizontal)
                Toggle("Étirer verticalement", isOn: $settings.stretchVertical)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onDisappear { settings.save() }
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
