import AppKit
import Foundation

// Generates a modern app icon:
// - Calm dark gradient background (slate -> grape, aligned with app theme seeds)
// - Bold, minimal "W" mark (Win the Year) with subtle shadow for depth
//
// Usage:
//   swift tools/icon_gen/generate_icons.swift <outputDir>
//
// Outputs:
//   app_icon_master_1024.png
//   android_adaptive_foreground_432.png
//   android_adaptive_background_432.png

func hex(_ value: UInt32) -> NSColor {
  let r = CGFloat((value >> 16) & 0xFF) / 255.0
  let g = CGFloat((value >> 8) & 0xFF) / 255.0
  let b = CGFloat(value & 0xFF) / 255.0
  return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
}

func writePNG(image: NSImage, to url: URL) throws {
  guard let tiff = image.tiffRepresentation else {
    throw NSError(domain: "icon_gen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing TIFF representation"])
  }
  guard let rep = NSBitmapImageRep(data: tiff) else {
    throw NSError(domain: "icon_gen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing bitmap rep"])
  }
  rep.size = image.size
  guard let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "icon_gen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
  }
  try png.write(to: url, options: .atomic)
}

func makeWMarkPath(in rect: CGRect) -> NSBezierPath {
  // Build a geometric "W" using a polyline with rounded caps/join.
  // Keep it well inside safe bounds to look good on iOS masks + Android circles.
  let w = rect.width
  let h = rect.height

  let leftX = rect.minX + w * 0.22
  let rightX = rect.minX + w * 0.78
  // macOS drawing coordinates increase upward (origin bottom-left), so "top" needs a larger Y.
  let topY = rect.minY + h * 0.76
  let bottomY = rect.minY + h * 0.28

  let p1 = CGPoint(x: leftX, y: topY)
  let p2 = CGPoint(x: rect.minX + w * 0.35, y: bottomY)
  // Peak in the center to read clearly as a "W" (previously this was too low and read like an "M").
  let p3 = CGPoint(x: rect.minX + w * 0.50, y: topY + (bottomY - topY) * 0.10)
  let p4 = CGPoint(x: rect.minX + w * 0.65, y: bottomY)
  let p5 = CGPoint(x: rightX, y: topY)

  let path = NSBezierPath()
  path.move(to: p1)
  path.line(to: p2)
  path.line(to: p3)
  path.line(to: p4)
  path.line(to: p5)
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  return path
}

func pngData(for image: NSImage) throws -> Data {
  guard let tiff = image.tiffRepresentation else {
    throw NSError(domain: "icon_gen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing TIFF representation"])
  }
  guard let rep = NSBitmapImageRep(data: tiff) else {
    throw NSError(domain: "icon_gen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing bitmap rep"])
  }
  rep.size = image.size
  guard let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "icon_gen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
  }
  return png
}

func writeIco(withPngData png: Data, size: Int, to url: URL) throws {
  // ICO container with a single PNG image (supported by Windows Vista+ and modern tooling).
  // ICONDIR (6 bytes) + ICONDIRENTRY (16 bytes) + PNG bytes.
  func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
  func le32(_ v: UInt32) -> [UInt8] {
    [
      UInt8(v & 0xFF),
      UInt8((v >> 8) & 0xFF),
      UInt8((v >> 16) & 0xFF),
      UInt8((v >> 24) & 0xFF),
    ]
  }

  var out = Data()
  // Reserved (0), Type (1 = icon), Count (1)
  out.append(contentsOf: le16(0))
  out.append(contentsOf: le16(1))
  out.append(contentsOf: le16(1))

  // Entry
  let dimByte: UInt8 = size >= 256 ? 0 : UInt8(size) // 0 means 256 in ICO spec
  out.append(dimByte) // width
  out.append(dimByte) // height
  out.append(0) // color count
  out.append(0) // reserved
  out.append(contentsOf: le16(1)) // planes
  out.append(contentsOf: le16(32)) // bit count
  out.append(contentsOf: le32(UInt32(png.count))) // bytes in res
  out.append(contentsOf: le32(UInt32(6 + 16))) // image offset

  out.append(png)
  try out.write(to: url, options: .atomic)
}

