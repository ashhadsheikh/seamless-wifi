import AppKit
import CoreGraphics
import Foundation

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmap = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let background = CGPath(roundedRect: bounds, cornerWidth: 220, cornerHeight: 220, transform: nil)
bitmap.addPath(background)
bitmap.clip()

let colors = [
    CGColor(red: 0.035, green: 0.20, blue: 0.48, alpha: 1),
    CGColor(red: 0.055, green: 0.48, blue: 0.91, alpha: 1),
    CGColor(red: 0.24, green: 0.72, blue: 0.98, alpha: 1)
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.56, 1])!
bitmap.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 90), end: CGPoint(x: 900, y: 930), options: [])

// Soft highlight gives the mark depth while keeping the silhouette clean at small sizes.
bitmap.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.055))
bitmap.fillEllipse(in: CGRect(x: 180, y: 515, width: 690, height: 690))

bitmap.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
bitmap.setLineWidth(52)
bitmap.setLineCap(.round)
bitmap.setLineJoin(.round)

let arcs: [CGPath] = [
    {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 190, y: 600))
        p.addCurve(to: CGPoint(x: 834, y: 600), control1: CGPoint(x: 360, y: 800), control2: CGPoint(x: 664, y: 800))
        return p
    }(),
    {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 300, y: 465))
        p.addCurve(to: CGPoint(x: 724, y: 465), control1: CGPoint(x: 420, y: 590), control2: CGPoint(x: 604, y: 590))
        return p
    }(),
    {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 416, y: 340))
        p.addCurve(to: CGPoint(x: 608, y: 340), control1: CGPoint(x: 470, y: 395), control2: CGPoint(x: 554, y: 395))
        return p
    }()
]
for arc in arcs { bitmap.addPath(arc); bitmap.strokePath() }

bitmap.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.98))
bitmap.fillEllipse(in: CGRect(x: 474, y: 172, width: 76, height: 76))

// Small green connection badge.
let badge = CGRect(x: 728, y: 168, width: 150, height: 150)
bitmap.setFillColor(CGColor(red: 0.035, green: 0.20, blue: 0.48, alpha: 1))
bitmap.fillEllipse(in: badge.insetBy(dx: -13, dy: -13))
bitmap.setFillColor(CGColor(red: 0.15, green: 0.83, blue: 0.48, alpha: 1))
bitmap.fillEllipse(in: badge)
bitmap.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
bitmap.setLineWidth(20)
bitmap.setLineCap(.round)
bitmap.setLineJoin(.round)
let check = CGMutablePath()
check.move(to: CGPoint(x: 770, y: 240))
check.addLine(to: CGPoint(x: 808, y: 204))
check.addLine(to: CGPoint(x: 842, y: 238))
bitmap.addPath(check)
bitmap.strokePath()

let image = bitmap.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "Resources/SeamlessWiFi.png") as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination))
