import Foundation

struct MigrationAccount {
    let secret: Data
    let name: String
    let issuer: String
    let algorithm: Int // 0=unspecified, 1=SHA1, 2=SHA256, 3=SHA512
    let digits: Int    // 0=unspecified, 1=six, 2=eight
    let type: Int      // 0=unspecified, 1=HOTP, 2=TOTP
    let counter: UInt64
}

struct ProtobufHelper {
    static func decodeMigrationPayload(_ data: Data) -> [MigrationAccount] {
        var accounts: [MigrationAccount] = []
        var offset = 0

        while offset < data.count {
            guard let (fieldNumber, wireType) = readTag(data: data, offset: &offset) else { break }

            if fieldNumber == 1 && wireType == 2 {
                guard let nested = readLengthDelimited(data: data, offset: &offset) else { break }
                if let account = parseAccount(nested) {
                    accounts.append(account)
                }
            } else {
                skipField(data: data, wireType: wireType, offset: &offset)
            }
        }

        return accounts
    }

    private static func parseAccount(_ data: Data) -> MigrationAccount? {
        var offset = 0
        var secret = Data()
        var name = ""
        var issuer = ""
        var algorithm = 0
        var digits = 0
        var type = 0
        var counter: UInt64 = 0

        while offset < data.count {
            guard let (fieldNumber, wireType) = readTag(data: data, offset: &offset) else { break }

            switch fieldNumber {
            case 1: // secret (bytes)
                if wireType == 2, let value = readLengthDelimited(data: data, offset: &offset) {
                    secret = value
                } else { skipField(data: data, wireType: wireType, offset: &offset) }
            case 2: // name (string)
                if wireType == 2, let value = readLengthDelimited(data: data, offset: &offset) {
                    name = String(data: value, encoding: .utf8) ?? ""
                } else { skipField(data: data, wireType: wireType, offset: &offset) }
            case 3: // issuer (string)
                if wireType == 2, let value = readLengthDelimited(data: data, offset: &offset) {
                    issuer = String(data: value, encoding: .utf8) ?? ""
                } else { skipField(data: data, wireType: wireType, offset: &offset) }
            case 4: // algorithm (enum/varint)
                if wireType == 0, let value = readVarint(data: data, offset: &offset) {
                    algorithm = Int(value)
                } else { skipField(data: data, wireType: wireType, offset: &offset) }
            case 5: // digits (enum/varint)
                if wireType == 0, let value = readVarint(data: data, offset: &offset) {
                    digits = Int(value)
                } else { skipField(data: data, wireType: wireType, offset: &offset) }
            case 6: // type (enum/varint)
                if wireType == 0, let value = readVarint(data: data, offset: &offset) {
                    type = Int(value)
                } else { skipField(data: data, wireType: wireType, offset: &offset) }
            case 7: // counter (varint)
                if wireType == 0, let value = readVarint(data: data, offset: &offset) {
                    counter = value
                } else { skipField(data: data, wireType: wireType, offset: &offset) }
            default:
                skipField(data: data, wireType: wireType, offset: &offset)
            }
        }

        guard !secret.isEmpty else { return nil }
        return MigrationAccount(secret: secret, name: name, issuer: issuer, algorithm: algorithm, digits: digits, type: type, counter: counter)
    }

    private static func readTag(data: Data, offset: inout Int) -> (fieldNumber: Int, wireType: Int)? {
        guard let value = readVarint(data: data, offset: &offset) else { return nil }
        let wireType = Int(value & 0x07)
        let fieldNumber = Int(value >> 3)
        return (fieldNumber, wireType)
    }

    private static func readVarint(data: Data, offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0

        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { return nil }
        }

        return nil
    }

    private static func readLengthDelimited(data: Data, offset: inout Int) -> Data? {
        guard let length = readVarint(data: data, offset: &offset) else { return nil }
        let len = Int(length)
        guard offset + len <= data.count else { return nil }
        let result = data[offset..<(offset + len)]
        offset += len
        return Data(result)
    }

    private static func skipField(data: Data, wireType: Int, offset: inout Int) {
        switch wireType {
        case 0: _ = readVarint(data: data, offset: &offset)
        case 1: offset += 8
        case 2: if let len = readVarint(data: data, offset: &offset) { offset += Int(len) }
        case 5: offset += 4
        default: offset = data.count
        }
    }
}
