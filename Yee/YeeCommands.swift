import SwiftUI
import AppKit

enum YeeMenuAction {
    case openFile
    case revealInFinder
    case deleteCurrent
    case rotateCW
    case zoomIn, zoomOut, zoomReset, fitOnScreen
    case toggleFullScreen
    case toggleStatusBar
    case nextFile, previousFile, firstFile, lastFile
    case randomFile, backFromRandom
}

struct YeeCommands: Commands {
    @ObservedObject private var settings = AppSettings.shared

    var body: some Commands {

        CommandGroup(replacing: .appInfo) {
            Button(L("about.title")) { showAboutPanel() }
        }

        CommandGroup(replacing: .newItem) {
            Button(L("menu.open")) { post(.openFile) }
                .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button(L("menu.revealInFinder")) { post(.revealInFinder) }
                .keyboardShortcut("l", modifiers: .command)

            Divider()

            Button(L("menu.rotate")) { post(.rotateCW) }
                .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button(L("menu.delete")) { post(.deleteCurrent) }
                .keyboardShortcut(.delete, modifiers: [])
        }

        CommandMenu(L("menu.view")) {
            Button(L("menu.fullscreen")) { post(.toggleFullScreen) }
                .keyboardShortcut("f", modifiers: .command)

            Divider()

            Button(L("menu.fitOnScreen")) { post(.fitOnScreen) }
            Button(L("menu.zoom100")) { post(.zoomReset) }
            Button(L("menu.zoomIn")) { post(.zoomIn) }
            Button(L("menu.zoomOut")) { post(.zoomOut) }

            Divider()

            Menu(L("menu.fitOptions")) {
                Toggle(L("menu.shrinkH"), isOn: $settings.shrinkHorizontal)
                Toggle(L("menu.shrinkV"), isOn: $settings.shrinkVertical)
                Divider()
                Toggle(L("menu.stretchH"), isOn: $settings.stretchHorizontal)
                Toggle(L("menu.stretchV"), isOn: $settings.stretchVertical)
            }
            Toggle(L("menu.alwaysFit"), isOn: $settings.alwaysFitOnOpen)

            Divider()

            Toggle(L("menu.showStatusBar"), isOn: $settings.showStatusBar)

            Divider()

            Menu(L("menu.sortBy")) {
                ForEach(SortKey.allCases) { key in
                    Button {
                        settings.sortKey = key
                        settings.save()
                        NotificationCenter.default.post(name: .yeeSortChanged, object: nil)
                    } label: {
                        HStack { Text(key.label); if settings.sortKey == key { Image(systemName: "checkmark") } }
                    }
                }
                Divider()
                Button {
                    settings.sortDirection = settings.sortDirection == .ascending ? .descending : .ascending
                    settings.save()
                    NotificationCenter.default.post(name: .yeeSortChanged, object: nil)
                } label: {
                    Text(settings.sortDirection == .ascending ? L("menu.sortAscending") : L("menu.sortDescending"))
                }
            }

            Toggle(L("menu.includeSubfolders"), isOn: $settings.includeSubfolders)
                .onChange(of: settings.includeSubfolders) { _ in
                    settings.save()
                    NotificationCenter.default.post(name: .yeeSortChanged, object: nil)
                }
        }

        CommandMenu(L("menu.navigation")) {
            Button(L("menu.next")) { post(.nextFile) }
                .keyboardShortcut(.pageDown, modifiers: [])
            Button(L("menu.previous")) { post(.previousFile) }
                .keyboardShortcut(.pageUp, modifiers: [])
            Divider()
            Button(L("menu.first")) { post(.firstFile) }
                .keyboardShortcut(.home, modifiers: [])
            Button(L("menu.last")) { post(.lastFile) }
                .keyboardShortcut(.end, modifiers: [])
            Divider()
            Button(L("menu.random")) { post(.randomFile) }
                .keyboardShortcut("r", modifiers: [])
            Button(L("menu.backFromRandom")) { post(.backFromRandom) }
                .keyboardShortcut("r", modifiers: .shift)
        }
    }

    private func post(_ action: YeeMenuAction) {
        NotificationCenter.default.post(name: .yeeMenuAction, object: action)
    }

    private func showAboutPanel() {
        let credits = NSMutableAttributedString(string: L("about.tagline") + "\n\n" + L("about.license") + "\n")
        let linkRange: NSRange
        let linkText = L("about.github")
        let full = NSMutableAttributedString(attributedString: credits)
        full.append(NSAttributedString(string: "\n"))
        let linkStart = full.length
        full.append(NSAttributedString(string: linkText))
        linkRange = NSRange(location: linkStart, length: linkText.count)
        full.addAttribute(.link, value: "https://github.com/vince357/eYe", range: linkRange)
        full.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: full.length))

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: full,
            NSApplication.AboutPanelOptionKey(rawValue: "ApplicationName"): "Yee",
            .applicationVersion: "1.0"
        ])
    }
}
