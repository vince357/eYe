import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Yee")
                    .font(.largeTitle.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("help.formatsTitle")).font(.headline)
                    Text(L("help.formatsList"))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("help.shortcutsTitle")).font(.headline)
                    shortcutsTable
                }
            }
            .padding(28)
            .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    private struct ShortcutRow: Identifiable {
        let id = UUID()
        let key: String
        let description: String
    }

    private var shortcutsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(shortcutRows) { row in
                HStack {
                    Text(row.key)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 140, alignment: .leading)
                    Text(row.description)
                    Spacer()
                }
            }
        }
    }

    private var shortcutRows: [ShortcutRow] {
        [
            ShortcutRow(key: "⌘O", description: L("help.sc.open")),
            ShortcutRow(key: "⌘L", description: L("help.sc.reveal")),
            ShortcutRow(key: "⌘R", description: L("help.sc.rotate")),
            ShortcutRow(key: "Delete", description: L("help.sc.delete")),
            ShortcutRow(key: "⌘F", description: L("help.sc.fullscreen")),
            ShortcutRow(key: "*", description: L("help.sc.fit")),
            ShortcutRow(key: "0", description: L("help.sc.zoom100")),
            ShortcutRow(key: "+ / −", description: L("help.sc.zoom")),
            ShortcutRow(key: "Shift + (+/−)", description: L("help.sc.zoomFine")),
            ShortcutRow(key: "← → ↑ ↓", description: L("help.sc.pan")),
            ShortcutRow(key: "Page Up/Down", description: L("help.sc.prevNext")),
            ShortcutRow(key: "Home / End", description: L("help.sc.firstLast")),
            ShortcutRow(key: "R", description: L("help.sc.random")),
            ShortcutRow(key: "Shift + R", description: L("help.sc.randomBack")),
            ShortcutRow(key: "Space", description: L("help.sc.gifPause")),
            ShortcutRow(key: "Return", description: L("help.sc.gifResume")),
            ShortcutRow(key: "⌘,", description: L("help.sc.prefs")),
        ]
    }
}
