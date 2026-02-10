import AVFoundation
import AppKit
import CoreImage

enum QRDetectionState: Equatable {
    case none
    case tracking(CGRect)
    case success(CGRect, String)
    case error(CGRect)
}

class CameraService: NSObject, ObservableObject {
    @Published var state: QRDetectionState = .none
    @Published var isRunning = false
    @Published var permissionDenied = false

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "net.dalir.mactokio.camera")
    private let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    private var isConfigured = false
    private var isLocked = false
    private var trackingFrames = 0
    private var missedFrames = 0
    private let trackingThreshold = 10
    private let missedThreshold = 6

    func startScanning() {
        isLocked = false
        trackingFrames = 0
        missedFrames = 0

        DispatchQueue.main.async {
            self.state = .none
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.sessionQueue.async { self.setupAndStart() }
            } else {
                DispatchQueue.main.async { self.permissionDenied = true }
            }
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    private func setupAndStart() {
        if !isConfigured {
            session.beginConfiguration()

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true

            guard session.canAddOutput(videoOutput) else {
                session.commitConfiguration()
                return
            }

            session.addOutput(videoOutput)
            session.commitConfiguration()
            isConfigured = true
        }

        session.startRunning()
        DispatchQueue.main.async { self.isRunning = true }
    }

    private func normalizedRect(for bounds: CGRect, imageWidth: CGFloat, imageHeight: CGFloat) -> CGRect {
        CGRect(
            x: bounds.origin.x / imageWidth,
            y: 1.0 - (bounds.origin.y + bounds.height) / imageHeight,
            width: bounds.width / imageWidth,
            height: bounds.height / imageHeight
        )
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isLocked else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature],
              let feature = features.first else {
            // Grace period before hiding the highlight
            missedFrames += 1
            if missedFrames > missedThreshold {
                trackingFrames = 0
                DispatchQueue.main.async { self.state = .none }
            }
            return
        }

        missedFrames = 0
        let rect = normalizedRect(for: feature.bounds, imageWidth: width, imageHeight: height)

        // Show tracking while building confidence
        trackingFrames += 1
        if trackingFrames <= trackingThreshold {
            DispatchQueue.main.async { self.state = .tracking(rect) }
            return
        }

        // Evaluate QR content
        let code = feature.messageString ?? ""

        if code.hasPrefix("otpauth://") || code.hasPrefix("otpauth-migration://") {
            isLocked = true
            DispatchQueue.main.async { self.state = .success(rect, code) }
        } else {
            isLocked = true
            DispatchQueue.main.async { self.state = .error(rect) }
        }
    }
}
