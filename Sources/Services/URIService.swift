import Foundation

struct URIService {
    // Parse otpauth://totp/Issuer:Account?secret=...&algorithm=...&digits=...&period=...
    // Parse otpauth://hotp/Issuer:Account?secret=...&counter=...
    static func parse(_ uri: String) -> (Account, Data)? {
        guard let url = URLComponents(string: uri),
              url.scheme == "otpauth",
              let host = url.host,
              let typeValue = OTPType(rawValue: host) else { return nil }

        var path = url.path
        if path.hasPrefix("/") { path = String(path.dropFirst()) }

        let params = queryParams(from: url)

        guard let secretString = params["secret"],
              let secret = Base32.decode(secretString) else { return nil }

        let (issuer, name) = parseLabel(path, issuerParam: params["issuer"])

        let algorithm: Algorithm
        switch params["algorithm"]?.uppercased() {
        case "SHA256": algorithm = .sha256
        case "SHA512": algorithm = .sha512
        default: algorithm = .sha1
        }

        let digits = Int(params["digits"] ?? "") ?? 6
        let period = Int(params["period"] ?? "") ?? 30
        let counter = UInt64(params["counter"] ?? "") ?? 0

        let account = Account(
            name: name,
            issuer: issuer,
            type: typeValue,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter
        )

        return (account, secret)
    }

    // Parse otpauth-migration://offline?data=... (Google Authenticator export)
    static func parseMigration(_ uri: String) -> [(Account, Data)]? {
        guard let url = URLComponents(string: uri),
              url.scheme == "otpauth-migration",
              url.host == "offline" else { return nil }

        let params = queryParams(from: url)
        guard let dataString = params["data"],
              let data = Data(base64Encoded: dataString) else { return nil }

        let migrationAccounts = ProtobufHelper.decodeMigrationPayload(data)
        guard !migrationAccounts.isEmpty else { return nil }

        return migrationAccounts.map { migration in
            let algorithm: Algorithm
            switch migration.algorithm {
            case 2: algorithm = .sha256
            case 3: algorithm = .sha512
            default: algorithm = .sha1
            }

            let digits: Int
            switch migration.digits {
            case 2: digits = 8
            default: digits = 6
            }

            let type: OTPType
            switch migration.type {
            case 1: type = .hotp
            default: type = .totp
            }

            let (issuer, name) = parseMigrationName(migration.name, issuer: migration.issuer)

            let account = Account(
                name: name,
                issuer: issuer,
                type: type,
                algorithm: algorithm,
                digits: digits,
                period: 30,
                counter: migration.counter
            )

            return (account, migration.secret)
        }
    }

    // MARK: - Helpers

    private static func queryParams(from url: URLComponents) -> [String: String] {
        var params: [String: String] = [:]
        for item in url.queryItems ?? [] {
            if let value = item.value {
                params[item.name] = value
            }
        }
        return params
    }

    private static func parseLabel(_ path: String, issuerParam: String?) -> (issuer: String, name: String) {
        let decoded = path.removingPercentEncoding ?? path

        if let colonRange = decoded.range(of: ":") {
            let issuer = String(decoded[decoded.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let name = String(decoded[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (issuerParam ?? issuer, name)
        }

        return (issuerParam ?? "", decoded)
    }

    private static func parseMigrationName(_ name: String, issuer: String) -> (issuer: String, name: String) {
        if !issuer.isEmpty {
            // If name contains "issuer:name" format, extract name part
            if let colonRange = name.range(of: ":") {
                let namePart = String(name[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                return (issuer, namePart)
            }
            return (issuer, name)
        }

        // Try to extract issuer from "issuer:name" format
        if let colonRange = name.range(of: ":") {
            let issuerPart = String(name[name.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let namePart = String(name[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (issuerPart, namePart)
        }

        return ("", name)
    }
}
