import SwiftUI
import AppKit

/// Handcrafted Coucou / Shimeji-style 2D Interactive Vector Capybara ("Maki")
/// - Real-time global cursor tracking (or tracks live butterfly / reading book!)
/// - Grounded elastic squash-and-stretch (feet stay planted; NEVER jumps upward!)
/// - 8+ autonomous idle animations: Mini MacBook coding, Matcha tea, Butterfly, Juggling 3 oranges,
///   Soap bubbles, Reading book, Stretching aerobics, Poppable sleep bubble, & Trackpad fur brushing!
public struct Capybara2DView: View {
    public var role: CapyRole
    public var action: CapyAction
    public var orangesOnHead: Int
    public var isOnsen: Bool
    public var isListeningMusic: Bool
    public var isFocusing: Bool
    public var isDangling: Bool
    public var isMouthOpenForDrop: Bool
    public var lookVector: CGPoint
    public var lastSquishTime: TimeInterval
    public var facingRight: Bool
    public var mascotModel: CapyMascotModel
    public var nameBadge: String

    @State private var isHoveringSelf: Bool = false

    public init(
        role: CapyRole = .habitat,
        action: CapyAction = .chill,
        orangesOnHead: Int = 1,
        isOnsen: Bool = false,
        isListeningMusic: Bool = false,
        isFocusing: Bool = false,
        isDangling: Bool = false,
        isMouthOpenForDrop: Bool = false,
        lookVector: CGPoint = .zero,
        lastSquishTime: TimeInterval = 0,
        facingRight: Bool = false,
        mascotModel: CapyMascotModel = .classic,
        nameBadge: String = "maki"
    ) {
        self.role = role
        self.action = action
        self.orangesOnHead = orangesOnHead
        self.isOnsen = isOnsen
        self.isListeningMusic = isListeningMusic
        self.isFocusing = isFocusing
        self.isDangling = isDangling
        self.isMouthOpenForDrop = isMouthOpenForDrop
        self.lookVector = lookVector
        self.lastSquishTime = lastSquishTime
        self.facingRight = facingRight
        self.mascotModel = mascotModel
        self.nameBadge = nameBadge
    }

    public var body: some View {
        // Adaptive frame rate: full 30 fps only while Maki is actually animating; calm 15 fps when just chilling/sleeping (halves idle CPU = snappier UI)
        let calm = (action == .chill || action == .sleeping) && !isMouthOpenForDrop && !isHoveringSelf
        TimelineView(.animation(minimumInterval: calm ? 1.0 / 15.0 : 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawMaki(in: &ctx, size: size, t: t)
            }
        }
        .onHover { hovering in
            isHoveringSelf = hovering
        }
    }

    // MARK: - 2D Rigged Vector Renderer
    private func drawMaki(in ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width
        let h = size.height
        // Scale s proportionally to guarantee ample headroom for 3 stacked oranges + leaf and hats!
        let s = min(w * 0.88, h * 0.74)
        guard s > 8 else { return }

        let strokeW = max(1.1, s * 0.025)
        let isPlushie = (mascotModel == .plushie)
        let outlineColor = isPlushie ? Color(red: 0.38, green: 0.26, blue: 0.18) : Color(red: 0.23, green: 0.13, blue: 0.06)
        let furTop = isPlushie ? Color(red: 0.98, green: 0.96, blue: 0.91) : Color(red: 0.80, green: 0.52, blue: 0.30)
        let furBottom = isPlushie ? Color(red: 0.93, green: 0.87, blue: 0.78) : Color(red: 0.65, green: 0.39, blue: 0.20)
        let bellyCream = Color(red: 0.92, green: 0.77, blue: 0.61)
        let snoutDark = isPlushie ? Color(red: 0.98, green: 0.52, blue: 0.10) : Color(red: 0.39, green: 0.23, blue: 0.13)
        let snoutHighlight = isPlushie ? Color(red: 1.0, green: 0.68, blue: 0.28) : Color(red: 0.49, green: 0.31, blue: 0.19)
        let pawColor = isPlushie ? Color(red: 0.94, green: 0.88, blue: 0.80) : snoutDark
        let footColor = isPlushie ? Color(red: 0.93, green: 0.86, blue: 0.77) : snoutDark
        let blushPink = Color(red: 1.0, green: 0.48, blue: 0.55)

        let cx = w * 0.5
        let groundY = h * 0.92

        // Deterministic elastic squish on click/interact (0 vertical offset!)
        let dt = t - lastSquishTime
        let squishWave: CGFloat = (dt >= 0 && dt < 0.52)
            ? CGFloat(exp(-dt * 7.8) * sin(dt * 25.0))
            : 0.0

        var breathScaleX: CGFloat = 1.0
        var breathScaleY: CGFloat = 1.0
        var swayDeg: Double = 0.0

        if isDangling {
            swayDeg = sin(t * 9.0) * 5.5
            breathScaleX = 0.96
            breathScaleY = 1.04
        } else if action == .brushed {
            // Melts into a happy wide mochi puddle when brushed with two fingers on trackpad!
            breathScaleX = 1.14 + CGFloat(sin(t * 10.0)) * 0.02
            breathScaleY = 0.87 - CGFloat(sin(t * 10.0)) * 0.015
            swayDeg = sin(t * 8.0) * 2.5
        } else if action == .stretching {
            let st = sin(t * 5.2)
            swayDeg = st * 10.5
            breathScaleX = 0.96 + CGFloat(abs(st)) * 0.04
            breathScaleY = 1.04 - CGFloat(abs(st)) * 0.02
        } else if action == .dizzy {
            swayDeg = sin(t * 14.0) * 6.0
        } else if action == .ticklish {
            swayDeg = sin(t * 20.0) * 4.5
            breathScaleX = 1.03
            breathScaleY = 0.97
        } else if isListeningMusic && (role == .djMusic || role == .habitat) {
            let beat = CGFloat(abs(sin(t * 5.6)))
            breathScaleX = 1.0 + (1.0 - beat) * 0.035
            breathScaleY = 0.965 + beat * 0.04
            swayDeg = sin(t * 2.8) * 3.5
        } else if action == .walking {
            let step = CGFloat(abs(sin(t * 11.0)))
            breathScaleX = 1.01
            breathScaleY = 0.975 + step * 0.04
            swayDeg = sin(t * 11.0) * 4.2
        } else {
            let b = CGFloat(sin(t * 2.3))
            breathScaleX = 1.0 + b * 0.016
            breathScaleY = 1.0 - b * 0.016
            if isHoveringSelf {
                swayDeg = sin(t * 4.0) * 1.6
            }
        }

        let totalSX = breathScaleX + squishWave * 0.14
        let totalSY = breathScaleY - squishWave * 0.12

        // Precompute butterfly position if chasing butterfly so Maki's eyes track it!
        let butterflyPos = CGPoint(
            x: CGFloat(sin(t * 2.3)) * s * 0.36,
            y: -s * 0.56 + CGFloat(sin(t * 4.6)) * s * 0.12
        )

        // Gaze parallax (-1 ... +1)
        let dirSign: CGFloat = facingRight ? 1.0 : -1.0
        let gx: CGFloat
        let gy: CGFloat
        if action == .butterflyChase {
            gx = max(-1, min(1, butterflyPos.x / (s * 0.36)))
            gy = max(-1, min(1, (butterflyPos.y + s * 0.45) / (s * 0.25)))
        } else if action == .readingBook {
            gx = CGFloat(sin(t * 2.4)) * 0.55
            gy = 0.55
        } else if action == .typingLaptop {
            gx = CGFloat(sin(t * 4.5)) * 0.28
            gy = 0.50
        } else if action == .jugglingOranges {
            gx = CGFloat(-sin(t * 3.4)) * 0.55
            gy = -0.68
        } else if action == .walking {
            gx = dirSign * 0.65
            gy = 0.0
        } else {
            gx = max(-1, min(1, lookVector.x + (lookVector == .zero ? dirSign * 0.25 : 0)))
            gy = max(-1, min(1, lookVector.y))
        }

        // 1. Feathered Multi-Layer Ambient Contact Shadow + Walking Dust Puffs
        if !isDangling {
            let baseW = s * (isOnsen ? 0.78 : 0.58) * totalSX
            let baseH = s * 0.082
            let shadowCenterY = groundY - baseH * 0.45

            // Layer 1: Wide diffused ambient contact shadow (soft feathering, no harsh edge)
            let outW = baseW * 1.18
            let outH = baseH * 1.40
            let outRect = CGRect(x: cx - outW * 0.5, y: shadowCenterY - outH * 0.15, width: outW, height: outH)
            ctx.fill(Path(ellipseIn: outRect), with: .color(Color(red: 0.18, green: 0.12, blue: 0.08).opacity(0.035)))

            // Layer 2: Mid contact shadow
            let midW = baseW * 0.88
            let midH = baseH * 0.92
            let midRect = CGRect(x: cx - midW * 0.5, y: shadowCenterY, width: midW, height: midH)
            ctx.fill(Path(ellipseIn: midRect), with: .color(Color(red: 0.15, green: 0.10, blue: 0.06).opacity(0.055)))

            // Layer 3: Core occlusion directly underneath paws
            let coreW = baseW * 0.58
            let coreH = baseH * 0.55
            let coreRect = CGRect(x: cx - coreW * 0.5, y: shadowCenterY + baseH * 0.12, width: coreW, height: coreH)
            ctx.fill(Path(ellipseIn: coreRect), with: .color(Color(red: 0.12, green: 0.08, blue: 0.05).opacity(0.075)))

            if action == .walking && s > 40 {
                for i in 0..<2 {
                    let phase = (t * 2.8 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1.0)
                    let trailDir: CGFloat = facingRight ? -1.0 : 1.0
                    let px = cx + trailDir * (s * 0.22 + CGFloat(phase) * s * 0.16)
                    let py = groundY - CGFloat(phase) * s * 0.08
                    let pr = s * (0.045 - CGFloat(phase) * 0.03)
                    if pr > 0.5 {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                            with: .color(.white.opacity((1.0 - phase) * 0.45))
                        )
                    }
                }
            }
        }

