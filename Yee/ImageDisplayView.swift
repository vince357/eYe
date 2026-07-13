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
    let stepRequestToken: Int                // increments to request one GIF frame step

    var body: some View {
        GeometryReader { geo in
            if let file = store.currentFile {
                let ext = file.url.pathExtension.lowercased()
                let scale = computeScale(containerSize: geo.size)

                Group {
                    if ext == "gif" {
                        AnimatedGIFView(url: file.url,
                                        naturalSize: $imagePixelSize,
                                        paused: $gifPaused,
                                        stepToken: stepRequestToken)
                    } else if MediaStore.videoExtensions.contains(ext) {
                        VideoPreviewView(url: file.url)
                    } else {
                        StaticImageView(url: file.url, naturalSize: $imagePixelSize)
                    }
                }
                .rotationEffect(.degrees(Double(store.pendingRotation)))
                .frame(width: (imagePixelSize?.width ?? geo.size.width) * scale,
                       height: (imagePixelSize?.height ?? geo.size.height) * scale)
                .position(x: geo.size.width / 2 + panOffset.width,
                          y: geo.size.height / 2 + panOffset.height)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { v in
                            guard isImageLargerThanContainer(containerSize: geo.size, scale: scale) else { return }
                            panOffset = CGSize(width: panOffset.width + v.translation.width * 0.15,
                                                height: panOffset.height + v.translation.height * 0.15)
                        }
                )
                .onDrag {
                    NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
                }
                .onChange(of: store.currentIndex) { _ in panOffset = .zero }
            }
        }
    }

    private func isImageLargerThanContainer(containerSize: CGSize, scale: CGFloat) -> Bool {
        guard let nat = imagePixelSize else { return false }
        return nat.width * scale > containerSize.width || nat.height * scale > containerSize.height
    }

    private func computeScale(containerSize: CGSize) -> CGFloat {
        guard let nat = imagePixelSize, nat.width > 0, nat.height > 0 else {
            return zoomScale > 0 ? zoomScale : 1.0
        }
        if zoomScale > 0 { return zoomScale }
        return fitScale(containerSize: containerSize, natural: nat)
    }

    // Exposed so ContentView can compute the same fit scale for the status bar / reset logic
    static func fitScale(containerSize: CGSize, natural: CGSize, settings: AppSettings) -> CGFloat {
        let widthRatio  = containerSize.width  / natural.width
        let heightRatio = containerSize.height / natural.height
        var scale: CGFloat = 1.0
        var applied = false

        if settings.shrinkHorizontal && natural.width > containerSize.width {
            scale = min(scale, widthRatio); applied = true
        }
        if settings.shrinkVertical && natural.height > containerSize.height {
            scale = min(scale, heightRatio); applied = true
        }
        if settings.stretchHorizontal && natural.width < containerSize.width {
            scale = max(scale, widthRatio); applied = true
        }
        if settings.stretchVertical && natural.height < containerSize.height {
            scale = max(scale, heightRatio); applied = true
        }
        if !applied {
            scale = min(widthRatio, heightRatio)
        }
        return scale
    }

    private func fitScale(containerSize: CGSize, natural: CGSize) -> CGFloat {
        Self.fitScale(containerSize: containerSize, natural: natural, settings: settings)
    }
}

// MARK: - Static image (max quality rendering, incl. upscaling)
struct StaticImageView: View {
    let url: URL
    @Binding var naturalSize: CGSize?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)          // best available interpolation for upscaling
                    .antialiased(true)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear { load() }
        .onChange(of: url) { _ in load() }
    }

    private func load() {
        image = nil
        naturalSize = nil
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = NSImage(contentsOf: url) else { return }
            // Force use of the largest available representation (important for RAW/multi-rep formats)
            if let best = img.representations.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }) {
                let size = CGSize(width: best.pixelsWide, height: best.pixelsHigh)
                DispatchQueue.main.async {
                    image = img
                    naturalSize = size
                }
            } else {
                DispatchQueue.main.async {
                    image = img
                    naturalSize = img.size
                }
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
            guard let data = try? Data(contentsOf: url),
                  let src = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            context.coordinator.frames = Self.extractFrames(source: src)
            context.coordinator.frameIndex = 0
            let img = NSImage(contentsOf: url)
            nsView.image = img
            DispatchQueue.main.async { naturalSize = img?.size }
        }

        nsView.animates = !paused

        if paused, context.coordinator.lastStepToken != stepToken {
            context.coordinator.lastStepToken = stepToken
            context.coordinator.stepFrame(on: nsView)
        }
    }

    static func extractFrames(source: CGImageSource) -> [NSImage] {
        let count = CGImageSourceGetCount(source)
        var frames: [NSImage] = []
        for i in 0..<count {
            if let cg = CGImageSourceCreateImageAtIndex(source, i, nil) {
                frames.append(NSImage(cgImage: cg, size: .zero))
            }
        }
        return frames
    }

    class Coordinator {
        var loadedURL: URL?
        var frames: [NSImage] = []
        var frameIndex: Int = 0
        var lastStepToken: Int = 0

        func stepFrame(on view: NSImageView) {
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
