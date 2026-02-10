import Foundation

struct Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    static func decode(_ input: String) -> Data? {
        let cleaned = input.uppercased().filter { $0 != "=" && !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }

        var bits = 0
        var accumulator: UInt32 = 0
        var output = Data()

        for char in cleaned {
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            accumulator = (accumulator << 5) | UInt32(index)
            bits += 5

            if bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> bits) & 0xFF))
            }
        }

        return output
    }
}
