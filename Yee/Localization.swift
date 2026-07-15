import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french  = "fr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .french:  return "Français"
        }
    }
}

/// Simple key-based localization dictionary.
/// To add a new language: add a case to AppLanguage, then add a matching
/// dictionary below. Missing keys fall back to English, then to the key itself.
enum L10n {
    static func t(_ key: String) -> String {
        let lang = AppSettings.shared.language
        if let dict = tables[lang], let value = dict[key] { return value }
        if let value = tables[.english]?[key] { return value }
        return key
    }

    private static let tables: [AppLanguage: [String: String]] = [
        .english: [
            // Drop zone
            "dropzone.title": "Open an image or a folder",
            "dropzone.subtitle": "Drag a file or folder here, or use File › Open",
            "dropzone.empty.title": "No supported media found",
            "dropzone.empty.subtitle": "This folder doesn't contain any image or video Yee can open.",

            // File menu
            "menu.open": "Open…",
            "menu.revealInFinder": "Reveal in Finder",
            "menu.rotate": "Rotate 90° (clockwise)",
            "menu.saveLossless": "Save Losslessly",
            "menu.delete": "Move to Trash",

            // View menu
            "menu.view": "View",
            "menu.fullscreen": "Full Screen",
            "menu.fitOnScreen": "Fit on Screen",
            "menu.zoom100": "Zoom 100%",
            "menu.zoomIn": "Zoom In",
            "menu.zoomOut": "Zoom Out",
            "menu.fitOptions": "Fitting Options",
            "menu.shrinkH": "Shrink to Fit Horizontally",
            "menu.shrinkV": "Shrink to Fit Vertically",
            "menu.stretchH": "Stretch to Fit Horizontally",
            "menu.stretchV": "Stretch to Fit Vertically",
            "menu.alwaysFit": "Always Fit Opened Images on Screen",
            "menu.showStatusBar": "Show Status Bar",
            "menu.sortBy": "Sort By",
            "menu.sortAscending": "Ascending ✓",
            "menu.sortDescending": "Descending ✓",
            "menu.includeSubfolders": "Include Subfolders",

            // Navigation menu
            "menu.navigation": "Navigation",
            "menu.next": "Next Image",
            "menu.previous": "Previous Image",
            "menu.first": "First Image",
            "menu.last": "Last Image",
            "menu.random": "Random Image",
            "menu.backFromRandom": "Go Back",

            // Sort keys
            "sort.name": "Name",
            "sort.dateModified": "Date Modified",
            "sort.size": "Size",
            "sort.fileType": "File Type",

            // Toasts / alerts
            "toast.saved": "Image saved.",
            "toast.saveFailed": "Save failed: %@",
            "toast.noRotation": "No pending rotation.",
            "toast.noFile": "No file selected.",
            "toast.trashed": "“%@” moved to the Trash.",
            "toast.trashFailed": "Error: %@",
            "alert.deleteTitle": "Delete this file?",
            "alert.cancel": "Cancel",
            "alert.moveToTrash": "Move to Trash",

            // Preferences
            "prefs.title": "Preferences",
            "prefs.language": "Language",
            "prefs.section.opening": "Opening",
            "prefs.openFullScreen": "Open in full screen by default",
            "prefs.alwaysFit": "Always fit images on open",
            "prefs.includeSubfolders": "Include subfolders",
            "prefs.section.interface": "Interface",
            "prefs.showStatusBar": "Show status bar",
            "prefs.section.fitting": "Fitting Options",
            "prefs.restartTitle": "Restart Required",
            "prefs.restartMessage": "Yee's own menus and messages already switched to the new language. However, some standard macOS menu items (Quit, Hide, Services, Window, Help…) are supplied by the system and will only follow the new language after you quit and reopen Yee.",
            "prefs.restartLater": "OK, I'll Restart Later",

            // About
            "about.title": "About Yee",
            "about.tagline": "A native macOS image viewer, spiritual successor to Xee³.",
            "about.license": "Licensed under the MIT License.",
            "about.github": "View on GitHub",
        ],
        .french: [
            "dropzone.title": "Ouvrir une image ou un dossier",
            "dropzone.subtitle": "Glissez un fichier ou un dossier ici, ou utilisez Fichier › Ouvrir",
            "dropzone.empty.title": "Aucun média pris en charge",
            "dropzone.empty.subtitle": "Ce dossier ne contient aucune image ou vidéo que Yee peut ouvrir.",

            "menu.open": "Ouvrir…",
            "menu.revealInFinder": "Afficher dans le Finder",
            "menu.rotate": "Pivoter à 90° (horaire)",
            "menu.saveLossless": "Enregistrer sans perte",
            "menu.delete": "Déplacer vers la Corbeille",

            "menu.view": "Affichage",
            "menu.fullscreen": "Plein écran",
            "menu.fitOnScreen": "Ajuster à l'écran",
            "menu.zoom100": "Zoom 100%",
            "menu.zoomIn": "Zoom avant",
            "menu.zoomOut": "Zoom arrière",
            "menu.fitOptions": "Options d'ajustement",
            "menu.shrinkH": "Réduire horizontalement",
            "menu.shrinkV": "Réduire verticalement",
            "menu.stretchH": "Étirer horizontalement",
            "menu.stretchV": "Étirer verticalement",
            "menu.alwaysFit": "Toujours ajuster les images à l'ouverture",
            "menu.showStatusBar": "Afficher la barre de statut",
            "menu.sortBy": "Trier par",
            "menu.sortAscending": "Ordre croissant ✓",
            "menu.sortDescending": "Ordre décroissant ✓",
            "menu.includeSubfolders": "Inclure les sous-dossiers",

            "menu.navigation": "Navigation",
            "menu.next": "Image suivante",
            "menu.previous": "Image précédente",
            "menu.first": "Première image",
            "menu.last": "Dernière image",
            "menu.random": "Image aléatoire",
            "menu.backFromRandom": "Revenir en arrière",

            "sort.name": "Nom",
            "sort.dateModified": "Date de modification",
            "sort.size": "Poids",
            "sort.fileType": "Type de fichier",

            "toast.saved": "Image sauvegardée.",
            "toast.saveFailed": "Échec de la sauvegarde : %@",
            "toast.noRotation": "Aucune rotation en attente.",
            "toast.noFile": "Aucun fichier sélectionné.",
            "toast.trashed": "« %@ » déplacé vers la Corbeille.",
            "toast.trashFailed": "Erreur : %@",
            "alert.deleteTitle": "Supprimer ce fichier ?",
            "alert.cancel": "Annuler",
            "alert.moveToTrash": "Déplacer vers la Corbeille",

            "prefs.title": "Préférences",
            "prefs.language": "Langue",
            "prefs.section.opening": "Ouverture",
            "prefs.openFullScreen": "Ouvrir en plein écran par défaut",
            "prefs.alwaysFit": "Toujours ajuster les images à l'ouverture",
            "prefs.includeSubfolders": "Inclure les sous-dossiers",
            "prefs.section.interface": "Interface",
            "prefs.showStatusBar": "Afficher la barre de statut",
            "prefs.section.fitting": "Options d'ajustement",
            "prefs.restartTitle": "Redémarrage nécessaire",
            "prefs.restartMessage": "Les menus et messages propres à Yee ont déjà basculé dans la nouvelle langue. En revanche, certains éléments de menu standards de macOS (Quitter, Masquer, Services, Fenêtre, Aide…) sont fournis par le système et ne suivront la nouvelle langue qu'après avoir quitté puis rouvert Yee.",
            "prefs.restartLater": "OK, je redémarrerai plus tard",

            "about.title": "À propos de Yee",
            "about.tagline": "Un visualiseur d'images natif macOS, successeur spirituel de Xee³.",
            "about.license": "Sous licence MIT.",
            "about.github": "Voir sur GitHub",
        ]
    ]
}

func L(_ key: String) -> String { L10n.t(key) }
func L(_ key: String, _ arg: String) -> String { String(format: L10n.t(key), arg) }
