import SwiftUI

struct AccountRow: View {
    let account: Account
    let isActive: Bool
    let code: String?
    let progress: Double
    let remaining: Int
    let onActivate: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var copied = false

    private var displayName: String {
        account.name.isEmpty ? "Unknown" : account.name
    }

    private var displayIssuer: String {
        account.issuer.isEmpty ? "Unknown" : account.issuer
    }

    private var avatarColor: Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink]
        let input = account.issuer.isEmpty ? account.name : account.issuer
        let hash = input.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                // Top: avatar + name/issuer
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(avatarColor.opacity(0.12))
                            .frame(width: 36, height: 36)

                        if isActive && code != nil {
                            CountdownRing(progress: progress, remaining: remaining, color: avatarColor)
                                .transition(.opacity)
                        } else {
                            Text(String(displayIssuer.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(avatarColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(displayIssuer)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                }

                // Bottom: message left + code right
                HStack(spacing: 8) {
                    if isActive {
                        if code != nil {
                            infoMessage("Tap to copy", icon: "square.on.square.fill")
                        } else {
                            infoMessage("Re-import required", icon: "exclamationmark.triangle.fill", iconColor: .orange)
                        }
                    } else {
                        infoMessage("Tap to reveal", icon: "lock.fill")
                    }

                    Spacer()

                    if isActive, let code {
                        CodeDisplay(code: code, digits: account.digits)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Copy overlay
            if copied {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Copied to clipboard")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .cornerRadius(8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: copied)
        .contentShape(Rectangle())
        .onTapGesture {
            if isActive {
                guard code != nil else { return }
                onCopy()
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    copied = false
                }
            } else {
                onActivate()
            }
        }
        .contextMenu {
            if isActive && code != nil {
                Button(action: {
                    onCopy()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        copied = false
                    }
                }) {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func infoMessage(_ text: String, icon: String, iconColor: Color = .secondary.opacity(0.6)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(iconColor)
                .frame(width: 12)
            Text(text)
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
}
