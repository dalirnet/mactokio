import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var appConfig = AppConfig.shared
    @ObservedObject var authService = AuthService.shared
    @State private var activeAccountIds: Set<UUID> = []
    @State private var accountCycles: [UUID: Int] = [:]
    @State private var lastRemaining: [UUID: Int] = [:]
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var tick = 0
    @State private var importError: String?
    @State private var deleteTarget: Account?
    @State private var searchText = ""

    var body: some View {
        Group {
            if !authService.isAuthenticated {
                authGate
            } else {
                mainContent
            }
        }
        .onReceive(timer) { _ in
            tick += 1
            checkCycles()
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert("Delete Account", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let account = deleteTarget {
                    deleteAccount(account)
                }
                deleteTarget = nil
            }
        } message: {
            if let account = deleteTarget {
                Text("Remove \(account.name.isEmpty ? "Unknown" : account.name)?")
            }
        }
    }

    // MARK: - Auth Gate

    @State private var authGateAppeared = false
    @State private var pulseScale: CGFloat = 1.0

    private var authGate: some View {
        VStack(spacing: 20) {
            Button(action: requestAuth) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulseScale)
                    Circle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseScale * 0.97)
                    Image(systemName: "touchid")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)

            Text("Unlock to view your codes")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            .opacity(authGateAppeared ? 1 : 0)
            .offset(y: authGateAppeared ? 0 : -8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                authGateAppeared = true
            }
        }
        .onDisappear {
            authGateAppeared = false
            pulseScale = 1.0
        }
    }

    private func requestAuth() {
        authService.authenticate { _ in }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ViewLayout(
            headerLeft: { HeaderTitle(title: "Mactokio") },
            headerRight: { importMenu },
            content: {
                if appConfig.accounts.isEmpty {
                    EmptyState("No accounts yet", icon: "qrcode")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            // Search field
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                TextField("Type to filter", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .padding(.bottom, 4)

                            if filteredAccounts.isEmpty {
                                EmptyState("No results", icon: "magnifyingglass")
                                    .frame(height: 200)
                            } else {
                                ForEach(filteredAccounts) { account in
                                    let isActive = activeAccountIds.contains(account.id)
                                    let code: String? = isActive ? generateCode(for: account) : nil
                                    let progress = isActive && account.type == .totp ? TimeHelper.progress(period: account.period) : 0
                                    let remaining = isActive && account.type == .totp ? TimeHelper.secondsRemaining(period: account.period) : 0

                                    AccountRow(
                                        account: account,
                                        isActive: isActive,
                                        code: code,
                                        progress: progress,
                                        remaining: remaining,
                                        onActivate: { activateAccount(account) },
                                        onCopy: { if let code { ClipboardHelper.copy(code) } },
                                        onDelete: { deleteTarget = account }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity.combined(with: .move(edge: .bottom))
                                    ))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10).padding(.bottom, 10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: filteredAccounts.map(\.id))
                    }
                }
            }
        )
    }

    // MARK: - Import Menu

    private var importMenu: some View {
        Menu {
            Button(action: importFromFile) {
                Label("From File", systemImage: "doc")
            }
            Button(action: importFromClipboard) {
                Label("From Clipboard", systemImage: "clipboard")
            }
            Divider()
            Button(action: openCameraScan) {
                Label("From Camera", systemImage: "qrcode.viewfinder")
            }
        } label: {
            Image(systemName: "plus.viewfinder")
                .font(.system(size: 16))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Import Actions

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, .utf8PlainText, .image, .png, .jpeg, .tiff, .bmp, .gif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a text or image file"

        guard panel.runModal() == .OK,
              let url = panel.url else { return }

        // Try as text file first
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var imported = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if importSingleURI(trimmed) {
                    imported = true
                }
            }
            if imported { return }
        }

        // Try as QR image
        if let qrContent = QRService.detectQR(from: url) {
            if importSingleURI(qrContent) { return }
        }

        importError = "No valid otpauth data found"
    }

    private func importFromClipboard() {
        // Try text first
        if let text = ClipboardHelper.read() {
            let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var imported = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if importSingleURI(trimmed) {
                    imported = true
                }
            }
            if imported { return }
        }

        // Then try QR image from clipboard
        if let qrContent = QRService.scanFromClipboard() {
            if importSingleURI(qrContent) { return }
        }

        importError = "No valid otpauth data found in clipboard"
    }

    @discardableResult
    private func importSingleURI(_ uri: String) -> Bool {
        if let (account, secretData) = URIService.parse(uri) {
            SecretStore.save(secret: secretData, for: account.id)
            let _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appConfig.addAccount(account)
            }
            return true
        }

        if let accounts = URIService.parseMigration(uri), !accounts.isEmpty {
            for (account, secretData) in accounts {
                SecretStore.save(secret: secretData, for: account.id)
                let _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    appConfig.addAccount(account)
                }
            }
            return true
        }

        return false
    }

    private func openCameraScan() {
        CameraScanWindow.open()
    }

    // MARK: - Account Actions

    private func activateAccount(_ account: Account) {
        let _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            activeAccountIds.insert(account.id)
        }
        accountCycles[account.id] = 0
        lastRemaining[account.id] = TimeHelper.secondsRemaining(period: account.period)
    }

    private func deactivateAccount(_ id: UUID) {
        let _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            activeAccountIds.remove(id)
        }
        accountCycles.removeValue(forKey: id)
        lastRemaining.removeValue(forKey: id)
    }

    private func checkCycles() {
        for id in activeAccountIds {
            guard let account = appConfig.getAccount(by: id),
                  account.type == .totp else { continue }

            let remaining = TimeHelper.secondsRemaining(period: account.period)
            let prev = lastRemaining[id] ?? remaining

            if remaining > prev {
                accountCycles[id] = (accountCycles[id] ?? 0) + 1
            }
            lastRemaining[id] = remaining

            if (accountCycles[id] ?? 0) >= 3 {
                deactivateAccount(id)
            }
        }
    }

    private func deleteAccount(_ account: Account) {
        SecretStore.delete(for: account.id)
        let _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            appConfig.deleteAccount(account)
        }
        deactivateAccount(account.id)
    }

    // MARK: - Helpers

    private var sortedAccounts: [Account] {
        appConfig.accounts.sorted { $0.order < $1.order }
    }

    private var filteredAccounts: [Account] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return sortedAccounts }
        return sortedAccounts.filter {
            $0.name.lowercased().contains(query) || $0.issuer.lowercased().contains(query)
        }
    }

    private func generateCode(for account: Account) -> String? {
        guard let secret = SecretStore.load(for: account.id) else { return nil }
        let _ = tick

        switch account.type {
        case .totp:
            return OTPService.generateTOTP(secret: secret, period: account.period, digits: account.digits, algorithm: account.algorithm)
        case .hotp:
            return OTPService.generateHOTP(secret: secret, counter: account.counter, digits: account.digits, algorithm: account.algorithm)
        }
    }
}
