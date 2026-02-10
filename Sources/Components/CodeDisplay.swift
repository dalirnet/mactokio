import SwiftUI

struct CodeDisplay: View {
    let code: String
    let digits: Int
    let grouped: Bool

    init(code: String, digits: Int, grouped: Bool = true) {
        self.code = code
        self.digits = digits
        self.grouped = grouped
    }

    var body: some View {
        Text(displayCode)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .tracking(0.5)
    }

    private var displayCode: String {
        guard grouped else { return code }

        var result = ""
        for (index, char) in code.enumerated() {
            if index > 0 && index % 2 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }
}
