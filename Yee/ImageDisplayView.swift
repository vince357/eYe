import SwiftUI
import AppKit
import AVKit

struct ImageDisplayView: View {
    @ObservedObject var store: MediaStore
    @ObservedObject var settings = AppSettings.shared
    @Binding var zoomScale: CGFloat          // 0 = auto-fit sentinel
    @Binding var imagePixelSize: CGSize?
    @Binding var panOffset: CGSize
    @Binding var gifPaused: Bool
    let stepRequestToken: Int
    let nudgeToken: Int
    let nudgeDelta: CGSize

    var body: some View {
        GeometryReader { geo in
            if let file = store.currentFile {
                let ext = file.url.pathExtension.lowercased()
                let scale = computeScale(containerSize: geo.size)
                let scaledSize = CGSize(width: (imagePixelSize?.width ?? geo.size.width) * scale,
                                        height: (imagePixelSize?.height ?? geo.size.height) * scale)

                ZStack {
                    Group {
                        if ext == "gif" {
                            AnimatedGIFView(url: file.url, naturalSize: $imagePixelSize,
                                            paused: $gifPaused, stepToken: stepRequestToken)
                        } else if MediaStore.videoExtensions.contains(ext) {
                            VideoPreviewView(url: file.url)
                        } else {
                            StaticImageView(url: file.url, naturalSize: $imagePixelSize)
                        }
                    }
                    .rotationEffect(.degrees(Double(store.pendingRotation)))
                    .frame(width: scaledSize.width, height: scaledSize.height)
                    .offset(panOffset)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in
                            let start = dragStartOffset ?? panOffset
                            if dragStartOffset == nil { dragStartOffset = panOffset }
                            let proposed = CGSize(width: start.width + v.translation.width,
                                                  height: start.height + v.translation.height)
                            panOffset = clamp(proposed, scaledSize: scaledSize, containerSize: geo.size)
                        }
                        .onEnded { _ in dragStartOffset = nil }
                )
                // Identity keyed on the file's URL: forces SwiftUI to fully
                // discard and recreate this subtree (and its @State) when the
                // current file changes, instead of potentially reusing stale
                // state from the previous image while an async load is still
                // in flight. This is what fixed the name/image mismatch bug.
                .id(file.url)
                .onChange(of: store.currentIndex) { _ in panOffset = .zero }
                .onChange(of: nudgeToken) { _ in
                    let proposed = CGSize(width: panOffset.width + nudgeDelta.width,
                                          height: panOffset.height + nudgeDelta.height)
                    panOffset = clamp(proposed, scaledSize: scaledSize, containerSize: geo.size)
                }
            } else {
                Color.clear
            }
        }
    }

    @State private var dragStartOffset: CGSize? = nil

    /// Keeps the image edges from ever revealing empty background beyond
    /// what panning should expose: clamps so the visible image always fully
    /// covers the container on any axis where it's larger than the container.
    private func clamp(_ offset: CGSize, scaledSize: CGSize, containerSize: CGSize) -> CGSize {
        var result = offset
        let maxX = max(0, (scaledSize.width - containerSize.width) / 2)
        let maxY = max(0, (scaledSize.height - containerSize.height) / 2)
        result.width = min(max(result.width, -maxX), maxX)
        result.height = min(max(result.height, -maxY), maxY)
        return result
    }

    private func computeScale(containerSize: CGSize) -> CGFloat {
        guard let nat = imagePixelSize, nat.width > 0, nat.height > 0 else {
            return zoomScale > 0 ? zoomScale : 1.0
        }
        if zoomScale > 0 { return zoomScale }
        return Self.fitScale(containerSize: containerSize, natural: nat, settings: settings)
    }

    static func fitScale(containerSize: CGSize, natural: CGSize, settings: AppSettings) -> CGFloat {
        let widthRatio  = containerSize.width  / natural.width
        let heightRatio = containerSize.height / natural.height
        var scale: CGFloat = 1.0
        var applied = false

        // "Stretch" is applied first, then clamped by "shrink" on the OTHER
        // axis if it would otherwise overflow — this prevents cropping when
        // e.g. "stretch horizontal" is on but the resulting height would
        // exceed the window (per user feedback: never crop, use letterboxing
        // instead).
        if settings.stretchHorizontal && natural.width < containerSize.width {
            scale = max(scale, widthRatio); applied = true
        }
        if settings.stretchVertical && natural.height < containerSize.height {
            scale = max(scale, heightRatio); applied = true
        }
        if settings.shrinkHorizontal && natural.width * scale > containerSize.width {
            scale = min(scale, widthRatio)
        }
        if settings.shrinkVertical && natural.height * scale > containerSize.height {
            scale = min(scale, heightRatio)
        }
        if settings.shrinkHorizontal && natural.width > containerSize.width && !applied {
            scale = min(scale, widthRatio); applied = true
        }
        if settings.shrinkVertical && natural.height > containerSize.height && !applied {
            scale = min(scale, heightRatio); applied = true
        }
        if !applied {
            scale = min(widthRatio, heightRatio)
        }
        return scale
    }
}

// MARK: - Static image (max quality, incl. upscaling)
struct StaticImageView: View {
    let url: URL
    @Binding var naturalSize: CGSize?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        let requestedURL = url
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = NSImage(contentsOf: requestedURL) else { return }
            let size: CGSize
            if let best = img.representations.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }) {
                size = CGSize(width: best.pixelsWide, height: best.pixelsHigh)
            } else {
                size = img.size
            }
            DispatchQueue.main.async {
                // Guard against a stale async result arriving after the user
                // has already navigated away from this file.
                guard requestedURL == url else { return }
                image = img
                naturalSize = size
            }
        }
    }
}

// MARK: - Animated GIF with loop control + frame stepping
struct AnimatedGIFView: NSViewRepresentable {
    let url: URL
    @Binding var naturalSize: CGSize?
    @Binding var paused: Bool
    let stepToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleAxesIndependently
        view.animates = !paused
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            let img = NSImage(contentsOf: url)
            nsView.image = img
            DispatchQueue.main.async { naturalSize = img?.size }
        }
        nsView.animates = !paused

        if paused, context.coordinator.lastStepToken != stepToken {
            context.coordinator.lastStepToken = stepToken
            context.coordinator.stepFrame(on: nsView, url: url)
        }
    }

    class Coordinator {
        var loadedURL: URL?
        var frames: [NSImage] = []
        var frameIndex: Int = 0
        var lastStepToken: Int = 0

        func stepFrame(on view: NSImageView, url: URL) {
            if frames.isEmpty {
                guard let data = try? Data(contentsOf: url),
                      let src = CGImageSourceCreateWithData(data as CFData, nil) else { return }
                let count = CGImageSourceGetCount(src)
                frames = (0..<count).compactMap { i in
                    CGImageSourceCreateImageAtIndex(src, i, nil).map { NSImage(cgImage: $0, size: .zero) }
                }
                frameIndex = 0
            }
            guard !frames.isEmpty else { return }
            frameIndex = (frameIndex + 1) % frames.count
            view.image = frames[frameIndex]
        }
    }
}

// MARK: - Video preview
struct VideoPreviewView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = AVPlayer(url: url)
        v.controlsStyle = .floating
        return v
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if (nsView.player?.currentItem?.asset as? AVURLAsset)?.url != url {
            nsView.player = AVPlayer(url: url)
        }
    }
}
