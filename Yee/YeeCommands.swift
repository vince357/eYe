import SwiftUI
import AppKit

enum YeeMenuAction {
    case openFile
    case revealInFinder
    case deleteCurrent
    case rotateCW
    case saveLossless
    case zoomIn, zoomOut, zoomReset, fitOnScreen
    case toggleFullScreen
    case toggleStatusBar
    case nextFile, previousFile, firstFile, lastFile
    case randomFile, backFromRandom
}

struct YeeCommands: Commands {
    @ObservedObject private var settings = AppSettings.shared

    var body: some Commands {

        CommandGroup(replacing: .newItem) {
            Button("Ouvrir…") { post(.openFile) }
                .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Afficher dans le Finder") { post(.revealInFinder) }
                .keyboardShortcut("l", modifiers: .command)

            Divider()

            Button("Pivoter à 90° (horaire)") { post(.rotateCW) }
                .keyboardShortcut("r", modifiers: .command)

            Button("Enregistrer (sans perte)") { post(.saveLossless) }
                .keyboardShortcut("s", modifiers: .command)

            Divider()

            Button("Déplacer vers la Corbeille") { post(.deleteCurrent) }
        }

        CommandMenu("Affichage") {
            Button("Plein écran") { post(.toggleFullScreen) }
                .keyboardShortcut("f", modifiers: .command)

            Divider()

            Button("Ajuster à l'écran") { post(.fitOnScreen) }
            Button("Zoom 100%") { post(.zoomReset) }
            Button("Zoom avant") { post(.zoomIn) }
            Button("Zoom arrière") { post(.zoomOut) }

            Divider()

            Menu("Options d'ajustement") {
                Toggle("Réduire horizontalement", isOn: $settings.shrinkHorizontal)
                Toggle("Réduire verticalement", isOn: $settings.shrinkVertical)
                Divider()
                Toggle("Étirer horizontalement", isOn: $settings.stretchHorizontal)
                Toggle("Étirer verticalement", isOn: $settings.stretchVertical)
            }
            Toggle("Toujours ajuster à l'ouverture", isOn: $settings.alwaysFitOnOpen)

            Divider()

            Toggle("Afficher la barre de statut", isOn: $settings.showStatusBar)

            Divider()

            Menu("Trier par") {
                ForEach(SortKey.allCases) { key in
                    Button {
                        settings.sortKey = key
                        settings.save()
                        NotificationCenter.default.post(name: .yeeSortChanged, object: nil)
                    } label: {
                        HStack { Text(key.rawValue); if settings.sortKey == key { Image(systemName: "checkmark") } }
                    }
                }
                Divider()
                Button {
                    settings.sortDirection = settings.sortDirection == .ascending ? .descending : .ascending
                    settings.save()
                    NotificationCenter.default.post(name: .yeeSortChanged, object: nil)
                } label: {
                    Text(settings.sortDirection == .ascending ? "Ordre croissant ✓" : "Ordre décroissant ✓")
                }
            }

            Toggle("Inclure les sous-dossiers", isOn: $settings.includeSubfolders)
                .onChange(of: settings.includeSubfolders) { _ in
                    settings.save()
                    NotificationCenter.default.post(name: .yeeSortChanged, object: nil)
                }
        }

        CommandMenu("Navigation") {
            Button("Image suivante") { post(.nextFile) }
            Button("Image précédente") { post(.previousFile) }
            Divider()
            Button("Première image") { post(.firstFile) }
            Button("Dernière image") { post(.lastFile) }
            Divider()
            Button("Image aléatoire") { post(.randomFile) }
            Button("Revenir en arrière") { post(.backFromRandom) }
        }
    }

    private func post(_ action: YeeMenuAction) {
        NotificationCenter.default.post(name: .yeeMenuAction, object: action)
    }
}
