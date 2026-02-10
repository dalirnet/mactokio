import SwiftUI

struct CountdownRing: View {
    let progress: Double
    let remaining: Int
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 2)

            Circle()
                .trim(from: 0, to: 1 - progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: 16, height: 16)
    }
}
