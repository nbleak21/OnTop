// Copyright (c) 2026 OnTop contributors
// SPDX-License-Identifier: MIT

// Generates OnTop's app icon as an .iconset of PNGs, drawn with CoreGraphics.
// Usage: swift Tools/make_icon.swift [output.iconset]
// Then:  iconutil -c icns <output.iconset> -o Resources/AppIcon.icns
//
// Concept: a dark rounded tile with four ascending bars in a green→red
// utilization gradient — a system-monitor "meter" that stays legible at 16px.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: sRGB, components: [r / 255, g / 255, b / 255, a])!
}

func drawIcon(_ ctx: CGContext, _ s: CGFloat) {
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Rounded tile with a macOS-style corner radius.
    let margin = s * 0.085
    let tile = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let radius = tile.width * 0.2237
    let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft drop shadow (baked into the master so it looks right in Finder).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: rgb(0, 0, 0, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(rgb(18, 22, 32))
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient + a faint top sheen, clipped to the tile.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: sRGB, colors: [rgb(44, 52, 72), rgb(15, 19, 29)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: tile.midX, y: tile.maxY),
                           end: CGPoint(x: tile.midX, y: tile.minY),
                           options: [])
    let sheen = CGGradient(colorsSpace: sRGB, colors: [rgb(255, 255, 255, 0.10), rgb(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen,
                           start: CGPoint(x: tile.midX, y: tile.maxY),
                           end: CGPoint(x: tile.midX, y: tile.midY),
                           options: [])

    // Four ascending bars on a shared baseline.
    let content = tile.insetBy(dx: tile.width * 0.21, dy: tile.height * 0.22)
    let count = 4
    let gapRatio: CGFloat = 0.36
    let barWidth = content.width / (CGFloat(count) + CGFloat(count - 1) * gapRatio)
    let gap = barWidth * gapRatio
    let heights: [CGFloat] = [0.36, 0.54, 0.74, 1.0]
    let colors = [rgb(53, 208, 127), rgb(255, 194, 75), rgb(255, 138, 61), rgb(255, 90, 95)]

    var x = content.minX
    for i in 0..<count {
        let h = content.height * heights[i]
        let bar = CGRect(x: x, y: content.minY, width: barWidth, height: h)
        let r = min(barWidth * 0.30, h * 0.5)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.setFillColor(colors[i])
        ctx.fillPath()
        x += barWidth + gap
    }
    ctx.restoreGState()
}

func render(_ px: Int, to path: String) {
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                              bytesPerRow: 0, space: sRGB,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    ctx.clear(CGRect(x: 0, y: 0, width: px, height: px))
    drawIcon(ctx, CGFloat(px))
    guard let image = ctx.makeImage() else { return }
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let renditions: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in renditions {
    render(px, to: outDir + "/" + name)
}
print("Wrote \(renditions.count) PNGs to \(outDir)")
