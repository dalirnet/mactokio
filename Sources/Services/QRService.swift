import AppKit
import CoreImage

struct QRService {
    static func scanFromClipboard() -> String? {
        let pb = NSPasteboard.general

        // Try NSImage first
        if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            if let result = detectQR(from: image) { return result }
        }

        // Try raw image data (PNG, TIFF, JPEG)
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff, .init("public.jpeg")]
        for type in imageTypes {
            if let data = pb.data(forType: type), let ciImage = CIImage(data: data) {
                if let result = detectQR(in: ciImage) { return result }
            }
        }

        // Try file URL
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let result = detectQR(from: url) { return result }
            }
        }

        return nil
    }

    // MARK: - Detection

    static func detectQR(from url: URL) -> String? {
        guard let ciImage = CIImage(contentsOf: url) else { return nil }
        return detectQR(in: ciImage)
    }

    private static func detectQR(from image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return nil }
        return detectQR(in: ciImage)
    }

    private static func detectQR(in ciImage: CIImage) -> String? {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []

        for feature in features {
            if let qr = feature as? CIQRCodeFeature, let message = qr.messageString {
                return message
            }
        }

        return nil
    }
}
