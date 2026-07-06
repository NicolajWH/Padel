import SwiftUI
import Foundation
import PadelKit

/// Playful themed mascots for the two tournament formats: a cowboy for
/// **Americano** and a sombrero-wearing charro for **Mexicano**. Drawn as
/// vector art in a `Canvas` on a normalised 100×100 grid, so they stay crisp
/// at any size and adapt to light/dark without bundling any image assets.
struct FormatMascot: View {
    let format: AmericanoFormat
    var size: CGFloat = 56

    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            switch format {
            case .americano: Self.drawCowboy(context, side: side)
            case .mexicano: Self.drawMexican(context, side: side)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Cowboy (Americano)

    private static func drawCowboy(_ context: GraphicsContext, side s: CGFloat) {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x / 100 * s, y: y / 100 * s) }
        func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x / 100 * s, y: y / 100 * s, width: w / 100 * s, height: h / 100 * s)
        }

        let skin = Color(hex: "F1D0AE")
        let vest = Color(hex: "C89A66")
        let bandana = Color(hex: "D64545")
        let hat = Color(hex: "6E4B2A")
        let hatDark = Color(hex: "553A20")

        // Shoulders / vest
        var body = Path()
        body.move(to: P(12, 100))
        body.addCurve(to: P(50, 74), control1: P(18, 82), control2: P(34, 74))
        body.addCurve(to: P(88, 100), control1: P(66, 74), control2: P(82, 82))
        body.closeSubpath()
        context.fill(body, with: .color(vest))

        // Bandana knot at the neck
        var band = Path()
        band.move(to: P(38, 72))
        band.addLine(to: P(62, 72))
        band.addLine(to: P(50, 88))
        band.closeSubpath()
        context.fill(band, with: .color(bandana))

        // Ears
        context.fill(Path(ellipseIn: R(31, 50, 8, 9)), with: .color(skin))
        context.fill(Path(ellipseIn: R(61, 50, 8, 9)), with: .color(skin))

        // Head
        context.fill(Path(ellipseIn: R(33, 34, 34, 40)), with: .color(skin))

        // Hat brim
        context.fill(Path(ellipseIn: R(9, 30, 82, 16)), with: .color(hat))

        // Hat crown
        var crown = Path()
        crown.move(to: P(37, 39))
        crown.addLine(to: P(38, 22))
        crown.addQuadCurve(to: P(62, 22), control: P(50, 12))
        crown.addLine(to: P(63, 39))
        crown.closeSubpath()
        context.fill(crown, with: .color(hat))

        // Hat band
        context.fill(Path(roundedRect: R(37, 33, 26, 6), cornerRadius: 0.02 * s), with: .color(hatDark))
    }

    // MARK: - Charro (Mexicano)

    private static func drawMexican(_ context: GraphicsContext, side s: CGFloat) {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x / 100 * s, y: y / 100 * s) }
        func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x / 100 * s, y: y / 100 * s, width: w / 100 * s, height: h / 100 * s)
        }

        let skin = Color(hex: "E8BE93")
        let shirt = Color(hex: "C0392B")
        let hat = Color(hex: "2C2C2C")
        let trim = Color(hex: "F2F2F2")
        let bandColor = Color(hex: "B7B7B7")
        let stache = Color(hex: "3A2A1C")

        // Shoulders / shirt
        var body = Path()
        body.move(to: P(12, 100))
        body.addCurve(to: P(50, 78), control1: P(18, 86), control2: P(34, 78))
        body.addCurve(to: P(88, 100), control1: P(66, 78), control2: P(82, 86))
        body.closeSubpath()
        context.fill(body, with: .color(shirt))

        // Ears
        context.fill(Path(ellipseIn: R(31, 58, 8, 9)), with: .color(skin))
        context.fill(Path(ellipseIn: R(61, 58, 8, 9)), with: .color(skin))

        // Head
        context.fill(Path(ellipseIn: R(34, 42, 32, 36)), with: .color(skin))

        // Handlebar moustache
        var stacheP = Path()
        // Left half
        stacheP.move(to: P(50, 64))
        stacheP.addQuadCurve(to: P(35, 61), control: P(43, 61))
        stacheP.addQuadCurve(to: P(34, 67), control: P(32, 63))
        stacheP.addQuadCurve(to: P(50, 67), control: P(42, 69))
        stacheP.closeSubpath()
        // Right half
        stacheP.move(to: P(50, 64))
        stacheP.addQuadCurve(to: P(65, 61), control: P(57, 61))
        stacheP.addQuadCurve(to: P(66, 67), control: P(68, 63))
        stacheP.addQuadCurve(to: P(50, 67), control: P(58, 69))
        stacheP.closeSubpath()
        context.fill(stacheP, with: .color(stache))

        // Sombrero brim
        context.fill(Path(ellipseIn: R(3, 28, 94, 18)), with: .color(hat))

        // White zig-zag trim running around the brim
        let segments = 14
        let cx: CGFloat = 50, cy: CGFloat = 37
        var zig = Path()
        for k in 0...(segments * 2) {
            let angle = Double.pi * Double(k) / Double(segments)
            let outer = k % 2 == 0
            let rx: CGFloat = outer ? 44 : 39
            let ry: CGFloat = outer ? 8 : 6.5
            let point = P(cx + rx * CGFloat(cos(angle)), cy + ry * CGFloat(sin(angle)))
            if k == 0 { zig.move(to: point) } else { zig.addLine(to: point) }
        }
        context.stroke(zig, with: .color(trim), lineWidth: max(1, 0.014 * s))

        // Sombrero crown (rounded dome)
        var crown = Path()
        crown.move(to: P(37, 38))
        crown.addLine(to: P(38, 21))
        crown.addQuadCurve(to: P(62, 21), control: P(50, 11))
        crown.addLine(to: P(63, 38))
        crown.closeSubpath()
        context.fill(crown, with: .color(hat))

        // Silver band at the base of the crown
        context.fill(Path(roundedRect: R(37, 31, 26, 6), cornerRadius: 0.02 * s), with: .color(bandColor))
    }
}

#Preview {
    HStack(spacing: 24) {
        FormatMascot(format: .americano, size: 120)
        FormatMascot(format: .mexicano, size: 120)
    }
    .padding()
}
