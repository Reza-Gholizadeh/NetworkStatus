import AppKit

let sizes: [(name: String, px: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func tintedSymbol(named symbolName: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let configured = base.withSymbolConfiguration(config) else { return nil }

    let tinted = NSImage(size: configured.size)
    tinted.lockFocus()
    color.set()
    NSRect(origin: .zero, size: configured.size).fill()
    configured.draw(
        at: .zero, from: .zero,
        operation: .destinationIn, fraction: 1.0
    )
    tinted.unlockFocus()
    return tinted
}

func renderIcon(pixelSize: CGFloat) -> Data? {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let cornerRadius = pixelSize * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()

    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.20, green: 0.55, blue: 1.00, alpha: 1.0),
            NSColor(calibratedRed: 0.03, green: 0.16, blue: 0.45, alpha: 1.0),
        ]
    )
    gradient?.draw(in: bgPath, angle: -90)

    if let symbol = tintedSymbol(named: "wifi", pointSize: pixelSize * 0.5, color: .white) {
        let origin = NSPoint(
            x: (pixelSize - symbol.size.width) / 2,
            y: (pixelSize - symbol.size.height) / 2.2
        )
        symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { return nil }
    return png
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for (name, px) in sizes {
    guard let data = renderIcon(pixelSize: px) else {
        FileHandle.standardError.write("Failed to render \(name)\n".data(using: .utf8)!)
        continue
    }
    let path = "\(outputDir)/\(name).png"
    try? data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}
