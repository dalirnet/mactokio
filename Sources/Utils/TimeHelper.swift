import Foundation

struct TimeHelper {
    static func currentTimestamp() -> UInt64 {
        UInt64(Date().timeIntervalSince1970)
    }

    static func timeStep(period: Int) -> UInt64 {
        currentTimestamp() / UInt64(period)
    }

    static func secondsRemaining(period: Int) -> Int {
        period - Int(currentTimestamp() % UInt64(period))
    }

    static func progress(period: Int) -> Double {
        let elapsed = Double(currentTimestamp() % UInt64(period))
        return elapsed / Double(period)
    }
}
