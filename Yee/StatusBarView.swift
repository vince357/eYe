import SwiftUI

struct StatusBarView: View {
    @ObservedObject var store: MediaStore
    @ObservedObject var settings = AppSettings.shared
    let imagePixelSize: CGSize?
    let displayedZoomPercent: Int

    var body: some View {
        if settings.showStatusBar, let file = store.currentFile {
            HStack(spacing: 10) {
                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if let size = imagePixelSize {
                    Text("\(Int(size.width)) × \(Int(size.height)) px")
                }

                Text(formatSize(file.fileSize))

                Text("\(displayedZoomPercent)%")
                    .monospacedDigit()

                Divider().frame(height: 12)

                Text("\(store.currentIndex + 1) / \(store.files.count)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.75))
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let unitKB = AppSettings.shared.language == .french ? "Ko" : "KB"
        let unitMB = AppSettings.shared.language == .french ? "Mo" : "MB"
        if kb < 1024 { return String(format: "%.0f %@", kb, unitKB) }
        return String(format: "%.1f %@", kb / 1024, unitMB)
    }
}
