import SwiftUI
import AppKit

// MARK: - App Entry Notification
extension Notification.Name {
    static let openImageURL = Notification.Name("openImageURL")
}

// MARK: - Root View
struct ContentView: View {
    @StateObject private var store = ImageStore()
    @State private var zoomScale: CGFloat = 1.0
    @State private var isFullScreen: Bool = false
    @State private var toastMessage: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.images.isEmpty {
                DropZoneView()
            } else {
                ImageDisplayView(store: store, zoomScale: $zoomScale)
            }

            // Top HUD
            if !store.images.isEmpty {
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        LeftHUDView(store: store, isFullScreen: $isFullScreen, toast: showToast)
                            .padding(12)
                        Spacer()
                        RightHUDView(store: store, zoomScale: $zoomScale, toast: showToast)
                            .padding(12)
                    }
                    Spacer()
                    StatusBarView(store: store)
                }
            }

            // Toast
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
                        .padding(.bottom, 48)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: toastMessage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Invisible key catcher layered behind everything
        .background(
            KeyEventHandlingView(store: store, zoomScale: $zoomScale,
                                 isFullScreen: $isFullScreen, toast: showToast)
        )
        .onReceive(NotificationCenter.default.publisher(for: .openImageURL)) { notif in
            if let url = notif.object as? URL {
                store.openImage(url: url)
                zoomScale = 1.0
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
    }

    // MARK: helpers
    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                store.openImage(url: url)
                zoomScale = 1.0
            }
        }
        return true
    }
}

// MARK: - Drop Zone
struct DropZoneView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("Ouvrir une image")
                .font(.title2)
                .foregroundColor(.gray)
            Text("Glissez une image ici ou utilisez Fichier › Ouvrir")
                .font(.caption)
                .foregroundColor(Color.gray.opacity(0.7))
            Button("Ouvrir…") { openFilePanel() }
                .keyboardShortcut("o", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf]
        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .openImageURL, object: url)
        }
    }
}

// MARK: - Image Display (with GIF support)
struct ImageDisplayView: View {
    @ObservedObject var store: ImageStore
    @Binding var zoomScale: CGFloat
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            if let imgFile = store.currentImage {
                let ext = imgFile.url.pathExtension.lowercased()
                if ext == "gif" {
                    AnimatedGIFView(url: imgFile.url)
                        .rotationEffect(.degrees(store.rotationAngle))
                        .scaleEffect(zoomScale)
                        .offset(offset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .applyDragAndMagnify(zoomScale: $zoomScale, offset: $offset, dragStart: $dragStart)
                        .resetOnChange(of: store.currentIndex, zoomScale: $zoomScale, offset: $offset, dragStart: $dragStart)
                } else {
                    AsyncImageView(url: imgFile.url)
                        .rotationEffect(.degrees(store.rotationAngle))
                        .scaleEffect(zoomScale)
                        .offset(offset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .applyDragAndMagnify(zoomScale: $zoomScale, offset: $offset, dragStart: $dragStart)
                        .resetOnChange(of: store.currentIndex, zoomScale: $zoomScale, offset: $offset, dragStart: $dragStart)
                }
            }
        }
        .onChange(of: store.currentIndex) { _ in
            withAnimation(.none) {
                zoomScale = 1.0
                offset = .zero
                dragStart = .zero
            }
        }
    }
}

// Standard (non-GIF) image loader
struct AsyncImageView: View {
    let url: URL
    @State private var image: NSImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear { load() }
        .onChange(of: url) { _ in load() }
    }

    private func load() {
        image = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async { image = img }
        }
    }
}

// Animated GIF via NSImageView wrapped in NSViewRepresentable
struct AnimatedGIFView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyDown
        view.animates = true
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage(contentsOf: url)
    }
}

// MARK: - View modifiers helpers
extension View {
    func applyDragAndMagnify(zoomScale: Binding<CGFloat>, offset: Binding<CGSize>, dragStart: Binding<CGSize>) -> some View {
        self
            .gesture(DragGesture()
                .onChanged { v in
                    offset.wrappedValue = CGSize(
                        width:  dragStart.wrappedValue.width  + v.translation.width,
                        height: dragStart.wrappedValue.height + v.translation.height
                    )
                }
                .onEnded { _ in dragStart.wrappedValue = offset.wrappedValue }
            )
            .gesture(MagnificationGesture()
                .onChanged { v in zoomScale.wrappedValue = max(0.05, v) }
            )
    }

    func resetOnChange(of index: Int, zoomScale: Binding<CGFloat>, offset: Binding<CGSize>, dragStart: Binding<CGSize>) -> some View {
        self.onChange(of: index) { _ in
            zoomScale.wrappedValue = 1.0
            offset.wrappedValue    = .zero
            dragStart.wrappedValue = .zero
        }
    }
}

// MARK: - Left HUD (rotate, save, finder, editor, random, subfolders, fullscreen)
struct LeftHUDView: View {
    @ObservedObject var store: ImageStore
    @Binding var isFullScreen: Bool
    var toast: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Rotate left
            HUDButton(icon: "rotate.left") { store.rotateLeft() }
                .help("Rotation 90° à gauche (R)")

            // Save rotated
            HUDButton(icon: "square.and.arrow.down") {
                store.saveRotated { ok, msg in toast(msg) }
            }
            .help("Sauvegarder la rotation (⌘S)")

            Divider().frame(width: 24).background(Color.white.opacity(0.3))

