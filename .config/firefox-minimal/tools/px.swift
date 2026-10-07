// Sample exact pixels from a PNG. Pillow is not installed and eyeballing a
// downscaled crop is unreliable for 13px glyphs, so read the bitmap directly.
//
//   swift px.swift <image> <x1> <y1> <x2> <y2>
//
// Reports the brightest pixel and the spread in the region, which is what
// distinguishes "icon drawn but dim" from "nothing drawn at all".
import AppKit

let a = CommandLine.arguments
guard a.count == 6, let img = NSImage(contentsOfFile: a[1]),
      let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    print("usage: swift px.swift <image> <x1> <y1> <x2> <y2>"); exit(1)
}
let (x1, y1, x2, y2) = (Int(a[2])!, Int(a[3])!, Int(a[4])!, Int(a[5])!)

var minL = 1.0, maxL = 0.0
var brightest = (x: 0, y: 0)
var sum = 0.0, n = 0

for y in y1..<min(y2, rep.pixelsHigh) {
    for x in x1..<min(x2, rep.pixelsWide) {
        guard let c = rep.colorAt(x: x, y: y) else { continue }
        let l = 0.2126 * c.redComponent + 0.7152 * c.greenComponent
              + 0.0722 * c.blueComponent
        if l > maxL { maxL = l; brightest = (x, y) }
        minL = Swift.min(minL, l)
        sum += l; n += 1
    }
}
let f = { (v: Double) in String(format: "%.4f", v) }
print("region \(x1),\(y1) -> \(x2),\(y2)  samples=\(n)")
print("  luminance  min=\(f(minL))  mean=\(f(sum / Double(n)))  max=\(f(maxL))")
print("  brightest pixel at \(brightest.x),\(brightest.y)")
if let c = rep.colorAt(x: brightest.x, y: brightest.y) {
    print(String(format: "  brightest rgb = #%02X%02X%02X",
                 Int(c.redComponent * 255), Int(c.greenComponent * 255),
                 Int(c.blueComponent * 255)))
}
print(maxL - minL < 0.02 ? "  VERDICT: flat — nothing is drawn here"
                         : "  VERDICT: content present")