func drawMasterIcon(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocusFlipped(false)
  defer { image.unlockFocus() }

  let rect = CGRect(x: 0, y: 0, width: size, height: size)

  // Background gradient (slate -> grape) with a subtle highlight blob.
  let bg1 = hex(0x1F2937) // slate seed
  let bg2 = hex(0x4C1D95) // grape seed
  let gradient = NSGradient(colors: [bg1, bg2])!
  gradient.draw(in: rect, angle: 35)

  // Highlight glow (subtle, modern depth).
  NSGraphicsContext.current?.saveGraphicsState()
  let glowPath = NSBezierPath(ovalIn: CGRect(
    x: size * 0.10,
    y: size * 0.55,
    width: size * 0.60,
    height: size * 0.60
  ))
  hex(0xFFFFFF).withAlphaComponent(0.10).setFill()
  glowPath.fill()
  NSGraphicsContext.current?.restoreGraphicsState()

  // Foreground mark (white-ish with shadow).
  let markRect = rect.insetBy(dx: size * 0.12, dy: size * 0.12)
  let wPath = makeWMarkPath(in: markRect)
  wPath.lineWidth = size * 0.085

  NSGraphicsContext.current?.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowBlurRadius = size * 0.045
  shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
  shadow.set()

  NSColor.white.withAlphaComponent(0.94).setStroke()
  wPath.stroke()
  NSGraphicsContext.current?.restoreGraphicsState()

  // Small accent notch (adds uniqueness without clutter).
  let accent = NSBezierPath(roundedRect: CGRect(
    x: size * 0.68,
    y: size * 0.30,
    width: size * 0.14,
    height: size * 0.06
  ), xRadius: size * 0.03, yRadius: size * 0.03)
  hex(0xF59E0B).withAlphaComponent(0.95).setFill() // warm accent (sunset vibe)
  accent.fill()

  return image
}

func drawAndroidAdaptiveBackground(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocusFlipped(false)
  defer { image.unlockFocus() }
  let rect = CGRect(x: 0, y: 0, width: size, height: size)

  let bg1 = hex(0x1F2937)
  let bg2 = hex(0x4C1D95)
  let gradient = NSGradient(colors: [bg1, bg2])!
  gradient.draw(in: rect, angle: 35)

  // Subtle highlight.
  let glowPath = NSBezierPath(ovalIn: CGRect(
    x: size * 0.08,
    y: size * 0.52,
    width: size * 0.64,
    height: size * 0.64
  ))
  hex(0xFFFFFF).withAlphaComponent(0.10).setFill()
  glowPath.fill()

  return image
}

func drawAndroidAdaptiveForeground(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocusFlipped(false)
  defer { image.unlockFocus() }

  // Transparent background; only the mark.
  NSColor.clear.setFill()
  CGRect(x: 0, y: 0, width: size, height: size).fill()

  // Keep foreground in safe zone.
  let safe = CGRect(x: size * 0.16, y: size * 0.16, width: size * 0.68, height: size * 0.68)
  let wPath = makeWMarkPath(in: safe)
  wPath.lineWidth = size * 0.090

  let shadow = NSShadow()
  shadow.shadowBlurRadius = size * 0.040
  shadow.shadowOffset = NSSize(width: 0, height: -size * 0.015)
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)

  NSGraphicsContext.current?.saveGraphicsState()
  shadow.set()
  NSColor.white.withAlphaComponent(0.96).setStroke()
  wPath.stroke()
  NSGraphicsContext.current?.restoreGraphicsState()

  return image
}

let args = CommandLine.arguments
guard args.count >= 2 else {
  fputs("Usage: swift generate_icons.swift <outputDir>\\n", stderr)
  exit(2)
}

let outputDir = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let master = drawMasterIcon(size: 1024)
try writePNG(image: master, to: outputDir.appendingPathComponent("app_icon_master_1024.png"))

let androidBg = drawAndroidAdaptiveBackground(size: 432)
try writePNG(image: androidBg, to: outputDir.appendingPathComponent("android_adaptive_background_432.png"))

let androidFg = drawAndroidAdaptiveForeground(size: 432)
try writePNG(image: androidFg, to: outputDir.appendingPathComponent("android_adaptive_foreground_432.png"))

let winPng256 = try pngData(for: drawMasterIcon(size: 256))
try writeIco(withPngData: winPng256, size: 256, to: outputDir.appendingPathComponent("app_icon_256.ico"))

print("Wrote icons to \(outputDir.path)")