        // Apply grounded transform at (cx, groundY)
        ctx.translateBy(x: cx, y: groundY)
        ctx.rotate(by: .degrees(swayDeg))
        ctx.scaleBy(x: totalSX, y: totalSY)

        let bodyW = s * 0.58
        let bodyH = s * 0.64
        let headCenterY = -bodyH * 0.66
        let faceShiftX = gx * s * 0.048
        let faceShiftY = gy * s * 0.032

        // 2. Back Onsen Rim & Water
        if isOnsen {
            let tubW = s * 0.78
            let tubH = s * 0.34
            let backWaterRect = CGRect(x: -tubW * 0.46, y: -tubH * 0.98, width: tubW * 0.92, height: tubH * 0.36)
            ctx.fill(Path(ellipseIn: backWaterRect), with: .color(Color(red: 0.28, green: 0.85, blue: 0.90)))
        }

        // 3. Cute Rounded Capybara Ears
        let earTwitch = (sin(t * 1.9) > 0.93) ? sin(t * 28.0) * 8.0 : 0.0
        let earY = headCenterY - s * 0.17 - faceShiftY * 0.35
        let earSpread = bodyW * 0.35
        for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
            var earCtx = ctx
            let ex = side * earSpread - faceShiftX * 0.35
            earCtx.translateBy(x: ex, y: earY)
            earCtx.rotate(by: .degrees(Double(side) * (22.0 + (side > 0 ? earTwitch : 0))))
            let ew = s * 0.13
            let eh = s * 0.16
            let earRect = CGRect(x: -ew * 0.5, y: -eh * 0.6, width: ew, height: eh)
            let earPath = Path(roundedRect: earRect, cornerRadius: ew * 0.48)

