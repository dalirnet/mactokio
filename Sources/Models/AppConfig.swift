import Foundation

extension Notification.Name {
    static let accountsChanged = Notification.Name("accountsChanged")
}

class AppConfig: ObservableObject {
    static let shared = AppConfig()

    private let configDir: URL
    private let configPath: URL
    private var isLoading = false

    @Published var accounts: [Account] = [] { didSet { saveAndNotify() } }

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDir = homeDir.appendingPathComponent(".config/mactokio")
        configPath = configDir.appendingPathComponent("config.json")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - CRUD

    func addAccount(_ account: Account) {
        if let existingIndex = accounts.firstIndex(where: {
            $0.name == account.name && $0.issuer == account.issuer && $0.type == account.type
        }) {
            // Allow re-import if secret is missing
            if SecretStore.load(for: accounts[existingIndex].id) == nil {
                SecretStore.delete(for: accounts[existingIndex].id)
                accounts.remove(at: existingIndex)
            } else {
                return
            }
        }
        var newAccount = account
        newAccount.order = accounts.count
        accounts.append(newAccount)
    }

    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
    }

    func getAccount(by id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }

    // MARK: - Persistence

    private func saveAndNotify() {
        guard !isLoading else { return }
        save()
        NotificationCenter.default.post(name: .accountsChanged, object: nil)
    }

    private func save() {
        let data: [String: Any] = [
            "accounts": accounts.map { accountToDict($0) }
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? jsonData.write(to: configPath)
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let accountDicts = json["accounts"] as? [[String: Any]] {
            accounts = accountDicts.compactMap { dictToAccount($0) }
        }
    }

    // MARK: - Serialization

    private func accountToDict(_ account: Account) -> [String: Any] {
        [
            "id": account.id.uuidString,
            "name": account.name,
            "issuer": account.issuer,
            "type": account.type.rawValue,
            "algorithm": account.algorithm.rawValue,
            "digits": account.digits,
            "period": account.period,
            "counter": account.counter,
            "order": account.order
        ]
    }

    private func dictToAccount(_ dict: [String: Any]) -> Account? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = dict["name"] as? String,
              let issuer = dict["issuer"] as? String else { return nil }

        return Account(
            id: id,
            name: name,
            issuer: issuer,
            type: OTPType(rawValue: dict["type"] as? String ?? "totp") ?? .totp,
            algorithm: Algorithm(rawValue: dict["algorithm"] as? String ?? "SHA1") ?? .sha1,
            digits: dict["digits"] as? Int ?? 6,
            period: dict["period"] as? Int ?? 30,
            counter: dict["counter"] as? UInt64 ?? 0,
            order: dict["order"] as? Int ?? 0
        )
    }
}
