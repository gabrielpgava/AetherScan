import SwiftUI

enum SignalArtworkState {
    case empty
    case scanning
    case diagnostic
}

struct SignalSpectrumArtwork: View {
    let state: SignalArtworkState

    var body: some View {
        Canvas { context, size in
            let baseline = size.height * 0.82
            let grid = Color.primary.opacity(0.10)
            let accent = Color.accentColor

            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: size.width * 0.06, y: baseline))
            baselinePath.addLine(to: CGPoint(x: size.width * 0.94, y: baseline))
            context.stroke(baselinePath, with: .color(grid), lineWidth: 1)

            for index in 0...10 {
                let x = size.width * (0.08 + CGFloat(index) * 0.084)
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: baseline - 3))
                tick.addLine(to: CGPoint(x: x, y: baseline + (index.isMultiple(of: 2) ? 5 : 2)))
                context.stroke(tick, with: .color(grid), lineWidth: 1)
            }

            switch state {
            case .empty:
                let center = CGPoint(x: size.width * 0.5, y: baseline - 1)
                let radius = max(3, size.width * 0.035)
                let marker = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(marker, with: .color(accent.opacity(0.55)), lineWidth: 1.5)

            case .scanning:
                let x = size.width * 0.68
                var sweep = Path()
                sweep.move(to: CGPoint(x: x, y: size.height * 0.18))
                sweep.addLine(to: CGPoint(x: x, y: baseline))
                context.stroke(sweep, with: .color(accent.opacity(0.72)), lineWidth: 1.5)

                let radius = max(2.5, size.width * 0.04)
                let scanPoint = Path(ellipseIn: CGRect(
                    x: x - radius,
                    y: baseline - size.height * 0.48 - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.fill(scanPoint, with: .color(accent))

            case .diagnostic:
                let peaks: [(center: CGFloat, height: CGFloat, spread: CGFloat, color: Color)] = [
                    (0.29, 0.34, 0.24, .cyan),
                    (0.53, 0.59, 0.29, accent),
                    (0.75, 0.30, 0.20, .teal)
                ]

                for peak in peaks {
                    let centerX = size.width * peak.center
                    let height = size.height * peak.height
                    let spread = size.width * peak.spread
                    var curve = Path()
                    curve.move(to: CGPoint(x: centerX - spread, y: baseline))
                    curve.addCurve(
                        to: CGPoint(x: centerX, y: baseline - height),
                        control1: CGPoint(x: centerX - spread * 0.42, y: baseline),
                        control2: CGPoint(x: centerX - spread * 0.38, y: baseline - height * 0.98)
                    )
                    curve.addCurve(
                        to: CGPoint(x: centerX + spread, y: baseline),
                        control1: CGPoint(x: centerX + spread * 0.38, y: baseline - height * 0.98),
                        control2: CGPoint(x: centerX + spread * 0.42, y: baseline)
                    )
                    context.stroke(curve, with: .color(peak.color.opacity(0.72)), lineWidth: 1.6)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Spectrum states") {
    HStack(spacing: 32) {
        SignalSpectrumArtwork(state: .empty)
        SignalSpectrumArtwork(state: .scanning)
        SignalSpectrumArtwork(state: .diagnostic)
    }
    .padding(24)
    .frame(width: 440, height: 120)
}
