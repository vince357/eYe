import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var store = MediaStore()
    @ObservedObject private var settings = AppSettings.shared

    @State private var zoomScale: CGFloat = 0
    @State private var imagePixelSize: CGSize? = nil
    @State private var panOffset: CGSize = .zero
    @State private var nudgeToken: Int = 0
    @State private var nudgeDelta: CGSize = .zero
    @State private var gifPaused: Bool = false
    @State private var gifStepToken: Int = 0
    @State private var toastMessage: String? = nil
    @State private var showDeleteConfirm = false
    @State private var hasOpenedAnything = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.files.isEmpty {
                if hasOpenedAnything && store.lastOpenWasEmpty {
                    EmptyFolderView()
                } else {
                    DropZoneView()
                }
            } else {
                ImageDisplayView(store: store,
                                  zoomScale: $zoomScale,
                                  imagePixelSize: $imagePixelSize,
                                  panOffset: $panOffset,
                                  gifPaused: $gifPaused,
                                  stepRequestToken: gifStepToken,
                                  nudgeToken: nudgeToken,
                                  nudgeDelta: nudgeDelta)
            }

            VStack {
                Spacer()
                StatusBarView(store: store,
                              imagePixelSize: imagePixelSize,
                              displayedZoomPercent: Int(round(zoomScale > 0 ? zoomScale * 100 : 100)))
            }

            if let msg = toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(10)
                        .padding(.bottom, settings.showStatusBar ? 40 : 16)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyCatcher(actions: keyActions))
        .onAppear {
            consumePendingURLIfNeeded()
            for attempt in 1...6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.3) {
                    consumePendingURLIfNeeded()
                }
            }
        }
        .onChange(of: store.currentIndex) { _ in
            if settings.alwaysFitOnOpen { zoomScale = 0 }
            panOffset = .zero
            gifPaused = false
            updateWindowTitle()
        }
        .onChange(of: store.currentFolderURL) { _ in updateWindowTitle() }
        .onReceive(NotificationCenter.default.publisher(for: .openImageURL)) { notif in
            if let url = notif.object as? URL {
                AppDelegate.pendingURL = nil
                hasOpenedAnything = true
                store.openFile(url: url)
                zoomScale = 0; panOffset = .zero
                updateWindowTitle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolderURL)) { notif in
            if let url = notif.object as? URL {
                AppDelegate.pendingURL = nil
                hasOpenedAnything = true
                store.openFolder(url: url)
                zoomScale = 0; panOffset = .zero
                updateWindowTitle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .yeeMenuAction)) { notif in
            if let action = notif.object as? YeeMenuAction { handle(action) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .yeeSortChanged)) { _ in
            store.reload()
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .alert(L("alert.deleteTitle"), isPresented: $showDeleteConfirm) {
            Button(L("alert.cancel"), role: .cancel) {}
            Button(L("alert.moveToTrash"), role: .destructive) {
                store.deleteCurrentFile { _, msg in showToast(msg) }
            }
        } message: {
            Text(store.currentFile?.name ?? "")
        }
    }

    private func updateWindowTitle() {
        DispatchQueue.main.async { NSApp.mainWindow?.title = store.currentFile?.name ?? "Yee" }
    }

    private func consumePendingURLIfNeeded() {
        guard let url = AppDelegate.pendingURL else { return }
        AppDelegate.pendingURL = nil
        hasOpenedAnything = true
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue { store.openFolder(url: url) } else { store.openFile(url: url) }
        zoomScale = 0; panOffset = .zero
        updateWindowTitle()
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toastMessage = nil } }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                hasOpenedAnything = true
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                if isDir.boolValue { store.openFolder(url: url) } else { store.openFile(url: url) }
                zoomScale = 0; panOffset = .zero
                updateWindowTitle()
            }
        }
        return true
    }

    private func handle(_ action: YeeMenuAction) {
        switch action {
        case .openFile: presentOpenPanel()
        case .revealInFinder: store.revealInFinder()
        case .deleteCurrent: if store.currentFile != nil { showDeleteConfirm = true }
        case .rotateCW: store.rotateCW()
        case .zoomIn: setZoom(currentZoomValue() + 0.25)
        case .zoomOut: setZoom(currentZoomValue() - 0.25)
        case .zoomReset: setZoom(1.0)
        case .fitOnScreen: zoomScale = 0; panOffset = .zero
        case .toggleFullScreen: NSApp.mainWindow?.toggleFullScreen(nil)
        case .toggleStatusBar: settings.showStatusBar.toggle(); settings.save()
        case .nextFile: store.goNext()
        case .previousFile: store.goPrevious()
        case .firstFile: store.goFirst()
        case .lastFile: store.goLast()
        case .randomFile: store.goRandom()
        case .backFromRandom: store.goBackFromRandom()
        }
    }

    private func currentZoomValue() -> CGFloat { zoomScale > 0 ? zoomScale : 1.0 }
    private func setZoom(_ value: CGFloat) { zoomScale = max(0.05, min(20, value)) }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            hasOpenedAnything = true
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue { store.openFolder(url: url) } else { store.openFile(url: url) }
            zoomScale = 0; panOffset = .zero
            updateWindowTitle()
        }
    }

    // MARK: - Low-level keyboard: arrows (pan/nav), space (GIF), enter (resume),
    // delete, and symbol-based zoom keys (character-matched, so it works
    // correctly on AZERTY and with the numeric keypad — the previous
    // hardware-keyCode approach didn't account for ISO/French key layouts).
    private var keyActions: KeyActionSet {
        KeyActionSet(
            onZoomIn: { fine in setZoom(currentZoomValue() + (fine ? 0.1 : 0.25)) },
            onZoomOut: { fine in setZoom(currentZoomValue() - (fine ? 0.1 : 0.25)) },
            onZoomReset: { zoomScale = 1.0 },
            onFitResetKey: { zoomScale = 0; panOffset = .zero },
            onSpace: {
                if !gifPaused { gifPaused = true } else { gifStepToken += 1 }
            },
            onEnter: {
                if gifPaused { gifPaused = false }
            },
            onArrow: { direction in
                if isZoomedBeyond() {
                    let delta: CGFloat = 30
                    switch direction {
                    case .left:  nudgeDelta = CGSize(width: delta, height: 0)
                    case .right: nudgeDelta = CGSize(width: -delta, height: 0)
                    case .up:    nudgeDelta = CGSize(width: 0, height: delta)
                    case .down:  nudgeDelta = CGSize(width: 0, height: -delta)
                    }
                    nudgeToken += 1
                } else {
                    switch direction {
                    case .left:  store.goPrevious()
                    case .right: store.goNext()
                    default: break
                    }
                }
            },
            onDelete: { if store.currentFile != nil { showDeleteConfirm = true } }
        )
    }

    private func isZoomedBeyond() -> Bool { zoomScale > 1.0 }
}

