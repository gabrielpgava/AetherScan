import AppKit
import CoreGraphics
import Foundation

let canvasSize = 1024
let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AetherScan/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
let colorSpace = CGColorSpaceCreateDeviceRGB()

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!
}

func makePeak(center: CGFloat, peakY: CGFloat, halfWidth: CGFloat, baseline: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center - halfWidth, y: baseline))
    path.addCurve(
        to: CGPoint(x: center, y: peakY),
        control1: CGPoint(x: center - halfWidth * 0.42, y: baseline),
        control2: CGPoint(x: center - halfWidth * 0.40, y: peakY + 14)
    )
    path.addCurve(
        to: CGPoint(x: center + halfWidth, y: baseline),
        control1: CGPoint(x: center + halfWidth * 0.40, y: peakY + 14),
        control2: CGPoint(x: center + halfWidth * 0.42, y: baseline)
    )
    return path
}

func makeFilledPeak(center: CGFloat, peakY: CGFloat, halfWidth: CGFloat, baseline: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center - halfWidth, y: baseline))
    path.addCurve(
        to: CGPoint(x: center, y: peakY),
        control1: CGPoint(x: center - halfWidth * 0.42, y: baseline),
        control2: CGPoint(x: center - halfWidth * 0.40, y: peakY + 14)
    )
    path.addCurve(
        to: CGPoint(x: center + halfWidth, y: baseline),
        control1: CGPoint(x: center + halfWidth * 0.40, y: peakY + 14),
        control2: CGPoint(x: center + halfWidth * 0.42, y: baseline)
    )
    path.addLine(to: CGPoint(x: center - halfWidth, y: baseline))
    path.closeSubpath()
    return path
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvasSize,
    pixelsHigh: canvasSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
let context = graphicsContext.cgContext
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let backgroundColors = [color(0.035, 0.085, 0.18), color(0.035, 0.15, 0.25), color(0.025, 0.045, 0.12)] as CFArray
let background = CGGradient(colorsSpace: colorSpace, colors: backgroundColors, locations: [0, 0.52, 1])!
context.drawLinearGradient(background, start: CGPoint(x: 0, y: canvasSize), end: CGPoint(x: canvasSize, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

let glow = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0.15, 0.55, 0.82, 0.19), color(0.12, 0.40, 0.72, 0)] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: 360, y: 690),
    startRadius: 0,
    endCenter: CGPoint(x: 360, y: 690),
    endRadius: 590,
    options: []
)

// A restrained channel grid anchors the spectral curves without turning the icon into a dashboard.
context.setStrokeColor(color(0.78, 0.91, 1, 0.11))
context.setLineWidth(3)
for index in 0...8 {
    let x = CGFloat(175 + index * 84)
    context.move(to: CGPoint(x: x, y: 248))
    context.addLine(to: CGPoint(x: x, y: 735))
}
context.strokePath()

let baseline: CGFloat = 282
context.setStrokeColor(color(0.76, 0.91, 1, 0.36))
context.setLineWidth(5)
context.move(to: CGPoint(x: 150, y: baseline))
context.addLine(to: CGPoint(x: 874, y: baseline))
context.strokePath()

let peaks: [(center: CGFloat, peakY: CGFloat, width: CGFloat, color: CGColor)] = [
    (340, 655, 218, color(0.18, 0.79, 0.98, 0.70)),
    (548, 555, 242, color(0.30, 0.61, 1.00, 0.86)),
    (734, 470, 160, color(0.26, 0.88, 0.78, 0.68))
]

for peak in peaks {
    let area = makeFilledPeak(center: peak.center, peakY: peak.peakY, halfWidth: peak.width, baseline: baseline)
    context.saveGState()
    context.addPath(area)
    context.clip()
    let fill = CGGradient(
        colorsSpace: colorSpace,
        colors: [peak.color.copy(alpha: 0.20)!, peak.color.copy(alpha: 0.015)!] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(fill, start: CGPoint(x: 0, y: baseline), end: CGPoint(x: 0, y: 730), options: [])
    context.restoreGState()

    let curve = makePeak(center: peak.center, peakY: peak.peakY, halfWidth: peak.width, baseline: baseline)
    context.saveGState()
    context.addPath(curve)
    context.setStrokeColor(peak.color)
    context.setLineWidth(19)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setShadow(offset: .zero, blur: 28, color: peak.color.copy(alpha: 0.42))
    context.strokePath()
    context.restoreGState()
}

// The bright center node gives the three overlapping channel shapes one memorable focal point.
let node = CGPoint(x: 548, y: 555)
context.setShadow(offset: .zero, blur: 32, color: color(0.43, 0.77, 1, 0.72))
context.setFillColor(color(0.91, 0.97, 1))
context.fillEllipse(in: CGRect(x: node.x - 12, y: node.y - 12, width: 24, height: 24))
context.setShadow(offset: .zero, blur: 0, color: nil)
context.setStrokeColor(color(0.20, 0.52, 0.85, 0.9))
context.setLineWidth(3)
context.strokeEllipse(in: CGRect(x: node.x - 22, y: node.y - 22, width: 44, height: 44))

NSGraphicsContext.restoreGraphicsState()

let outputDirectory = outputURL.deletingLastPathComponent()
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: outputURL, options: .atomic)
