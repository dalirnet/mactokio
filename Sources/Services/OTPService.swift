import Foundation
import CommonCrypto

struct OTPService {
    static func generateTOTP(secret: Data, period: Int = 30, digits: Int = 6, algorithm: Algorithm = .sha1) -> String {
        let counter = TimeHelper.timeStep(period: period)
        return generateHOTP(secret: secret, counter: counter, digits: digits, algorithm: algorithm)
    }

    static func generateHOTP(secret: Data, counter: UInt64, digits: Int = 6, algorithm: Algorithm = .sha1) -> String {
        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: MemoryLayout<UInt64>.size)

        let hash = hmac(algorithm: algorithm, key: secret, data: counterData)
        let code = truncate(hash: hash, digits: digits)

        let padded = String(format: "%0\(digits)d", code)
        return padded
    }

    private static func hmac(algorithm: Algorithm, key: Data, data: Data) -> Data {
        let (ccAlgorithm, digestLength) = algorithmParams(algorithm)

        var result = [UInt8](repeating: 0, count: digestLength)
        key.withUnsafeBytes { keyPtr in
            data.withUnsafeBytes { dataPtr in
                CCHmac(
                    ccAlgorithm,
                    keyPtr.baseAddress, key.count,
                    dataPtr.baseAddress, data.count,
                    &result
                )
            }
        }

        return Data(result)
    }

    private static func truncate(hash: Data, digits: Int) -> UInt32 {
        let offset = Int(hash[hash.count - 1] & 0x0F)

        let code = (UInt32(hash[offset]) & 0x7F) << 24
            | UInt32(hash[offset + 1]) << 16
            | UInt32(hash[offset + 2]) << 8
            | UInt32(hash[offset + 3])

        let mod = UInt32(pow(10, Double(digits)))
        return code % mod
    }

    private static func algorithmParams(_ algorithm: Algorithm) -> (CCHmacAlgorithm, Int) {
        switch algorithm {
        case .sha1:   return (CCHmacAlgorithm(kCCHmacAlgSHA1), Int(CC_SHA1_DIGEST_LENGTH))
        case .sha256: return (CCHmacAlgorithm(kCCHmacAlgSHA256), Int(CC_SHA256_DIGEST_LENGTH))
        case .sha512: return (CCHmacAlgorithm(kCCHmacAlgSHA512), Int(CC_SHA512_DIGEST_LENGTH))
        }
    }
}