// MARK: - Drop zone (nothing opened yet)
struct DropZoneView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64)).foregroundColor(.gray)
            Text(L("dropzone.title")).font(.title2).foregroundColor(.gray)
            Text(L("dropzone.subtitle"))
                .font(.caption).foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Empty folder (opened, but no supported media)
struct EmptyFolderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 64)).foregroundColor(.gray)
            Text(L("dropzone.empty.title")).font(.title2).foregroundColor(.gray)
            Text(L("dropzone.empty.subtitle"))
                .font(.caption).foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
    }
}

// MARK: - Key action bundle
enum ArrowDirection { case left, right, up, down }

struct KeyActionSet {
    let onZoomIn: (Bool) -> Void
    let onZoomOut: (Bool) -> Void
    let onZoomReset: () -> Void
    let onFitResetKey: () -> Void
    let onSpace: () -> Void
    let onEnter: () -> Void
    let onArrow: (ArrowDirection) -> Void
    let onDelete: () -> Void
}

struct KeyCatcher: NSViewRepresentable {
    let actions: KeyActionSet
    func makeNSView(context: Context) -> KeyCatcherNSView {
        let v = KeyCatcherNSView(); v.actions = actions; return v
    }
    func updateNSView(_ nsView: KeyCatcherNSView, context: Context) { nsView.actions = actions }
}

class KeyCatcherNSView: NSView {
    var actions: KeyActionSet?

    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let a = actions else { return }
        let cmd = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)

        if !cmd {
            // Symbol keys matched by resolved character (layout + numpad safe)
            if let chars = event.characters {
                if chars == "+" || chars == "=" { a.onZoomIn(shift); return }
                if chars == "-" { a.onZoomOut(shift); return }
                if chars == "_" { a.onZoomOut(true); return }
                if chars == "*" { a.onFitResetKey(); return }
            }
        }

        switch event.keyCode {
        case 29: if !cmd { a.onZoomReset(); return }          // '0' (digit row)
        case 82: if !cmd { a.onZoomReset(); return }          // numpad 0
        case 49: a.onSpace(); return                          // space
        case 36: a.onEnter(); return                          // return/enter
        case 123: a.onArrow(.left); return
        case 124: a.onArrow(.right); return
        case 126: a.onArrow(.up); return
        case 125: a.onArrow(.down); return
        case 51, 117: a.onDelete(); return                    // backspace / forward delete
        default:
            super.keyDown(with: event)
        }
    }
}
