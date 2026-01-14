import AppKit
import Foundation

// Generates a stoic, professional app icon set:
// - Calm near-black gradient background (charcoal -> slate)
// - Minimal "W" mark (Win the Year) with restrained depth (no playful accent)
//
// Usage:
//   swift tools/icon_gen/generate_icons.swift <outputDir> [repoRoot]
//
// Outputs:
//   app_icon_master_1024.png
//   android_adaptive_foreground_432.png
//   android_adaptive_background_432.png
//
// If repoRoot is provided, also writes platform-specific icons into:
// - ios/Runner/Assets.xcassets/AppIcon.appiconset
// - macos/Runner/Assets.xcassets/AppIcon.appiconset
// - android/app/src/main/res (mipmaps + adaptive layers)
// - web/icons
// - windows/runner/resources/app_icon.ico

func hex(_ value: UInt32) -> NSColor {
  let r = CGFloat((value >> 16) & 0xFF) / 255.0
  let g = CGFloat((value >> 8) & 0xFF) / 255.0
  let b = CGFloat(value & 0xFF) / 255.0
  return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
}

// IMPORTANT:
// Do NOT rely on NSImage.lockFocus() to produce pixel-perfect outputs. On Retina Macs, AppKit
// will often rasterize at 2x backing scale, which generates PNGs with *double* the pixel dimensions
// (and breaks Xcode asset catalogs).
//
// Instead: render into an explicit NSBitmapImageRep with the desired pixel dimensions.
func renderPNG(sizePx: Int, draw: (CGRect) -> Void) throws -> Data {
  guard sizePx > 0 else {
    throw NSError(domain: "icon_gen", code: 11, userInfo: [NSLocalizedDescriptionKey: "Invalid sizePx: \(sizePx)"])
  }

  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: sizePx,
    pixelsHigh: sizePx,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else {
    throw NSError(domain: "icon_gen", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap rep"])
  }

  // Keep point size equal to pixel size to avoid implicit scaling surprises.
  rep.size = NSSize(width: CGFloat(sizePx), height: CGFloat(sizePx))

  guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    throw NSError(domain: "icon_gen", code: 13, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context"])
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = ctx
  defer { NSGraphicsContext.restoreGraphicsState() }

  // High quality when downscaling to small sizes.
  ctx.imageInterpolation = .high

  let rect = CGRect(x: 0, y: 0, width: CGFloat(sizePx), height: CGFloat(sizePx))
  NSColor.clear.setFill()
  rect.fill()
  draw(rect)

  guard let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "icon_gen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
  }
  return png
}

func writePNG(data: Data, to url: URL) throws {
  try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try data.write(to: url, options: .atomic)
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

func pngData(sizePx: Int, draw: (CGRect) -> Void) throws -> Data {
  try renderPNG(sizePx: sizePx, draw: draw)
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
  try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try out.write(to: url, options: .atomic)
}

func drawMasterIcon(in rect: CGRect) {
  let size = rect.width

  // Background gradient (charcoal -> slate). Stoic, low-saturation.
  let bg1 = hex(0x0B0F16) // near-black
  let bg2 = hex(0x1C2533) // deep slate
  let gradient = NSGradient(colors: [bg1, bg2])!
  gradient.draw(in: rect, angle: 22)

  // Subtle vignette for depth (kept very restrained).
  NSGraphicsContext.current?.saveGraphicsState()
  let vignette = NSBezierPath(ovalIn: CGRect(
    x: rect.minX - size * 0.10,
    y: rect.minY - size * 0.10,
    width: size * 1.20,
    height: size * 1.20
  ))
  hex(0x000000).withAlphaComponent(0.28).setFill()
  vignette.fill()
  NSGraphicsContext.current?.restoreGraphicsState()

  // Foreground mark (soft white with minimal shadow).
  let markRect = rect.insetBy(dx: size * 0.13, dy: size * 0.13)
  let wPath = makeWMarkPath(in: markRect)
  wPath.lineWidth = size * 0.082

  NSGraphicsContext.current?.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowBlurRadius = size * 0.020
  shadow.shadowOffset = NSSize(width: 0, height: -size * 0.010)
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
  shadow.set()

  NSColor.white.withAlphaComponent(0.92).setStroke()
  wPath.stroke()
  NSGraphicsContext.current?.restoreGraphicsState()

  // Thin inner border to make the icon feel "finished" on flat backgrounds.
  let borderRect = rect.insetBy(dx: size * 0.06, dy: size * 0.06)
  let border = NSBezierPath(roundedRect: borderRect, xRadius: size * 0.22, yRadius: size * 0.22)
  border.lineWidth = max(1.0, size * 0.006)
  NSColor.white.withAlphaComponent(0.08).setStroke()
  border.stroke()
}

func drawAndroidAdaptiveBackground(in rect: CGRect) {
  let size = rect.width
  let bg1 = hex(0x0B0F16)
  let bg2 = hex(0x1C2533)
  let gradient = NSGradient(colors: [bg1, bg2])!
  gradient.draw(in: rect, angle: 22)

  let vignette = NSBezierPath(ovalIn: CGRect(
    x: -size * 0.10,
    y: -size * 0.10,
    width: size * 1.20,
    height: size * 1.20
  ))
  hex(0x000000).withAlphaComponent(0.28).setFill()
  vignette.fill()

}

func drawAndroidAdaptiveForeground(in rect: CGRect) {
  let size = rect.width

  // Keep foreground in safe zone.
  let safe = CGRect(x: size * 0.16, y: size * 0.16, width: size * 0.68, height: size * 0.68)
  let wPath = makeWMarkPath(in: safe)
  wPath.lineWidth = size * 0.088

  let shadow = NSShadow()
  shadow.shadowBlurRadius = size * 0.020
  shadow.shadowOffset = NSSize(width: 0, height: -size * 0.010)
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)

  NSGraphicsContext.current?.saveGraphicsState()
  shadow.set()
  NSColor.white.withAlphaComponent(0.94).setStroke()
  wPath.stroke()
  NSGraphicsContext.current?.restoreGraphicsState()
}

let args = CommandLine.arguments
guard args.count >= 2 else {
  fputs("Usage: swift generate_icons.swift <outputDir> [repoRoot]\\n", stderr)
  exit(2)
}

let outputDir = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

try writePNG(
  data: pngData(sizePx: 1024, draw: drawMasterIcon(in:)),
  to: outputDir.appendingPathComponent("app_icon_master_1024.png")
)

try writePNG(
  data: pngData(sizePx: 432, draw: drawAndroidAdaptiveBackground(in:)),
  to: outputDir.appendingPathComponent("android_adaptive_background_432.png")
)

try writePNG(
  data: pngData(sizePx: 432, draw: drawAndroidAdaptiveForeground(in:)),
  to: outputDir.appendingPathComponent("android_adaptive_foreground_432.png")
)

let winPng256 = try pngData(sizePx: 256, draw: drawMasterIcon(in:))
try writeIco(withPngData: winPng256, size: 256, to: outputDir.appendingPathComponent("app_icon_256.ico"))

func parseScale(_ s: String) -> CGFloat? {
  let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  if trimmed.hasSuffix("x") {
    let num = trimmed.dropLast()
    return CGFloat(Double(num) ?? 0)
  }
  return CGFloat(Double(trimmed) ?? 0)
}

func parseBaseSize(_ s: String) -> CGFloat? {
  // e.g. "83.5x83.5" -> 83.5 (assumes square)
  let parts = s.split(separator: "x")
  guard let first = parts.first else { return nil }
  return CGFloat(Double(first) ?? 0)
}

func writeAppIconSet(from contentsJson: URL, baseDir: URL) throws {
  let data = try Data(contentsOf: contentsJson)
  guard
    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    let images = obj["images"] as? [[String: Any]]
  else {
    throw NSError(domain: "icon_gen", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid Contents.json: \(contentsJson.path)"])
  }

  var fileToPixels: [String: Int] = [:]
  for img in images {
    guard let filename = img["filename"] as? String else { continue }
    guard let sizeStr = img["size"] as? String else { continue }
    guard let scaleStr = img["scale"] as? String else { continue }
    guard let base = parseBaseSize(sizeStr) else { continue }
    guard let scale = parseScale(scaleStr), scale > 0 else { continue }
    let px = Int(round(base * scale))
    fileToPixels[filename] = max(fileToPixels[filename] ?? 0, px)
  }

  for (filename, px) in fileToPixels {
    try writePNG(
      data: pngData(sizePx: px, draw: drawMasterIcon(in:)),
      to: baseDir.appendingPathComponent(filename)
    )
  }
}

func writeAndroidIcons(repoRoot: URL) throws {
  let res = repoRoot
    .appendingPathComponent("android")
    .appendingPathComponent("app")
    .appendingPathComponent("src")
    .appendingPathComponent("main")
    .appendingPathComponent("res")

  // Legacy launcher icons
  let launcherSizes: [(String, Int)] = [
    ("mipmap-mdpi", 48),
    ("mipmap-hdpi", 72),
    ("mipmap-xhdpi", 96),
    ("mipmap-xxhdpi", 144),
    ("mipmap-xxxhdpi", 192),
  ]
  for (dir, px) in launcherSizes {
    let out = res.appendingPathComponent(dir).appendingPathComponent("ic_launcher.png")
    try writePNG(data: pngData(sizePx: px, draw: drawMasterIcon(in:)), to: out)
  }

  // Adaptive icon layers (pngs are referenced from mipmap-anydpi-v26/ic_launcher.xml)
  try writePNG(
    data: pngData(sizePx: 432, draw: drawAndroidAdaptiveBackground(in:)),
    to: res.appendingPathComponent("drawable").appendingPathComponent("ic_launcher_background.png")
  )
  try writePNG(
    data: pngData(sizePx: 432, draw: drawAndroidAdaptiveForeground(in:)),
    to: res.appendingPathComponent("drawable").appendingPathComponent("ic_launcher_foreground.png")
  )
}

func drawMaskableWebIcon(in rect: CGRect) {
  // Same background, but ensure the mark stays well within safe zone for maskable icons.
  let size = rect.width

  let bg1 = hex(0x0B0F16)
  let bg2 = hex(0x1C2533)
  let gradient = NSGradient(colors: [bg1, bg2])!
  gradient.draw(in: rect, angle: 22)

  let vignette = NSBezierPath(ovalIn: CGRect(
    x: -size * 0.10,
    y: -size * 0.10,
    width: size * 1.20,
    height: size * 1.20
  ))
  hex(0x000000).withAlphaComponent(0.28).setFill()
  vignette.fill()

  let markRect = rect.insetBy(dx: size * 0.22, dy: size * 0.22)
  let wPath = makeWMarkPath(in: markRect)
  wPath.lineWidth = size * 0.070

  let shadow = NSShadow()
  shadow.shadowBlurRadius = size * 0.018
  shadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)

  NSGraphicsContext.current?.saveGraphicsState()
  shadow.set()
  NSColor.white.withAlphaComponent(0.92).setStroke()
  wPath.stroke()
  NSGraphicsContext.current?.restoreGraphicsState()
}

func writeWebIcons(repoRoot: URL) throws {
  let webIcons = repoRoot.appendingPathComponent("web").appendingPathComponent("icons")
  try writePNG(data: pngData(sizePx: 192, draw: drawMasterIcon(in:)), to: webIcons.appendingPathComponent("Icon-192.png"))
  try writePNG(data: pngData(sizePx: 512, draw: drawMasterIcon(in:)), to: webIcons.appendingPathComponent("Icon-512.png"))
  try writePNG(data: pngData(sizePx: 192, draw: drawMaskableWebIcon(in:)), to: webIcons.appendingPathComponent("Icon-maskable-192.png"))
  try writePNG(data: pngData(sizePx: 512, draw: drawMaskableWebIcon(in:)), to: webIcons.appendingPathComponent("Icon-maskable-512.png"))
}

func writeWindowsIcon(repoRoot: URL) throws {
  let out = repoRoot
    .appendingPathComponent("windows")
    .appendingPathComponent("runner")
    .appendingPathComponent("resources")
    .appendingPathComponent("app_icon.ico")
  let png256 = try pngData(sizePx: 256, draw: drawMasterIcon(in:))
  try writeIco(withPngData: png256, size: 256, to: out)
}

if args.count >= 3 {
  let repoRoot = URL(fileURLWithPath: args[2], isDirectory: true)

  // iOS + macOS asset catalogs.
  try writeAppIconSet(
    from: repoRoot
      .appendingPathComponent("ios")
      .appendingPathComponent("Runner")
      .appendingPathComponent("Assets.xcassets")
      .appendingPathComponent("AppIcon.appiconset")
      .appendingPathComponent("Contents.json"),
    baseDir: repoRoot
      .appendingPathComponent("ios")
      .appendingPathComponent("Runner")
      .appendingPathComponent("Assets.xcassets")
      .appendingPathComponent("AppIcon.appiconset")
  )

  try writeAppIconSet(
    from: repoRoot
      .appendingPathComponent("macos")
      .appendingPathComponent("Runner")
      .appendingPathComponent("Assets.xcassets")
      .appendingPathComponent("AppIcon.appiconset")
      .appendingPathComponent("Contents.json"),
    baseDir: repoRoot
      .appendingPathComponent("macos")
      .appendingPathComponent("Runner")
      .appendingPathComponent("Assets.xcassets")
      .appendingPathComponent("AppIcon.appiconset")
  )

  try writeAndroidIcons(repoRoot: repoRoot)
  try writeWebIcons(repoRoot: repoRoot)
  try writeWindowsIcon(repoRoot: repoRoot)
}

print("Wrote icons to \(outputDir.path)\(args.count >= 3 ? " and applied to repo" : "")")

