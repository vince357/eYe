import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var store = MediaStore()
    @ObservedObject private var settings = AppSettings.shared

    @State private var zoomScale: CGFloat = 0   // 0 = auto-fit sentinel; >0 = explicit factor (1.0 = 100%)
    @State private var imagePixelSize: CGSize? = nil
    @State private var panOffset: CGSize = .zero
    @State private var gifPaused: Bool = false
    @State private var gifStepToken: Int = 0
    @State private var toastMessage: String? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.files.isEmpty {
                DropZoneView()
            } else {
                ImageDisplayView(store: store,
                                  zoomScale: $zoomScale,
                                  imagePixelSize: $imagePixelSize,
                                  panOffset: $panOffset,
                                  gifPaused: $gifPaused,
                                  stepRequestToken: gifStepToken)
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
        .onChange(of: store.currentIndex) { _ in
            if settings.alwaysFitOnOpen { zoomScale = 0 }
            panOffset = .zero
            gifPaused = false
            updateWindowTitle()
        }
        .onChange(of: store.currentFolderURL) { _ in updateWindowTitle() }
        .onReceive(NotificationCenter.default.publisher(for: .openImageURL)) { notif in
            if let url = notif.object as? URL {
                store.openFile(url: url)
                zoomScale = 0; panOffset = .zero
                updateWindowTitle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolderURL)) { notif in
            if let url = notif.object as? URL {
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
        .alert("Supprimer ce fichier ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Déplacer vers la Corbeille", role: .destructive) {
                store.deleteCurrentFile { _, msg in showToast(msg) }
            }
        } message: {
            Text(store.currentFile?.name ?? "")
        }
    }

    // MARK: - Window title
    private func updateWindowTitle() {
        DispatchQueue.main.async { NSApp.mainWindow?.title = store.currentFile?.name ?? "Yee" }
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toastMessage = nil } }
    }

    // MARK: - Drop (files/folders in)
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                if isDir.boolValue { store.openFolder(url: url) } else { store.openFile(url: url) }
                zoomScale = 0; panOffset = .zero
                updateWindowTitle()
            }
        }
        return true
    }

    // MARK: - Menu actions
    private func handle(_ action: YeeMenuAction) {
        switch action {
        case .openFile: presentOpenPanel()
        case .revealInFinder: store.revealInFinder()
        case .deleteCurrent: if store.currentFile != nil { showDeleteConfirm = true }
        case .rotateCW:
            store.rotateCW()
        case .saveLossless:
            store.saveLosslessly { _, msg in showToast(msg) }
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
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue { store.openFolder(url: url) } else { store.openFile(url: url) }
            zoomScale = 0; panOffset = .zero
            updateWindowTitle()
        }
    }

    // MARK: - Keyboard actions (keyCode-based, layout-independent — fixes AZERTY issues)
    private var keyActions: KeyActionSet {
        KeyActionSet(
            onZoomKey: { keyCode, shiftHeld in
                let step: CGFloat = shiftHeld ? 0.1 : 0.25
                if keyCode == 24 { setZoom(currentZoomValue() + step) }       // '+/=' physical key
                else if keyCode == 27 { setZoom(currentZoomValue() - step) } // '-' physical key
            },
            onZoomResetKey: { zoomScale = 1.0 },                             // '0'
            onFitResetKey: { zoomScale = 0; panOffset = .zero },             // '*' or '/'
            onSpace: {
                if !gifPaused { gifPaused = true }
                else { gifStepToken += 1 }
            },
            onArrow: { direction in
                if isZoomedBeyondContainer() {
                    let delta: CGFloat = 30
                    switch direction {
                    case .left:  panOffset.width += delta
                    case .right: panOffset.width -= delta
                    case .up:    panOffset.height += delta
                    case .down:  panOffset.height -= delta
                    }
                } else {
                    switch direction {
                    case .left:  store.goPrevious()
                    case .right: store.goNext()
                    default: break
                    }
                }
            },
            onPageUp: { store.goPrevious() },
            onPageDown: { store.goNext() },
            onShiftPageUp: { store.goFirst() },
            onShiftPageDown: { store.goLast() },
            onHome: { store.goFirst() },
            onEnd: { store.goLast() },
            onDelete: { if store.currentFile != nil { showDeleteConfirm = true } },
            onRandom: { store.goRandom() },
            onShiftRandomBack: { store.goBackFromRandom() }
        )
    }

    private func isZoomedBeyondContainer() -> Bool {
        // Best-effort: only allow panning when an explicit zoom > fit is active
        zoomScale > 0 && zoomScale > 1.0
    }
}

// MARK: - Drop zone
struct DropZoneView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64)).foregroundColor(.gray)
            Text("Ouvrir une image ou un dossier").font(.title2).foregroundColor(.gray)
            Text("Glissez un fichier ou un dossier ici, ou utilisez Fichier › Ouvrir")
                .font(.caption).foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Key action bundle
enum ArrowDirection { case left, right, up, down }

struct KeyActionSet {
    let onZoomKey: (UInt16, Bool) -> Void
    let onZoomResetKey: () -> Void
    let onFitResetKey: () -> Void
    let onSpace: () -> Void
    let onArrow: (ArrowDirection) -> Void
    let onPageUp: () -> Void
    let onPageDown: () -> Void
    let onShiftPageUp: () -> Void
    let onShiftPageDown: () -> Void
    let onHome: () -> Void
    let onEnd: () -> Void
    let onDelete: () -> Void
    let onRandom: () -> Void
    let onShiftRandomBack: () -> Void
}

struct KeyCatcher: NSViewRepresentable {
    let actions: KeyActionSet

    func makeNSView(context: Context) -> KeyCatcherNSView {
        let v = KeyCatcherNSView()
        v.actions = actions
        return v
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
        let shift = event.modifierFlags.contains(.shift)
        let cmd = event.modifierFlags.contains(.command)

        // Physical (hardware) key codes — identical across AZERTY/QWERTY/etc.
        switch event.keyCode {
        case 24, 27:                              // '=' / '-' physical keys → zoom
            a.onZoomKey(event.keyCode, shift); return
        case 29:                                   // '0'
            a.onZoomResetKey(); return
        case 28, 44:                               // '*' (shift+8) or '/'
            a.onFitResetKey(); return
        case 49:                                   // space
            a.onSpace(); return
        case 123: a.onArrow(.left); return
        case 124: a.onArrow(.right); return
        case 126: a.onArrow(.up); return
        case 125: a.onArrow(.down); return
        case 116: shift ? a.onShiftPageUp() : a.onPageUp(); return
        case 121: shift ? a.onShiftPageDown() : a.onPageDown(); return
        case 115: a.onHome(); return
        case 119: a.onEnd(); return
        case 51, 117: a.onDelete(); return         // Backspace / Forward delete
        case 15:                                    // 'R' physical key
            if !cmd { shift ? a.onShiftRandomBack() : a.onRandom() }
            return
        default:
            super.keyDown(with: event)
        }
    }
}