            // Reveal in Finder
            HUDButton(icon: "folder") { store.revealInFinder() }
                .help("Afficher dans le Finder (⌘F)")

            // Open in default editor
            HUDButton(icon: "pencil") { store.openInDefaultEditor() }
                .help("Éditer avec l'app par défaut (⌘E)")

            Divider().frame(width: 24).background(Color.white.opacity(0.3))

            // Random
            HUDButton(icon: "shuffle") { store.goRandom() }
                .help("Image aléatoire (X)")

            // Include subfolders toggle
            Button(action: { store.includeSubfolders.toggle() }) {
                Image(systemName: store.includeSubfolders ? "folder.badge.plus" : "folder")
                    .foregroundColor(store.includeSubfolders ? .yellow : .white)
                    .frame(width: 28, height: 28)
                    .padding(4)
                    .background(store.includeSubfolders ? Color.yellow.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Inclure les sous-dossiers")

            Divider().frame(width: 24).background(Color.white.opacity(0.3))

            // Fullscreen toggle
            HUDButton(icon: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                toggleFullScreen()
            }
            .help("Plein écran (F)")
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    private func toggleFullScreen() {
        NSApp.mainWindow?.toggleFullScreen(nil)
        isFullScreen.toggle()
    }
}

// MARK: - Right HUD (zoom + sort)
struct RightHUDView: View {
    @ObservedObject var store: ImageStore
    @Binding var zoomScale: CGFloat
    var toast: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HUDButton(icon: "plus.magnifyingglass") { zoomScale = min(10, zoomScale + 0.15) }
                .help("Zoom + (=)")

            Text("\(Int(zoomScale * 100))%")
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(.white)
                .frame(minWidth: 36)

            HUDButton(icon: "minus.magnifyingglass") { zoomScale = max(0.05, zoomScale - 0.15) }
                .help("Zoom - (-)")

            HUDButton(icon: "1.square") { zoomScale = 1.0 }
                .help("Zoom 100% (0)")

            Divider().frame(width: 24).background(Color.white.opacity(0.3))

            // Sort menu
            Menu {
                ForEach(SortOrder.allCases) { order in
                    Button {
                        store.sortOrder = order
                    } label: {
                        Label(order.rawValue,
                              systemImage: store.sortOrder == order ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Trier par…")
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

// MARK: - Status bar
struct StatusBarView: View {
    @ObservedObject var store: ImageStore

    var body: some View {
        HStack(spacing: 8) {
            if let img = store.currentImage {
                if store.includeSubfolders {
                    Text(img.url.deletingLastPathComponent().lastPathComponent + "/" + img.name)
                        .lineLimit(1).truncationMode(.middle)
                } else {
                    Text(img.name)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text("\(store.currentIndex + 1) / \(store.images.count)")
                Spacer()
                Text(formatSize(img.fileSize))
                if store.rotationAngle.truncatingRemainder(dividingBy: 360) != 0 {
                    Image(systemName: "rotate.left.fill").foregroundColor(.yellow)
                }
            }
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.55))
    }

    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.0f Ko", kb) }
        return String(format: "%.1f Mo", kb / 1024)
    }
}

// MARK: - Reusable HUD button
struct HUDButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(HUDButtonStyle())
    }
}

struct HUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background(configuration.isPressed ? Color.white.opacity(0.2) : Color.clear)
            .cornerRadius(6)
    }
}

// MARK: - Keyboard handling
struct KeyEventHandlingView: NSViewRepresentable {
    var store: ImageStore
    @Binding var zoomScale: CGFloat
    @Binding var isFullScreen: Bool
    var toast: (String) -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let v = KeyCatcherView()
        v.store     = store
        v.zoomGet   = { self.zoomScale }
        v.zoomSet   = { self.zoomScale = $0 }
        v.fsToggle  = {
            NSApp.mainWindow?.toggleFullScreen(nil)
            self.isFullScreen.toggle()
        }
        v.toastFn   = toast
        return v
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.store   = store
        nsView.toastFn = toast
    }
}

class KeyCatcherView: NSView {
    var store: ImageStore?
    var zoomGet: (() -> CGFloat)?
    var zoomSet: ((CGFloat) -> Void)?
    var fsToggle: (() -> Void)?
    var toastFn: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let store = store else { return }
        let zoom = zoomGet?() ?? 1.0

        // Handle modifier combos first
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "s":
                store.saveRotated { _, msg in self.toastFn?(msg) }
                return
            case "f":
                store.revealInFinder(); return
            case "e":
                store.openInDefaultEditor(); return
            default: break
            }
        }

        switch event.keyCode {
        case 116: store.goPrevious()                                    // Page Up
        case 121: store.goNext()                                        // Page Down
        case 115: store.goFirst()                                       // Home
        case 24:  zoomSet?(min(10.0, zoom + 0.15))                     // = / +
        case 27:  zoomSet?(max(0.05, zoom - 0.15))                     // -
        case 29:  zoomSet?(1.0)                                        // 0
        case 15:  store.rotateLeft()                                    // R
        case 7:   store.goRandom()                                      // X
        case 3:   fsToggle?()                                           // F
        default:
            // Also catch character-based
            switch event.charactersIgnoringModifiers {
            case "r","R": store.rotateLeft()
            case "x","X": store.goRandom()
            case "f","F": fsToggle?()
            default: super.keyDown(with: event)
            }
        }
    }
}
