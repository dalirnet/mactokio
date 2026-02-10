import SwiftUI
import AVFoundation
import AppKit

// MARK: - Full Screen Camera Window Manager

class CameraScanWindow: NSObject {
    private static var window: NSWindow?
    private static var monitor: Any?

    static func open() {
        guard window == nil else { return }
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.contentView = NSHostingView(rootView: CameraScanContentView(onClose: { close() }))
        window.makeKeyAndOrderFront(nil)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                close()
                return nil
            }
            return event
        }

        self.window = window
    }

    static func close() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - Camera Scan Content

struct CameraScanContentView: View {
    let onClose: () -> Void

    @StateObject private var camera = CameraService()
    @State private var statusMessage = "Waiting for camera access"
    @State private var highlightBounds: CGRect? = nil
    @State private var resultColor: Color = .green
    @State private var highlightVisible = false
    @State private var resultIcon: String? = nil
    @State private var resultIconVisible = false
    @State private var showDimming = false

    private var overlayBackground: Color {
        if camera.isRunning {
            return Color.black.opacity(0.6)
        }
        return Color.white.opacity(0.12)
    }

    var body: some View {
        ZStack {
            Color.black

            if camera.isRunning || highlightVisible {
                CameraPreviewView(session: camera.session)

                // Dimming overlay outside detection area
                if showDimming, let bounds = highlightBounds {
                    QRDimmingView(bounds: bounds)
                        .opacity(showDimming ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showDimming)
                }

                if let bounds = highlightBounds {
                    QRHighlightView(bounds: bounds)
                        .opacity(highlightVisible ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: highlightVisible)

                    // Result icon overlay
                    if let icon = resultIcon {
                        QRResultIconView(bounds: bounds, icon: icon, color: resultColor, visible: resultIconVisible)
                    }
                }
            } else if camera.permissionDenied {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Camera access denied")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    Text("Allow camera access in System Settings > Privacy & Security > Camera")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }

            // Status overlay
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    Text(statusMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Press Esc to cancel")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(overlayBackground)
                .cornerRadius(12)
                .padding(.horizontal, 48)
                .padding(.bottom, 48)
            }
        }
        .onAppear { camera.startScanning() }
        .onDisappear { camera.stopScanning() }
        .onChange(of: camera.isRunning) { running in
            if running {
                statusMessage = "Place QR code in front of camera"
            }
        }
        .onChange(of: camera.state) { newState in
            handleStateChange(newState)
        }
    }

    private func handleStateChange(_ newState: QRDetectionState) {
        switch newState {
        case .none:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                highlightVisible = false
                resultIconVisible = false
                showDimming = false
            }
            resultIcon = nil
            if camera.isRunning {
                statusMessage = "Place QR code in front of camera"
            }

        case .tracking(let rect):
            highlightBounds = rect
            statusMessage = "Reading QR code..."
            resultIcon = nil
            resultIconVisible = false
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                highlightVisible = true
                showDimming = false
            }

        case .success(let rect, let code):
            highlightBounds = rect
            resultIcon = "checkmark"
            resultColor = .green
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showDimming = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    resultIconVisible = true
                }
            }
            handleSuccess(code)

        case .error(let rect):
            highlightBounds = rect
            resultIcon = "xmark"
            resultColor = .red
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showDimming = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    resultIconVisible = true
                }
            }
            handleError()
        }
    }

    private func handleSuccess(_ code: String) {
        if let (account, secretData) = URIService.parse(code) {
            SecretStore.save(secret: secretData, for: account.id)
            AppConfig.shared.addAccount(account)
            statusMessage = "Account imported successfully"
        } else if let accounts = URIService.parseMigration(code), !accounts.isEmpty {
            for (account, secretData) in accounts {
                SecretStore.save(secret: secretData, for: account.id)
                AppConfig.shared.addAccount(account)
            }
            statusMessage = "Account imported successfully"
        } else {
            handleError()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            onClose()
        }
    }

    private func handleError() {
        statusMessage = "Unrecognized QR code, try another"

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                highlightVisible = false
                resultIconVisible = false
                showDimming = false
            }
            resultIcon = nil
            camera.startScanning()
            statusMessage = "Place QR code in front of camera"
        }
    }
}

// MARK: - Dimming Overlay (darkens outside detection area)

struct QRDimmingView: View {
    let bounds: CGRect

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(
                x: (1.0 - bounds.origin.x - bounds.width) * geo.size.width,
                y: bounds.origin.y * geo.size.height,
                width: bounds.width * geo.size.width,
                height: bounds.height * geo.size.height
            )
            let size = max(rect.width, rect.height) + 32
            let cutout = CGRect(
                x: rect.midX - size / 2,
                y: rect.midY - size / 2,
                width: size,
                height: size
            )

            Canvas { context, canvasSize in
                // Full dark overlay
                let fullRect = CGRect(origin: .zero, size: canvasSize)
                context.fill(Path(fullRect), with: .color(.black.opacity(0.5)))

                // Cut out the detection area
                let cutoutPath = Path(roundedRect: cutout, cornerRadius: 16)
                context.blendMode = .destinationOut
                context.fill(cutoutPath, with: .color(.white))
            }
            .compositingGroup()
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: rect.midX)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: rect.midY)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: size)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - QR Highlight Overlay

struct QRHighlightView: View {
    let bounds: CGRect

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(
                x: (1.0 - bounds.origin.x - bounds.width) * geo.size.width,
                y: bounds.origin.y * geo.size.height,
                width: bounds.width * geo.size.width,
                height: bounds.height * geo.size.height
            )
            let size = max(rect.width, rect.height) + 32
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                .frame(width: size, height: size)
                .position(x: rect.midX, y: rect.midY)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: rect.midX)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: rect.midY)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: size)
        }
    }
}

// MARK: - QR Result Icon

struct QRResultIconView: View {
    let bounds: CGRect
    let icon: String
    let color: Color
    let visible: Bool

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(
                x: (1.0 - bounds.origin.x - bounds.width) * geo.size.width,
                y: bounds.origin.y * geo.size.height,
                width: bounds.width * geo.size.width,
                height: bounds.height * geo.size.height
            )
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 0)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(visible ? 1 : 0.01)
            .opacity(visible ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: visible)
            .position(x: rect.midX, y: rect.midY)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: rect.midX)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: rect.midY)
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        previewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
