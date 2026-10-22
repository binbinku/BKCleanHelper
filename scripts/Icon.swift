import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)

func render(size: Int) throws -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(size) / 1024
    let rect = NSRect(x: 88 * scale, y: 88 * scale, width: 848 * scale, height: 848 * scale)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 188 * scale, yRadius: 188 * scale)
    NSGradient(starting: NSColor(srgbRed: 0.28, green: 0.68, blue: 1, alpha: 1),
               ending: NSColor(srgbRed: 0.08, green: 0.37, blue: 0.88, alpha: 1))!.draw(in: shape, angle: -90)
    let configuration = NSImage.SymbolConfiguration(pointSize: 420 * scale, weight: .regular)
        .applying(.init(paletteColors: [.white]))
    let keyboard = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)!
        .withSymbolConfiguration(configuration)!
    let keyWidth = 584 * scale
    let keyHeight = keyWidth * keyboard.size.height / keyboard.size.width
    keyboard.draw(in: NSRect(x: (CGFloat(size) - keyWidth) / 2, y: 342 * scale,
                            width: keyWidth, height: keyHeight))
    let sparkle = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)!
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 112 * scale, weight: .medium)
            .applying(.init(paletteColors: [.white])))!
    sparkle.draw(in: NSRect(x: 686 * scale, y: 634 * scale, width: 116 * scale, height: 116 * scale))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let suffix = factor == 2 ? "@2x" : ""
        let filename = "icon_\(base)x\(base)\(suffix).png"
        try render(size: base * factor).write(to: URL(fileURLWithPath: destination).appendingPathComponent(filename))
    }
}