            if isPlushie {
                // Cream plush ear base
                earCtx.fill(earPath, with: .color(furTop))
                earCtx.stroke(earPath, with: .color(outlineColor), lineWidth: strokeW)

                // Brown outer patch on the tip/edge (matches plushie photo!)
                let tipH = eh * 0.44
                let tipRect = CGRect(x: -ew * 0.5, y: -eh * 0.6, width: ew, height: tipH)
                earCtx.fill(Path(roundedRect: tipRect, cornerRadius: ew * 0.48), with: .color(Color(red: 0.52, green: 0.30, blue: 0.16)))

                // Sweet baby-pink inner ear
                let innerRect = earRect.insetBy(dx: ew * 0.22, dy: eh * 0.22)
                earCtx.fill(Path(roundedRect: innerRect, cornerRadius: ew * 0.28), with: .color(blushPink.opacity(0.55)))
            } else {
                earCtx.fill(earPath, with: .color(snoutDark))
                earCtx.stroke(earPath, with: .color(outlineColor), lineWidth: strokeW)

                let innerRect = earRect.insetBy(dx: ew * 0.24, dy: eh * 0.24)
                earCtx.fill(Path(roundedRect: innerRect, cornerRadius: ew * 0.25), with: .color(blushPink.opacity(0.42)))
            }
        }

        if role == .scholarNotes && s > 30 {
            var penCtx = ctx
            penCtx.translateBy(x: earSpread + s * 0.04, y: earY + s * 0.02)
            penCtx.rotate(by: .degrees(32))
            let pw = s * 0.20, ph = s * 0.048
            let bodyR = CGRect(x: -pw * 0.5, y: -ph * 0.5, width: pw * 0.75, height: ph)
            penCtx.fill(Path(roundedRect: bodyR, cornerRadius: 2), with: .color(.yellow))
            penCtx.stroke(Path(roundedRect: bodyR, cornerRadius: 2), with: .color(outlineColor), lineWidth: strokeW * 0.7)
            var tip = Path()
            tip.move(to: CGPoint(x: pw * 0.25, y: -ph * 0.5))
            tip.addLine(to: CGPoint(x: pw * 0.46, y: 0))
            tip.addLine(to: CGPoint(x: pw * 0.25, y: ph * 0.5))
            tip.closeSubpath()
            penCtx.fill(tip, with: .color(bellyCream))
        }

        // 4. Chubby Mochi-Loaf Capybara Body
        var bodyPath = Path()
        let topY = -bodyH - s * 0.05
        let botY: CGFloat = -s * 0.02
        bodyPath.move(to: CGPoint(x: 0, y: topY))
        bodyPath.addCurve(
            to: CGPoint(x: bodyW * 0.52, y: -bodyH * 0.30),
            control1: CGPoint(x: bodyW * 0.44, y: topY),
            control2: CGPoint(x: bodyW * 0.54, y: -bodyH * 0.65)
        )
        bodyPath.addCurve(
            to: CGPoint(x: bodyW * 0.30, y: botY),
            control1: CGPoint(x: bodyW * 0.52, y: -bodyH * 0.06),
            control2: CGPoint(x: bodyW * 0.44, y: botY)
        )
        bodyPath.addLine(to: CGPoint(x: -bodyW * 0.30, y: botY))
        bodyPath.addCurve(
            to: CGPoint(x: -bodyW * 0.52, y: -bodyH * 0.30),
            control1: CGPoint(x: -bodyW * 0.44, y: botY),
            control2: CGPoint(x: -bodyW * 0.52, y: -bodyH * 0.06)
        )
        bodyPath.addCurve(
            to: CGPoint(x: 0, y: topY),
            control1: CGPoint(x: -bodyW * 0.54, y: -bodyH * 0.65),
            control2: CGPoint(x: -bodyW * 0.44, y: topY)
        )
        bodyPath.closeSubpath()

        ctx.fill(
            bodyPath,
            with: .linearGradient(
                Gradient(colors: [furTop, furBottom]),
                startPoint: CGPoint(x: 0, y: topY),
                endPoint: CGPoint(x: 0, y: botY)
            )
        )

        if isPlushie {
            // Cute White T-shirt with embroidered royal-blue "maki" lettering (from user photo!)
            let shirtW = bodyW * 0.74
            let shirtH = bodyH * 0.38
            let shirtY = -bodyH * 0.43
            let shirtRect = CGRect(x: -shirtW * 0.5 + faceShiftX * 0.2, y: shirtY, width: shirtW, height: shirtH)
            let shirtPath = Path(roundedRect: shirtRect, cornerRadius: s * 0.055)
            // Soft white cotton fill & fabric seam outline
            ctx.fill(shirtPath, with: .color(.white))
            ctx.stroke(shirtPath, with: .color(outlineColor.opacity(0.52)), lineWidth: strokeW * 0.8)

            // Curved crew-neck collar seam
            var collar = Path()
            let collarY = shirtY
            collar.move(to: CGPoint(x: -shirtW * 0.26 + faceShiftX * 0.2, y: collarY))
            collar.addQuadCurve(
                to: CGPoint(x: shirtW * 0.26 + faceShiftX * 0.2, y: collarY),
                control: CGPoint(x: faceShiftX * 0.2, y: collarY + shirtH * 0.24)
            )
            ctx.stroke(collar, with: .color(outlineColor.opacity(0.48)), lineWidth: strokeW * 0.7)

            // Embroidered text across chest ("maki" or companion "moko")
            let textPos = CGPoint(x: faceShiftX * 0.2, y: shirtY + shirtH * 0.58)
            let badgeFont = Font.system(size: s * 0.105, weight: .heavy, design: .rounded)
            let badgeColor = (nameBadge == "moko")
                ? Color(red: 0.08, green: 0.62, blue: 0.45)
                : Color(red: 0.08, green: 0.36, blue: 0.88)
            let badgeText = Text(nameBadge)
                .font(badgeFont)
                .foregroundColor(badgeColor)
            ctx.draw(badgeText, at: textPos)
        } else {
            // Natural belly cream patch underneath
            let bellyW = bodyW * 0.54
            let bellyH = bodyH * 0.42
            let bellyRect = CGRect(
                x: -bellyW * 0.5 + faceShiftX * 0.25,
                y: -bellyH - s * 0.03,
                width: bellyW,
                height: bellyH
            )
            ctx.fill(Path(ellipseIn: bellyRect), with: .color(bellyCream.opacity(0.82)))

            // Signature cozy cotton tee with crew collar seam & embroidered name
            let shirtW = bodyW * 0.74
            let shirtH = bodyH * 0.38
            let shirtY = -bodyH * 0.43
            let shirtRect = CGRect(x: -shirtW * 0.5 + faceShiftX * 0.2, y: shirtY, width: shirtW, height: shirtH)
            let shirtPath = Path(roundedRect: shirtRect, cornerRadius: s * 0.055)
            // Warm latte cream cotton fill
            ctx.fill(shirtPath, with: .color(Color(red: 0.98, green: 0.95, blue: 0.90)))
            ctx.stroke(shirtPath, with: .color(outlineColor.opacity(0.58)), lineWidth: strokeW * 0.8)

            // Curved crew collar in warm espresso
            var collar = Path()
            let collarY = shirtY
            collar.move(to: CGPoint(x: -shirtW * 0.26 + faceShiftX * 0.2, y: collarY))
            collar.addQuadCurve(
                to: CGPoint(x: shirtW * 0.26 + faceShiftX * 0.2, y: collarY),
                control: CGPoint(x: faceShiftX * 0.2, y: collarY + shirtH * 0.24)
            )
            ctx.stroke(collar, with: .color(outlineColor.opacity(0.55)), lineWidth: strokeW * 0.7)

            // Embroidered name badge ("maki" or companion "moko")
            let textPos = CGPoint(x: faceShiftX * 0.2, y: shirtY + shirtH * 0.58)
            let badgeFont = Font.system(size: s * 0.105, weight: .heavy, design: .rounded)
            let badgeColor = (nameBadge == "moko")
                ? Color(red: 0.15, green: 0.58, blue: 0.38)
                : Color(red: 0.78, green: 0.38, blue: 0.12)
            let badgeText = Text(nameBadge)
                .font(badgeFont)
                .foregroundColor(badgeColor)
            ctx.draw(badgeText, at: textPos)
        }
        ctx.stroke(bodyPath, with: .color(outlineColor), lineWidth: strokeW)

        // 5. Lower Feet (Waddling when walking, Kicking when dangling, or Planted!)
        if !isOnsen {
            let footW = s * 0.14
            let footH = s * 0.085
            for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
                var liftY: CGFloat = 0
                if isDangling {
                    liftY = CGFloat(sin(t * 16.0 + Double(side) * 1.5)) * s * 0.045 + s * 0.03
                } else if action == .walking {
                    liftY = -max(0, CGFloat(sin(t * 11.0 + (side > 0 ? .pi : 0)))) * s * 0.045
                }
                let fx = side * bodyW * 0.26
                let fy = -footH * 0.65 + liftY
                let fRect = CGRect(x: fx - footW * 0.5, y: fy, width: footW, height: footH)
                let fPath = Path(roundedRect: fRect, cornerRadius: footH * 0.48)
                ctx.fill(fPath, with: .color(footColor))
                ctx.stroke(fPath, with: .color(outlineColor), lineWidth: strokeW * 0.85)
            }
        }

        // 6. Pilot Red Scarf
        if role == .pilotLauncher {
            let scarfY = -bodyH * 0.43
            let scarfRect = CGRect(x: -bodyW * 0.44, y: scarfY, width: bodyW * 0.88, height: s * 0.085)
            let scarfPath = Path(roundedRect: scarfRect, cornerRadius: s * 0.04)
            ctx.fill(scarfPath, with: .color(Color(red: 0.92, green: 0.22, blue: 0.22)))
            ctx.stroke(scarfPath, with: .color(outlineColor), lineWidth: strokeW * 0.85)

            let flutter = CGFloat(sin(t * 7.5)) * s * 0.025
            var tail = Path()
            tail.move(to: CGPoint(x: bodyW * 0.34, y: scarfY + s * 0.02))
            tail.addQuadCurve(
                to: CGPoint(x: bodyW * 0.60, y: scarfY + s * 0.03 + flutter),
                control: CGPoint(x: bodyW * 0.48, y: scarfY - s * 0.02)
            )
            tail.addLine(to: CGPoint(x: bodyW * 0.56, y: scarfY + s * 0.11 + flutter))
            tail.addLine(to: CGPoint(x: bodyW * 0.32, y: scarfY + s * 0.07))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(Color(red: 0.86, green: 0.18, blue: 0.18)))
            ctx.stroke(tail, with: .color(outlineColor), lineWidth: strokeW * 0.75)
        }

        // 7. Rosy Kawaii Cheeks
        let showStrongBlush = (action == .happyPet || action == .brushed || action == .sippingTea
            || action == .ticklish || action == .dizzy || isOnsen || isHoveringSelf)
        let cheekAlpha = showStrongBlush ? 0.64 : 0.28
        let cheekY = headCenterY + s * 0.05 + faceShiftY
        let cheekSpread = bodyW * 0.34
        for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
            let cr = CGRect(
                x: faceShiftX + side * cheekSpread - s * 0.055,
                y: cheekY - s * 0.032,
                width: s * 0.11,
                height: s * 0.064
            )
            ctx.fill(Path(ellipseIn: cr), with: .color(blushPink.opacity(cheekAlpha)))
        }

        // 8. Expressive 2D Eyes
        let eyeY = headCenterY - s * 0.035 + faceShiftY * 0.85
        let eyeSpread = bodyW * 0.255
        let blinkCycle = t.truncatingRemainder(dividingBy: 3.9)
        let isBlinking = (blinkCycle > 3.74 && blinkCycle < 3.88)

        for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
            let ex = faceShiftX * 0.85 + side * eyeSpread
            drawEye(
                in: &ctx,
                center: CGPoint(x: ex, y: eyeY),
                side: side,
                s: s,
                strokeW: strokeW,
                outlineColor: outlineColor,
                gx: gx,
                gy: gy,
                isBlinking: isBlinking,
                t: t
            )
        }

        // Round glasses auto-equipped when Maki is coding on his mini laptop!
        if action == .typingLaptop && role != .scholarNotes && s > 34 {
            let gxCenter = faceShiftX * 0.85
            let gr = s * 0.068
            for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
                let lRect = CGRect(x: gxCenter + side * eyeSpread - gr, y: eyeY - gr, width: gr * 2, height: gr * 2)
                ctx.stroke(Path(ellipseIn: lRect), with: .color(.cyan.opacity(0.85)), lineWidth: strokeW * 0.8)
            }
        }

        // 9. Snout Pad + Nostrils + Mouth
        var snoutW = s * (isPlushie ? 0.24 : 0.22)
        var snoutH = s * (isPlushie ? 0.22 : 0.19)
        if case .eating = action {
            let chew = CGFloat(sin(t * 15.0))
            snoutW += chew * s * 0.018
            snoutH -= chew * s * 0.014
        }
        let snoutX = faceShiftX * 1.15
        let snoutY = headCenterY + s * (isPlushie ? 0.040 : 0.045) + faceShiftY * 1.05
        let snoutRect = CGRect(x: snoutX - snoutW * 0.5, y: snoutY - snoutH * 0.42, width: snoutW, height: snoutH)
        let snoutCorner = isPlushie ? snoutW * 0.48 : snoutW * 0.42
        let snoutPath = Path(roundedRect: snoutRect, cornerRadius: snoutCorner)
        ctx.fill(snoutPath, with: .color(snoutDark))

        if !isPlushie {
            let shineRect = CGRect(x: snoutX - snoutW * 0.30, y: snoutY - snoutH * 0.33, width: snoutW * 0.60, height: snoutH * 0.22)
            ctx.fill(Path(roundedRect: shineRect, cornerRadius: snoutW * 0.2), with: .color(snoutHighlight.opacity(0.65)))
            ctx.stroke(snoutPath, with: .color(outlineColor), lineWidth: strokeW * 0.9)

            let nostrilR = max(1.2, s * 0.017)
            for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
                let nr = CGRect(
                    x: snoutX + side * snoutW * 0.21 - nostrilR,
                    y: snoutY - snoutH * 0.16 - nostrilR,
                    width: nostrilR * 2.0,
                    height: nostrilR * 1.6
                )
                ctx.fill(Path(ellipseIn: nr), with: .color(outlineColor))
            }
        } else {
            // Plushie circular vibrant orange snout patch stroke
            ctx.stroke(snoutPath, with: .color(outlineColor.opacity(0.70)), lineWidth: strokeW * 0.85)
        }

        drawMouth(
            in: &ctx,
            snoutCenter: CGPoint(x: snoutX, y: snoutY),
            snoutW: snoutW,
            snoutH: snoutH,
            s: s,
            strokeW: strokeW,
            outlineColor: outlineColor,
            isPlushie: isPlushie,
            t: t
        )

        // Cartoon Poppable Sleep Bubble at nostril when sleeping!
        if action == .sleeping && s > 34 {
            let bubR = s * (0.065 + CGFloat(sin(t * 1.8) + 1.0) * 0.032)
            let bx = snoutX + snoutW * 0.55
            let by = snoutY - snoutH * 0.22 - bubR * 0.3
            let bRect = CGRect(x: bx - bubR, y: by - bubR, width: bubR * 2, height: bubR * 2)
            ctx.fill(Path(ellipseIn: bRect), with: .color(Color.cyan.opacity(0.32)))
            ctx.stroke(Path(ellipseIn: bRect), with: .color(Color.white.opacity(0.75)), lineWidth: strokeW * 0.65)
            let hl = CGRect(x: bx - bubR * 0.45, y: by - bubR * 0.45, width: bubR * 0.4, height: bubR * 0.4)
            ctx.fill(Path(ellipseIn: hl), with: .color(.white.opacity(0.85)))
        }

        // 10. Front Paws & Interactive Idle Activity Props!
        drawFrontPawsAndProps(
            in: &ctx,
            bodyW: bodyW,
            bodyH: bodyH,
            topY: topY,
            snoutCenter: CGPoint(x: snoutX, y: snoutY),
            s: s,
            strokeW: strokeW,
            pawColor: pawColor,
            outlineColor: outlineColor,
            butterflyPos: butterflyPos,
            t: t
        )

        // 11. Front Wooden Hinoki Onsen Tub
        if isOnsen {
            drawOnsenTubFront(in: &ctx, s: s, strokeW: strokeW, outlineColor: outlineColor, t: t)
        }

        // 12. Per-Menu 2D Costumes & Hats (hide stacked head oranges while juggling them!)
        drawCostumeHeadgear(
            in: &ctx,
            headCenterY: headCenterY,
            topY: topY,
            bodyW: bodyW,
            eyeY: eyeY,
            eyeSpread: eyeSpread,
            faceShiftX: faceShiftX,
            faceShiftY: faceShiftY,
            s: s,
            strokeW: strokeW,
            outlineColor: outlineColor,
            t: t
        )

        // 13. Trackpad Fur Brush Overlay when stroking two fingers on trackpad!
        if action == .brushed && s > 34 {
            let bx = CGFloat(sin(t * 11.0)) * bodyW * 0.26
            let by = topY - s * 0.03
            let bRect = CGRect(x: bx - s * 0.11, y: by - s * 0.04, width: s * 0.22, height: s * 0.065)
            ctx.fill(Path(roundedRect: bRect, cornerRadius: 5), with: .color(Color.pink))
            ctx.stroke(Path(roundedRect: bRect, cornerRadius: 5), with: .color(outlineColor), lineWidth: strokeW * 0.75)
        }

        // 14. Dizzy Orbiting Stars
        if action == .dizzy && s > 28 {
            for i in 0..<3 {
                let angle = t * 5.2 + Double(i) * (.pi * 2.0 / 3.0)
                let sx = CGFloat(cos(angle)) * bodyW * 0.42
                let sy = topY - s * 0.06 + CGFloat(sin(angle)) * s * 0.045
                let starRect = CGRect(x: sx - s * 0.035, y: sy - s * 0.035, width: s * 0.07, height: s * 0.07)
                ctx.fill(Path(ellipseIn: starRect), with: .color(.yellow))
                ctx.stroke(Path(ellipseIn: starRect), with: .color(outlineColor), lineWidth: strokeW * 0.6)
            }
        }

        // 15. Foreground Aerial Props (Juggling 3 Yuzu Oranges, Butterfly, Soap Bubbles — drawn IN FRONT of hats & well inside Canvas!)
        if s > 30 {
            drawForegroundAerialProps(
                in: &ctx,
                bodyW: bodyW,
                bodyH: bodyH,
                snoutCenter: CGPoint(x: snoutX, y: snoutY),
                s: s,
                strokeW: strokeW,
                outlineColor: outlineColor,
                butterflyPos: butterflyPos,
                t: t
            )
        }
    }

    // MARK: - Eyes
    private func drawEye(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        side: CGFloat,
        s: CGFloat,
        strokeW: CGFloat,
        outlineColor: Color,
        gx: CGFloat,
        gy: CGFloat,
        isBlinking: Bool,
        t: Double
    ) {
        let r = s * 0.046

        if action == .dizzy {
            var spiral = Path()
            let turns = 12
            for step in 0...turns {
                let prog = CGFloat(step) / CGFloat(turns)
                let ang = Double(prog) * .pi * 3.5 + t * 10.0 * Double(side)
                let rad = prog * r * 1.15
                let pt = CGPoint(x: center.x + CGFloat(cos(ang)) * rad, y: center.y + CGFloat(sin(ang)) * rad)
                if step == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
            }
            ctx.stroke(spiral, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 0.85, lineCap: .round))
            return
        }

        if action == .ticklish {
            var sq = Path()
            let dx = r * 1.05 * side
            sq.move(to: CGPoint(x: center.x + dx, y: center.y - r * 0.75))
            sq.addLine(to: CGPoint(x: center.x - dx * 0.55, y: center.y))
            sq.addLine(to: CGPoint(x: center.x + dx, y: center.y + r * 0.75))
            ctx.stroke(sq, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 1.05, lineCap: .round, lineJoin: .round))
            return
        }

        let isHappyArc: Bool = {
            if action == .happyPet || action == .brushed || action == .swallowing || isOnsen { return true }
            if action == .sippingTea && sin(t * 2.2) > 0.15 { return true }
            if case .eating = action { return true }
            return false
        }()

        if isHappyArc {
            var arc = Path()
            arc.move(to: CGPoint(x: center.x - r, y: center.y + r * 0.25))
            arc.addQuadCurve(
                to: CGPoint(x: center.x + r, y: center.y + r * 0.25),
                control: CGPoint(x: center.x, y: center.y - r * 1.05)
            )
            ctx.stroke(arc, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 1.1, lineCap: .round))
            return
        }

        if action == .sleeping || isBlinking {
            var lid = Path()
            lid.move(to: CGPoint(x: center.x - r, y: center.y))
            lid.addQuadCurve(
                to: CGPoint(x: center.x + r, y: center.y),
                control: CGPoint(x: center.x, y: center.y + r * 0.75)
            )
            ctx.stroke(lid, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
            return
        }

        let scaleMul: CGFloat = (isMouthOpenForDrop || isDangling || action == .butterflyChase) ? 1.16 : (isHoveringSelf ? 1.08 : 1.0)
        let er = r * scaleMul
        let eyeRect = CGRect(x: center.x - er, y: center.y - er * 1.08, width: er * 2.0, height: er * 2.16)
        ctx.fill(Path(ellipseIn: eyeRect), with: .color(Color(red: 0.14, green: 0.07, blue: 0.04)))

        let shineX = center.x - er * 0.28 + gx * er * 0.34
        let shineY = center.y - er * 0.34 + gy * er * 0.28
        let mainShine = CGRect(x: shineX - er * 0.34, y: shineY - er * 0.34, width: er * 0.68, height: er * 0.68)
        ctx.fill(Path(ellipseIn: mainShine), with: .color(.white))

        let subShine = CGRect(x: center.x + er * 0.22, y: center.y + er * 0.24, width: er * 0.30, height: er * 0.30)
        ctx.fill(Path(ellipseIn: subShine), with: .color(.white.opacity(0.85)))
    }

    // MARK: - Mouth
    private func drawMouth(
        in ctx: inout GraphicsContext,
        snoutCenter: CGPoint,
        snoutW: CGFloat,
        snoutH: CGFloat,
        s: CGFloat,
        strokeW: CGFloat,
        outlineColor: Color,
        isPlushie: Bool,
        t: Double
    ) {
        let mx = snoutCenter.x
        let philTop = snoutCenter.y - snoutH * (isPlushie ? 0.16 : 0.02)
        let mouthY = snoutCenter.y + snoutH * (isPlushie ? 0.20 : 0.24)

        if isPlushie {
            // Stitched dark brown 'T' nose & mouth line from plushie keychain photo!
            let stitchW = snoutW * 0.32
            var tStitch = Path()
            // Top crossbar
            tStitch.move(to: CGPoint(x: mx - stitchW * 0.5, y: philTop))
            tStitch.addLine(to: CGPoint(x: mx + stitchW * 0.5, y: philTop))
            // Downward stem
            tStitch.move(to: CGPoint(x: mx, y: philTop))
            tStitch.addLine(to: CGPoint(x: mx, y: mouthY))
            ctx.stroke(tStitch, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 1.15, lineCap: .round))

            if isMouthOpenForDrop || isDangling || action == .blowingBubbles {
                let mw = snoutW * 0.28
                let mh = snoutH * 0.26
                let mRect = CGRect(x: mx - mw * 0.5, y: mouthY - mh * 0.1, width: mw, height: mh)
                ctx.fill(Path(ellipseIn: mRect), with: .color(Color(red: 0.55, green: 0.16, blue: 0.20)))
                ctx.stroke(Path(ellipseIn: mRect), with: .color(outlineColor), lineWidth: strokeW * 0.8)
            }
            return
        }

        var phil = Path()
        phil.move(to: CGPoint(x: mx, y: philTop))
        phil.addLine(to: CGPoint(x: mx, y: mouthY))
        ctx.stroke(phil, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 0.85, lineCap: .round))

        if isMouthOpenForDrop || isDangling || action == .blowingBubbles {
            let mul: CGFloat = action == .blowingBubbles ? 0.26 : (isMouthOpenForDrop ? 0.48 : 0.34)
            let mw = snoutW * mul
            let mh = snoutH * mul
            let mRect = CGRect(x: mx - mw * 0.5, y: mouthY - mh * 0.2, width: mw, height: mh)
            ctx.fill(Path(ellipseIn: mRect), with: .color(Color(red: 0.55, green: 0.16, blue: 0.20)))
            ctx.stroke(Path(ellipseIn: mRect), with: .color(outlineColor), lineWidth: strokeW * 0.85)
            return
        }

        if action == .dizzy {
            var wavy = Path()
            wavy.move(to: CGPoint(x: mx - snoutW * 0.24, y: mouthY + 1))
            wavy.addCurve(
                to: CGPoint(x: mx + snoutW * 0.24, y: mouthY + 1),
                control1: CGPoint(x: mx - snoutW * 0.08, y: mouthY - s * 0.025),
                control2: CGPoint(x: mx + snoutW * 0.08, y: mouthY + s * 0.03)
            )
            ctx.stroke(wavy, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 0.85, lineCap: .round))
            return
        }

        let isBigSmile = (action == .happyPet || action == .brushed || action == .jugglingOranges || action == .stretching)
        let span = snoutW * (isBigSmile ? 0.30 : 0.24)
        let dip = snoutH * (isBigSmile ? 0.20 : 0.13)
        var wMouth = Path()
        wMouth.move(to: CGPoint(x: mx - span, y: mouthY))
        wMouth.addQuadCurve(to: CGPoint(x: mx, y: mouthY), control: CGPoint(x: mx - span * 0.5, y: mouthY + dip))
        wMouth.addQuadCurve(to: CGPoint(x: mx + span, y: mouthY), control: CGPoint(x: mx + span * 0.5, y: mouthY + dip))
        ctx.stroke(wMouth, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 0.9, lineCap: .round))
    }

    // MARK: - Front Paws & Rich Idle Activity Props!
    private func drawFrontPawsAndProps(
        in ctx: inout GraphicsContext,
        bodyW: CGFloat,
        bodyH: CGFloat,
        topY: CGFloat,
        snoutCenter: CGPoint,
        s: CGFloat,
        strokeW: CGFloat,
        pawColor: Color,
        outlineColor: Color,
        butterflyPos: CGPoint,
        t: Double
    ) {
        let pawW = s * 0.12
        let pawH = s * 0.095
        let baseY = -bodyH * 0.33

        // Compute paw positions per activity
        for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
            var pawCtx = ctx
            var px = side * bodyW * 0.22
            var py = baseY
            var angleDeg: Double = Double(side) * -14.0

            if isMouthOpenForDrop || isDangling {
                px = side * bodyW * 0.38
                py = baseY - s * 0.07
                angleDeg = Double(side) * 35.0 + sin(t * 14.0) * 10.0
            } else if action == .stretching {
                px = side * bodyW * 0.38
                py = baseY - s * 0.15 + CGFloat(sin(t * 5.2)) * s * 0.03 * side
                angleDeg = Double(side) * 48.0
            } else if action == .jugglingOranges {
                px = side * s * 0.25
                py = baseY - s * 0.02 + CGFloat(sin(t * 6.8 + (side > 0 ? .pi : 0))) * s * 0.055
                angleDeg = Double(side) * 28.0
            } else if action == .typingLaptop {
                px = side * bodyW * 0.18
                py = baseY + s * 0.06 + CGFloat(sin(t * 25.0 + (side > 0 ? .pi : 0))) * s * 0.024
                angleDeg = Double(side) * -8.0
            } else if action == .sippingTea {
                let sipLift = max(0, CGFloat(sin(t * 2.2))) * s * 0.07
                px = side * bodyW * 0.13
                py = baseY - sipLift
            } else if action == .readingBook {
                px = side * bodyW * 0.21
                py = baseY + s * 0.02
            } else if action == .happyPet || action == .ticklish || (isListeningMusic && side < 0) {
                px = side * bodyW * 0.32
                py = baseY - s * 0.05 + CGFloat(sin(t * 12.0 + Double(side))) * s * 0.025
                angleDeg = Double(side) * 28.0
            }

            pawCtx.translateBy(x: px, y: py)
            pawCtx.rotate(by: .degrees(angleDeg))
            let pRect = CGRect(x: -pawW * 0.5, y: -pawH * 0.5, width: pawW, height: pawH)
            let pPath = Path(roundedRect: pRect, cornerRadius: pawH * 0.48)
            pawCtx.fill(pPath, with: .color(pawColor))
            pawCtx.stroke(pPath, with: .color(outlineColor), lineWidth: strokeW * 0.85)
        }

        // --- Rich 2D Idle Showcase Props ---
        guard s > 34 else { return }

        switch action {
        case .eating(let emoji):
            let chewOff = CGFloat(sin(t * 15.0)) * s * 0.015
            ctx.draw(Text(emoji).font(.system(size: s * 0.18)), at: CGPoint(x: 0, y: baseY - s * 0.02 + chewOff))

        case .sippingTea:
            // Cute sage-green Matcha Yunomi Cup + rising steam!
            let sipLift = max(0, CGFloat(sin(t * 2.2))) * s * 0.07
            let cupW = s * 0.15, cupH = s * 0.15
            let cupY = baseY - cupH * 0.5 - sipLift
            let cupRect = CGRect(x: -cupW * 0.5, y: cupY, width: cupW, height: cupH)
            let cupPath = Path(roundedRect: cupRect, cornerRadius: cupW * 0.26)
            ctx.fill(cupPath, with: .color(Color(red: 0.56, green: 0.78, blue: 0.52)))
            ctx.stroke(cupPath, with: .color(outlineColor), lineWidth: strokeW * 0.85)
            // Steam curl
            let stPhase = (t * 0.9).truncatingRemainder(dividingBy: 1.0)
            let stY = cupY - s * 0.03 - CGFloat(stPhase) * s * 0.11
            var steam = Path()
            steam.move(to: CGPoint(x: 0, y: stY + s * 0.05))
            steam.addQuadCurve(to: CGPoint(x: 0, y: stY), control: CGPoint(x: s * 0.04, y: stY + s * 0.025))
            ctx.stroke(steam, with: .color(.white.opacity((1.0 - stPhase) * 0.7)), lineWidth: strokeW * 0.7)

        case .typingLaptop:
            // Miniature Silver MacBook with glowing screen & floating </> code!
            let lapW = s * 0.40, lapH = s * 0.22
            let lapY = -s * 0.20
            let lidRect = CGRect(x: -lapW * 0.5, y: lapY, width: lapW, height: lapH)
            let lidPath = Path(roundedRect: lidRect, cornerRadius: s * 0.028)
            ctx.fill(lidPath, with: .color(Color(white: 0.84)))
            ctx.stroke(lidPath, with: .color(outlineColor), lineWidth: strokeW * 0.85)
            // Base keyboard deck
            let baseDeck = CGRect(x: -lapW * 0.58, y: lapY + lapH - s * 0.02, width: lapW * 1.16, height: s * 0.038)
            ctx.fill(Path(roundedRect: baseDeck, cornerRadius: 3), with: .color(Color(white: 0.72)))
            ctx.stroke(Path(roundedRect: baseDeck, cornerRadius: 3), with: .color(outlineColor), lineWidth: strokeW * 0.75)
            // Glowing tiny paw emblem on laptop lid
            let glowR = s * 0.032
            ctx.fill(Path(ellipseIn: CGRect(x: -glowR, y: lapY + lapH * 0.5 - glowR, width: glowR * 2, height: glowR * 2)), with: .color(.cyan))
            // Floating </> code badge with crisp dark backing so it's readable on light & dark wallpapers!
            let codePhase = (t * 0.85).truncatingRemainder(dividingBy: 1.0)
            let badgePos = CGPoint(x: bodyW * 0.44, y: lapY - CGFloat(codePhase) * s * 0.18)
            let badgeAlpha = 1.0 - codePhase
            let badgeRect = CGRect(x: badgePos.x - s * 0.11, y: badgePos.y - s * 0.06, width: s * 0.22, height: s * 0.12)
            ctx.fill(Path(roundedRect: badgeRect, cornerRadius: 4), with: .color(.black.opacity(0.75 * badgeAlpha)))
            ctx.draw(
                Text("</>").font(.system(size: s * 0.085, weight: .heavy, design: .monospaced)).foregroundColor(.green.opacity(badgeAlpha)),
                at: badgePos
            )

        case .readingBook:
            // Open 2D Teal Hardcover Book in Maki's paws!
            let bkW = s * 0.36, bkH = s * 0.19
            let bkY = baseY - s * 0.03
            let bkRect = CGRect(x: -bkW * 0.5, y: bkY, width: bkW, height: bkH)
            ctx.fill(Path(roundedRect: bkRect, cornerRadius: 4), with: .color(Color(red: 0.18, green: 0.58, blue: 0.68)))
            ctx.stroke(Path(roundedRect: bkRect, cornerRadius: 4), with: .color(outlineColor), lineWidth: strokeW * 0.85)
            // Center spine + cream pages top strip
            let pages = CGRect(x: -bkW * 0.44, y: bkY - s * 0.025, width: bkW * 0.88, height: s * 0.04)
            ctx.fill(Path(roundedRect: pages, cornerRadius: 2), with: .color(Color(red: 0.98, green: 0.95, blue: 0.86)))
            ctx.stroke(Path(CGRect(x: -0.8, y: bkY, width: 1.6, height: bkH)), with: .color(outlineColor), lineWidth: strokeW * 0.7)

        default:
            if role == .mechanicSystem && !isMouthOpenForDrop && !action.isIdleShowActivity {
                var wCtx = ctx
                wCtx.translateBy(x: s * 0.02, y: baseY - s * 0.01)
                wCtx.rotate(by: .degrees(-28))
                let handle = CGRect(x: -s * 0.09, y: -s * 0.018, width: s * 0.18, height: s * 0.036)
                wCtx.fill(Path(roundedRect: handle, cornerRadius: 2), with: .color(Color(white: 0.82)))
                wCtx.stroke(Path(roundedRect: handle, cornerRadius: 2), with: .color(outlineColor), lineWidth: strokeW * 0.65)
                let head = CGRect(x: s * 0.06, y: -s * 0.04, width: s * 0.075, height: s * 0.08)
                wCtx.fill(Path(ellipseIn: head), with: .color(Color(white: 0.86)))
                wCtx.stroke(Path(ellipseIn: head), with: .color(outlineColor), lineWidth: strokeW * 0.65)
            }
        }
    }

    // MARK: - Foreground Aerial Props (3-Orange Circus Juggling, Butterfly, Soap Bubbles)
    private func drawForegroundAerialProps(
        in ctx: inout GraphicsContext,
        bodyW: CGFloat,
        bodyH: CGFloat,
        snoutCenter: CGPoint,
        s: CGFloat,
        strokeW: CGFloat,
        outlineColor: Color,
        butterflyPos: CGPoint,
        t: Double
    ) {
        switch action {
        case .jugglingOranges:
            let pawSpanX = s * 0.34          // Wide arc beyond Maki's ears, well within [-0.50*s, +0.50*s]
            let pawCatchY = -bodyH * 0.35    // Right at Maki's raised tossing paws (~ -0.22*s)
            let highPeakY = -s * 0.72        // High above Maki's forehead (-0.69*s) & safely below Canvas top (-0.90*s)!
            let lowPassY = -bodyH * 0.22     // Quick handoff pass across Maki's chest so the 3 oranges NEVER overlap!

            // Dashed golden circus loop trail so the toss arc is immediately readable
            var trail = Path()
            trail.move(to: CGPoint(x: -pawSpanX, y: pawCatchY))
            trail.addQuadCurve(
                to: CGPoint(x: pawSpanX, y: pawCatchY),
                control: CGPoint(x: 0, y: highPeakY - s * 0.16)
            )
            trail.addQuadCurve(
                to: CGPoint(x: -pawSpanX, y: pawCatchY),
                control: CGPoint(x: 0, y: lowPassY + s * 0.05)
            )
            ctx.stroke(
                trail,
                with: .color(Color(red: 1.0, green: 0.78, blue: 0.18).opacity(0.48)),
                style: StrokeStyle(lineWidth: max(1.0, strokeW * 0.58), lineCap: .round, dash: [3, 4])
            )

            // 3 Distinct Plump Juicy Yuzu Oranges (120° apart on a closed non-overlapping cascade loop!)
            let ow = s * 0.190
            let oh = s * 0.164
            for i in 0..<3 {
                let ph = t * 3.4 + Double(i) * (.pi * 2.0 / 3.0)
                let ox = CGFloat(cos(ph)) * pawSpanX
                let sVal = CGFloat(sin(ph))
                let oy: CGFloat = sVal >= 0
                    ? (pawCatchY + (highPeakY - pawCatchY) * sVal)
                    : (pawCatchY + (lowPassY - pawCatchY) * (-sVal))

                var oCtx = ctx
                oCtx.translateBy(x: ox, y: oy)
                oCtx.rotate(by: .degrees(cos(ph) * 20.0))

                // Soft warm glow + crisp dark drop shadow so each orange pops on BOTH dark & white windows!
                let haloR = CGRect(x: -ow * 0.62, y: -oh * 0.62, width: ow * 1.24, height: oh * 1.24)
                oCtx.fill(Path(ellipseIn: haloR), with: .color(Color.orange.opacity(0.24)))

                let shadowR = CGRect(x: -ow * 0.52, y: -oh * 0.44, width: ow * 1.04, height: oh * 1.04)
                oCtx.fill(Path(ellipseIn: shadowR), with: .color(Color(red: 0.18, green: 0.10, blue: 0.05).opacity(0.14)))

                // Rich vibrant tangerine-orange body gradient
                let oRect = CGRect(x: -ow * 0.5, y: -oh * 0.5, width: ow, height: oh)
                let oPath = Path(ellipseIn: oRect)
                oCtx.fill(
                    oPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 1.0, green: 0.80, blue: 0.20),
                            Color(red: 1.0, green: 0.50, blue: 0.04),
                            Color(red: 0.90, green: 0.34, blue: 0.02)
                        ]),
                        startPoint: CGPoint(x: -ow * 0.25, y: -oh * 0.5),
                        endPoint: CGPoint(x: ow * 0.25, y: oh * 0.5)
                    )
                )
                oCtx.stroke(oPath, with: .color(outlineColor), lineWidth: strokeW * 0.95)

                // Glossy white citrus specular shine + peel dimple dots
                let hlRect = CGRect(x: -ow * 0.27, y: -oh * 0.29, width: ow * 0.25, height: oh * 0.21)
                oCtx.fill(Path(ellipseIn: hlRect), with: .color(.white.opacity(0.88)))

                let dimple1 = CGRect(x: ow * 0.14, y: oh * 0.04, width: ow * 0.08, height: oh * 0.08)
                let dimple2 = CGRect(x: ow * 0.02, y: oh * 0.18, width: ow * 0.07, height: oh * 0.07)
                oCtx.fill(Path(ellipseIn: dimple1), with: .color(Color(red: 0.72, green: 0.22, blue: 0.02).opacity(0.55)))
                oCtx.fill(Path(ellipseIn: dimple2), with: .color(Color(red: 0.72, green: 0.22, blue: 0.02).opacity(0.55)))

                // Woody stem + vibrant emerald yuzu leaf on top of EVERY orange!
                var stem = Path()
                stem.move(to: CGPoint(x: 0, y: -oh * 0.45))
                stem.addLine(to: CGPoint(x: 0, y: -oh * 0.68))
                oCtx.stroke(stem, with: .color(outlineColor), style: StrokeStyle(lineWidth: strokeW * 0.85, lineCap: .round))

                var leaf = Path()
                leaf.move(to: CGPoint(x: 0, y: -oh * 0.52))
                leaf.addQuadCurve(
                    to: CGPoint(x: ow * 0.46, y: -oh * 0.74),
                    control: CGPoint(x: ow * 0.16, y: -oh * 0.92)
                )
                leaf.addQuadCurve(
                    to: CGPoint(x: 0, y: -oh * 0.52),
                    control: CGPoint(x: ow * 0.32, y: -oh * 0.40)
                )
                oCtx.fill(leaf, with: .color(Color(red: 0.18, green: 0.84, blue: 0.30)))
                oCtx.stroke(leaf, with: .color(outlineColor), lineWidth: strokeW * 0.68)
            }

        case .butterflyChase:
            var bfCtx = ctx
            bfCtx.translateBy(x: butterflyPos.x, y: butterflyPos.y)
            let flap = max(0.25, abs(CGFloat(sin(t * 16.0))))
            bfCtx.scaleBy(x: flap, y: 1.0)
            let wr = s * 0.068
            for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
                let topWing = CGRect(x: (side < 0 ? -wr * 1.1 : 0), y: -wr, width: wr * 1.1, height: wr)
                let botWing = CGRect(x: (side < 0 ? -wr * 0.85 : 0), y: -wr * 0.1, width: wr * 0.85, height: wr * 0.8)
                bfCtx.fill(Path(ellipseIn: topWing), with: .color(.yellow))
                bfCtx.stroke(Path(ellipseIn: topWing), with: .color(outlineColor), lineWidth: strokeW * 0.6)
                bfCtx.fill(Path(ellipseIn: botWing), with: .color(.cyan))
                bfCtx.stroke(Path(ellipseIn: botWing), with: .color(outlineColor), lineWidth: strokeW * 0.6)
            }

        case .blowingBubbles:
            for i in 0..<4 {
                let ph = (t * 0.65 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1.0)
                let bx = snoutCenter.x - s * 0.08 - CGFloat(ph) * s * 0.20 + CGFloat(sin(t * 4.0 + Double(i))) * s * 0.04
                let by = snoutCenter.y - CGFloat(ph) * s * 0.34
                let br = s * (0.032 + CGFloat(ph) * 0.044)
                let bRect = CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)
                let tint: Color = (i % 2 == 0) ? .cyan : .pink
                ctx.fill(Path(ellipseIn: bRect), with: .color(tint.opacity((1.0 - ph) * 0.38)))
                ctx.stroke(Path(ellipseIn: bRect), with: .color(.white.opacity((1.0 - ph) * 0.90)), lineWidth: strokeW * 0.7)
            }

        default:
            break
        }
    }

    // MARK: - Wooden Hinoki Onsen Tub
    private func drawOnsenTubFront(
        in ctx: inout GraphicsContext,
        s: CGFloat,
        strokeW: CGFloat,
        outlineColor: Color,
        t: Double
    ) {
        let tubW = s * 0.78
        let tubH = s * 0.28
        let tubTopY = -tubH

        let waveRect = CGRect(x: -tubW * 0.46, y: tubTopY - s * 0.04, width: tubW * 0.92, height: s * 0.09)
        ctx.fill(Path(ellipseIn: waveRect), with: .color(Color(red: 0.32, green: 0.88, blue: 0.92).opacity(0.88)))

        let floatY = CGFloat(sin(t * 3.0)) * s * 0.01
        let yuzuRect = CGRect(x: tubW * 0.20, y: tubTopY - s * 0.035 + floatY, width: s * 0.085, height: s * 0.07)
        ctx.fill(Path(ellipseIn: yuzuRect), with: .color(.orange))
        ctx.stroke(Path(ellipseIn: yuzuRect), with: .color(outlineColor), lineWidth: strokeW * 0.65)

        let wallRect = CGRect(x: -tubW * 0.5, y: tubTopY, width: tubW, height: tubH)
        let wallPath = Path(roundedRect: wallRect, cornerRadius: s * 0.045)
        ctx.fill(
            wallPath,
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.88, green: 0.70, blue: 0.48), Color(red: 0.74, green: 0.54, blue: 0.34)]),
                startPoint: CGPoint(x: 0, y: tubTopY),
                endPoint: CGPoint(x: 0, y: 0)
            )
        )
        ctx.stroke(wallPath, with: .color(outlineColor), lineWidth: strokeW)

        let bandRect = CGRect(x: -tubW * 0.5, y: tubTopY + tubH * 0.48, width: tubW, height: s * 0.032)
        ctx.fill(Path(bandRect), with: .color(Color(red: 0.66, green: 0.40, blue: 0.22)))

        if s > 40 {
            for i in 0..<2 {
                let phase = (t * 0.55 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1.0)
                let sy = tubTopY - s * 0.08 - CGFloat(phase) * s * 0.22
                let sx = (i == 0 ? -tubW * 0.34 : tubW * 0.34) + CGFloat(sin(t * 2.5 + Double(i))) * s * 0.02
                let alpha = sin(phase * .pi) * 0.45
                let sr = s * (0.045 + CGFloat(phase) * 0.025)
                ctx.fill(Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2)), with: .color(.white.opacity(alpha)))
            }
        }
    }

    // MARK: - Per-Menu 2D Costumes & Hats
    private func drawCostumeHeadgear(
        in ctx: inout GraphicsContext,
        headCenterY: CGFloat,
        topY: CGFloat,
        bodyW: CGFloat,
        eyeY: CGFloat,
        eyeSpread: CGFloat,
        faceShiftX: CGFloat,
        faceShiftY: CGFloat,
        s: CGFloat,
        strokeW: CGFloat,
        outlineColor: Color,
        t: Double
    ) {
        let hx = faceShiftX * 0.55
        let hy = topY + faceShiftY * 0.35

        // 1. Sleek Matte Black DJ Headphones when listening to music (unless relaxing in onsen)
        if (role == .djMusic || isListeningMusic) && !isOnsen {
            drawDJHeadphones(in: &ctx, hx: hx, topY: hy, bodyW: bodyW, headCenterY: headCenterY, s: s, strokeW: strokeW, outlineColor: outlineColor, t: t)
        }

        switch role {
        case .habitat, .djMusic:
            break

        case .scholarNotes:
            let gxCenter = faceShiftX * 0.85
            let gr = s * 0.072
            let gold = Color(red: 0.96, green: 0.78, blue: 0.26)
            for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
                let lRect = CGRect(x: gxCenter + side * eyeSpread - gr, y: eyeY - gr, width: gr * 2, height: gr * 2)
                ctx.fill(Path(ellipseIn: lRect), with: .color(.white.opacity(0.14)))
                ctx.stroke(Path(ellipseIn: lRect), with: .color(gold), lineWidth: max(1.2, strokeW * 0.95))
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: gxCenter - eyeSpread + gr, y: eyeY - gr * 0.1))
            bridge.addQuadCurve(
                to: CGPoint(x: gxCenter + eyeSpread - gr, y: eyeY - gr * 0.1),
                control: CGPoint(x: gxCenter, y: eyeY - gr * 0.45)
            )
            ctx.stroke(bridge, with: .color(gold), lineWidth: max(1.1, strokeW * 0.85))

        case .pilotLauncher:
            let gyBand = hy + s * 0.075
            let bandRect = CGRect(x: hx - bodyW * 0.42, y: gyBand - s * 0.02, width: bodyW * 0.84, height: s * 0.04)
            ctx.fill(Path(roundedRect: bandRect, cornerRadius: 3), with: .color(Color(red: 0.35, green: 0.22, blue: 0.14)))
            for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
                let lw = s * 0.13, lh = s * 0.095
                let lr = CGRect(x: hx + side * s * 0.08 - lw * 0.5, y: gyBand - lh * 0.5, width: lw, height: lh)
                ctx.fill(Path(roundedRect: lr, cornerRadius: lh * 0.4), with: .color(Color(red: 0.35, green: 0.86, blue: 0.96)))
                ctx.stroke(Path(roundedRect: lr, cornerRadius: lh * 0.4), with: .color(Color(white: 0.86)), lineWidth: strokeW * 1.05)
            }

        case .builderTray:
            let hw = bodyW * 0.78
            let hh = s * 0.18
            var dome = Path()
            dome.addArc(center: CGPoint(x: hx, y: hy + s * 0.07), radius: hw * 0.46, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            dome.closeSubpath()
            ctx.fill(dome, with: .color(Color(red: 1.0, green: 0.82, blue: 0.12)))
            ctx.stroke(dome, with: .color(outlineColor), lineWidth: strokeW * 0.9)

            let brim = CGRect(x: hx - hw * 0.54, y: hy + s * 0.055, width: hw * 1.08, height: hh * 0.24)
            ctx.fill(Path(roundedRect: brim, cornerRadius: 4), with: .color(Color(red: 0.96, green: 0.74, blue: 0.06)))
            ctx.stroke(Path(roundedRect: brim, cornerRadius: 4), with: .color(outlineColor), lineWidth: strokeW * 0.85)

        case .mechanicSystem:
            let vw = bodyW * 0.76
            let vh = s * 0.068
            let vRect = CGRect(x: hx - vw * 0.5, y: hy + s * 0.055, width: vw, height: vh)
            ctx.fill(Path(roundedRect: vRect, cornerRadius: vh * 0.5), with: .color(Color(red: 0.12, green: 0.20, blue: 0.28)))
            ctx.stroke(Path(roundedRect: vRect, cornerRadius: vh * 0.5), with: .color(outlineColor), lineWidth: strokeW * 0.8)
            let glowRect = vRect.insetBy(dx: vw * 0.12, dy: vh * 0.24)
            let pulse = 0.75 + 0.25 * sin(t * 5.0)
            ctx.fill(Path(roundedRect: glowRect, cornerRadius: vh * 0.3), with: .color(Color.cyan.opacity(pulse)))

        case .detectiveClipboard:
            let cw = bodyW * 0.78
            var cap = Path()
            cap.addArc(center: CGPoint(x: hx, y: hy + s * 0.065), radius: cw * 0.45, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            cap.closeSubpath()
            let tweed = Color(red: 0.52, green: 0.40, blue: 0.29)
            ctx.fill(cap, with: .color(tweed))
            ctx.stroke(cap, with: .color(outlineColor), lineWidth: strokeW * 0.85)
            let bill = CGRect(x: hx - cw * 0.56, y: hy + s * 0.05, width: cw * 1.12, height: s * 0.036)
            ctx.fill(Path(roundedRect: bill, cornerRadius: 3), with: .color(tweed.opacity(0.92)))
            ctx.stroke(Path(roundedRect: bill, cornerRadius: 3), with: .color(outlineColor), lineWidth: strokeW * 0.8)

            let mr = s * 0.072
            let mx = faceShiftX * 0.85 + eyeSpread
            let mRect = CGRect(x: mx - mr, y: eyeY - mr, width: mr * 2, height: mr * 2)
            ctx.fill(Path(ellipseIn: mRect), with: .color(Color.cyan.opacity(0.14)))
            ctx.stroke(Path(ellipseIn: mRect), with: .color(.yellow), lineWidth: strokeW * 0.9)

        case .senseiTimer:
            let bw = bodyW * 0.82
            let bh = s * 0.064
            let bRect = CGRect(x: hx - bw * 0.5, y: hy + s * 0.055, width: bw, height: bh)
            ctx.fill(Path(roundedRect: bRect, cornerRadius: bh * 0.4), with: .color(.white))
            ctx.stroke(Path(roundedRect: bRect, cornerRadius: bh * 0.4), with: .color(outlineColor), lineWidth: strokeW * 0.8)
            let sunR = bh * 0.36
            ctx.fill(Path(ellipseIn: CGRect(x: hx - sunR, y: bRect.midY - sunR, width: sunR * 2, height: sunR * 2)), with: .color(.red))
        }

        // 3. Stacked Yuzu Oranges on Head (always drawn on top of head whenever orangesOnHead > 0!)
        drawOrangesOnHead(in: &ctx, hx: hx, hy: hy, s: s, strokeW: strokeW, outlineColor: outlineColor, t: t)
    }

    // MARK: - Stacked Yuzu Oranges on Head
    private func drawOrangesOnHead(
        in ctx: inout GraphicsContext,
        hx: CGFloat,
        hy: CGFloat,
        s: CGFloat,
        strokeW: CGFloat,
        outlineColor: Color,
        t: Double
    ) {
        guard orangesOnHead > 0 && action != .jugglingOranges && action != .brushed else { return }
        let count = min(3, orangesOnHead)
        var curY = hy + s * 0.018
        for i in 0..<count {
            let scale = 1.0 - CGFloat(i) * 0.13
            let ow = s * 0.185 * scale
            let oh = s * 0.145 * scale
            let wobble = CGFloat(sin(t * 3.0 + Double(i))) * s * 0.007 * CGFloat(i + 1)
            let ox = hx + wobble
            let oRect = CGRect(x: ox - ow * 0.5, y: curY - oh, width: ow, height: oh)

            // Small contact drop-shadow under upper stacked oranges
            if i > 0 {
                let cShadowRect = CGRect(x: ox - ow * 0.44, y: curY - oh * 0.28, width: ow * 0.88, height: oh * 0.32)
                ctx.fill(Path(ellipseIn: cShadowRect), with: .color(Color(red: 0.18, green: 0.10, blue: 0.05).opacity(0.12)))
            }

            // Rich juicy tangerine gradient body
            let oPath = Path(ellipseIn: oRect)
            ctx.fill(
                oPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.80, blue: 0.22),
                        Color(red: 1.0, green: 0.52, blue: 0.06),
                        Color(red: 0.88, green: 0.34, blue: 0.02)
                    ]),
                    startPoint: CGPoint(x: oRect.minX + ow * 0.25, y: oRect.minY),
                    endPoint: CGPoint(x: oRect.maxX - ow * 0.20, y: oRect.maxY)
                )
            )
            ctx.stroke(oPath, with: .color(outlineColor), lineWidth: strokeW * 0.85)

            // Glossy citrus specular highlight
            let hlRect = CGRect(x: oRect.minX + ow * 0.20, y: oRect.minY + oh * 0.16, width: ow * 0.24, height: oh * 0.20)
            ctx.fill(Path(ellipseIn: hlRect), with: .color(Color.white.opacity(0.85)))

            // Tiny textured peel dimple
            let dimpleR = CGRect(x: oRect.maxX - ow * 0.32, y: oRect.maxY - oh * 0.38, width: ow * 0.09, height: oh * 0.09)
            ctx.fill(Path(ellipseIn: dimpleR), with: .color(Color(red: 0.72, green: 0.22, blue: 0.02).opacity(0.48)))

            // Topmost orange gets a cute little brown stem + fresh green yuzu leaf!
            if i == count - 1 {
                let topCenter = CGPoint(x: ox, y: oRect.minY)

                // Tiny brown stem
                var stem = Path()
                stem.move(to: topCenter)
                stem.addQuadCurve(to: CGPoint(x: topCenter.x + ow * 0.08, y: topCenter.y - oh * 0.24), control: CGPoint(x: topCenter.x, y: topCenter.y - oh * 0.14))
                ctx.stroke(stem, with: .color(outlineColor), style: StrokeStyle(lineWidth: max(1.1, strokeW * 0.75), lineCap: .round))

                // Fresh green leaf
                let lx = topCenter.x + ow * 0.06
                let ly = topCenter.y - oh * 0.16
                var leaf = Path()
                leaf.move(to: CGPoint(x: lx, y: ly))
                leaf.addQuadCurve(to: CGPoint(x: lx + ow * 0.44, y: ly - oh * 0.26), control: CGPoint(x: lx + ow * 0.16, y: ly - oh * 0.46))
                leaf.addQuadCurve(to: CGPoint(x: lx, y: ly), control: CGPoint(x: lx + ow * 0.26, y: ly + oh * 0.04))
                leaf.closeSubpath()

                ctx.fill(
                    leaf,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.45, green: 0.88, blue: 0.36),
                            Color(red: 0.22, green: 0.65, blue: 0.24)
                        ]),
                        startPoint: CGPoint(x: lx, y: ly),
                        endPoint: CGPoint(x: lx + ow * 0.44, y: ly - oh * 0.26)
                    )
                )
                ctx.stroke(leaf, with: .color(outlineColor), lineWidth: strokeW * 0.65)
            }

            curY -= oh * 0.82
        }
    }

    // MARK: - Sleek Matte Black DJ Headphones
    private func drawDJHeadphones(
        in ctx: inout GraphicsContext,
        hx: CGFloat,
        topY: CGFloat,
        bodyW: CGFloat,
        headCenterY: CGFloat,
        s: CGFloat,
        strokeW: CGFloat,
        outlineColor: Color,
        t: Double
    ) {
        let span = bodyW * 0.49
        let cupY = headCenterY - s * 0.01
        var arch = Path()
        arch.move(to: CGPoint(x: hx - span, y: cupY))
        arch.addQuadCurve(to: CGPoint(x: hx + span, y: cupY), control: CGPoint(x: hx, y: topY - s * 0.14))
        ctx.stroke(arch, with: .color(Color(white: 0.12)), style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))

        // Sleek matte black earcups with subtle dark slate outline (no neon green!)
        for side in [-1.0 as CGFloat, 1.0 as CGFloat] {
            let cw = s * 0.095, ch = s * 0.16
            let cr = CGRect(x: hx + side * span - cw * 0.5, y: cupY - ch * 0.5, width: cw, height: ch)
            let cupPath = Path(roundedRect: cr, cornerRadius: cw * 0.45)
            ctx.fill(cupPath, with: .color(Color(red: 0.11, green: 0.11, blue: 0.13)))
            ctx.stroke(cupPath, with: .color(Color(white: 0.28)), lineWidth: strokeW * 0.9)

            let ir = cr.insetBy(dx: cw * 0.20, dy: ch * 0.20)
            ctx.stroke(Path(roundedRect: ir, cornerRadius: cw * 0.25), with: .color(Color(white: 0.20)), lineWidth: strokeW * 0.6)
        }
    }
}
