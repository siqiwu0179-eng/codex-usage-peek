import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: prepare-icon.swift <input.png> <output.png>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let size = 1024

guard let input = NSImage(contentsOf: inputURL) else {
    fputs("Unable to read input image: \(inputURL.path)\n", stderr)
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create output bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
defer { NSGraphicsContext.restoreGraphicsState() }

guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create graphics context\n", stderr)
    exit(1)
}

NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
let bounds = NSRect(x: 0, y: 0, width: size, height: size)
graphics.cgContext.clear(bounds)

// Rebuild the tile on true transparency so the generated preview's baked-in
// checkerboard never reaches the shipped application icon.
let tile = NSBezierPath(roundedRect: bounds, xRadius: 224, yRadius: 224)
tile.addClip()
NSColor.white.setFill()
bounds.fill()

// The accepted knot and 70/30 progress ring sit entirely inside this circle.
// Restricting the reference artwork to it preserves those details while the
// outer tile remains a clean, neutral white.
NSGraphicsContext.saveGraphicsState()
NSBezierPath(ovalIn: bounds.insetBy(dx: 103, dy: 103)).addClip()
input.draw(
    in: bounds,
    from: NSRect(origin: .zero, size: input.size),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode output PNG\n", stderr)
    exit(1)
}

try png.write(to: outputURL, options: .atomic)
