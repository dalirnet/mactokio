import AppKit

struct ClipboardHelper {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
