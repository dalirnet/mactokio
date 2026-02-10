import SwiftUI

struct EmptyState: View {
    let message: String
    let icon: String
    let action: (() -> Void)?
    let actionLabel: String?

    init(_ message: String, icon: String, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        self.message = message
        self.icon = icon
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
