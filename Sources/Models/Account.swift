import Foundation

enum OTPType: String, Codable, CaseIterable {
    case totp
    case hotp
}

enum Algorithm: String, Codable, CaseIterable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

struct Account: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var issuer: String
    var type: OTPType
    var algorithm: Algorithm
    var digits: Int
    var period: Int
    var counter: UInt64
    var order: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        issuer: String = "",
        type: OTPType = .totp,
        algorithm: Algorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: UInt64 = 0,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.type = type
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.counter = counter
        self.order = order
    }
}
