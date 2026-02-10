import Foundation
import CommonCrypto

struct SecretStore {
    private static var secretsDir: URL = {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dir = homeDir.appendingPathComponent(".config/mactokio/secrets")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Restrict directory permissions to owner only (700)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        return dir
    }()

    // Derive a stable encryption key from machine-specific data
    private static var encryptionKey: Data = {
        // Use a combination of hardware UUID and a fixed salt
        let hwUUID = hardwareUUID() ?? "fallback-mactokio-key"
        let salt = "net.dalir.mactokio.v1"
        let input = "\(hwUUID):\(salt)"
        let inputData = Data(input.utf8)

        // SHA-256 hash as 32-byte key
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        inputData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(inputData.count), &hash)
        }
        return Data(hash)
    }()

    static func save(secret: Data, for accountId: UUID) {
        let path = secretsDir.appendingPathComponent(accountId.uuidString)
        guard let encrypted = encrypt(secret) else { return }
        try? encrypted.write(to: path)
        // Restrict file permissions to owner only (600)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }

    static func load(for accountId: UUID) -> Data? {
        let path = secretsDir.appendingPathComponent(accountId.uuidString)
        guard let encrypted = try? Data(contentsOf: path) else { return nil }
        return decrypt(encrypted)
    }

    static func delete(for accountId: UUID) {
        let path = secretsDir.appendingPathComponent(accountId.uuidString)
        try? FileManager.default.removeItem(at: path)
    }

    // MARK: - Encryption

    private static func encrypt(_ data: Data) -> Data? {
        let key = encryptionKey
        var iv = [UInt8](repeating: 0, count: kCCBlockSizeAES128)
        guard SecRandomCopyBytes(kSecRandomDefault, iv.count, &iv) == errSecSuccess else { return nil }

        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var bytesEncrypted = 0

        let status = key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCCrypt(
                    CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionPKCS7Padding),
                    keyBytes.baseAddress, kCCKeySizeAES256,
                    iv,
                    dataBytes.baseAddress, data.count,
                    &buffer, bufferSize,
                    &bytesEncrypted
                )
            }
        }

        guard status == kCCSuccess else { return nil }

        // Prepend IV to ciphertext
        var result = Data(iv)
        result.append(Data(buffer.prefix(bytesEncrypted)))
        return result
    }

    private static func decrypt(_ data: Data) -> Data? {
        let key = encryptionKey
        guard data.count > kCCBlockSizeAES128 else { return nil }

        let iv = data.prefix(kCCBlockSizeAES128)
        let ciphertext = data.dropFirst(kCCBlockSizeAES128)

        let bufferSize = ciphertext.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var bytesDecrypted = 0

        let status = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                ciphertext.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, kCCKeySizeAES256,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, ciphertext.count,
                        &buffer, bufferSize,
                        &bytesDecrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return Data(buffer.prefix(bytesDecrypted))
    }

    // MARK: - Hardware UUID

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let key = kIOPlatformUUIDKey as CFString
        guard let uuid = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String else {
            return nil
        }
        return uuid
    }
}
