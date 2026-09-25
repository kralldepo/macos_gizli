// Uygulama ikonunu (1024×1024 PNG) çizer: swift Scripts/ikon.swift <çıktı.png>
// Göz, README görselleriyle aynı 24×24 geometriden elle çizilir (SF Symbols ikonda kullanılamaz).
import AppKit

let cikti = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let boyut = 1024
let renkUzayi = CGColorSpace(name: CGColorSpace.sRGB)!

func tuval() -> CGContext {
    CGContext(data: nil, width: boyut, height: boyut, bitsPerComponent: 8, bytesPerRow: 0,
              space: renkUzayi, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

// Plaka: Apple'ın macOS ikon ızgarası — 1024 tuvalde 824×824 yuvarlatılmış kare, yukarıdan aşağı koyulaşır.
let ikon = tuval()
ikon.saveGState()
ikon.addPath(CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                    cornerWidth: 185, cornerHeight: 185, transform: nil))
ikon.clip()
let gradyan = CGGradient(colorsSpace: renkUzayi, colors: [
    CGColor(srgbRed: 0.20, green: 0.24, blue: 0.32, alpha: 1),
    CGColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 1),
] as CFArray, locations: [0, 1])!
ikon.drawLinearGradient(gradyan, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ikon.restoreGState()

// Üstü çizili göz ayrı katmanda çizilir; böylece çizginin yanındaki boşluk plakayı değil yalnızca gözü keser.
let goz = tuval()
let olcek: CGFloat = 25
goz.translateBy(x: (CGFloat(boyut) - 24 * olcek) / 2, y: (CGFloat(boyut) + 24 * olcek) / 2)
goz.scaleBy(x: olcek, y: -olcek)  // SVG gibi y aşağı doğru artsın
goz.setLineCap(.round)
goz.setLineJoin(.round)
goz.setStrokeColor(CGColor(gray: 1, alpha: 1))

let govde = CGMutablePath()
govde.move(to: CGPoint(x: 2, y: 12))
govde.addCurve(to: CGPoint(x: 12, y: 5), control1: CGPoint(x: 5, y: 6.5), control2: CGPoint(x: 8.5, y: 5))
govde.addCurve(to: CGPoint(x: 22, y: 12), control1: CGPoint(x: 15.5, y: 5), control2: CGPoint(x: 19, y: 6.5))
govde.addCurve(to: CGPoint(x: 12, y: 19), control1: CGPoint(x: 19, y: 17.5), control2: CGPoint(x: 15.5, y: 19))
govde.addCurve(to: CGPoint(x: 2, y: 12), control1: CGPoint(x: 8.5, y: 19), control2: CGPoint(x: 5, y: 17.5))
govde.closeSubpath()
govde.addEllipse(in: CGRect(x: 8.8, y: 8.8, width: 6.4, height: 6.4))
goz.setLineWidth(2)
goz.addPath(govde)
goz.strokePath()

let cizgi = CGMutablePath()
cizgi.move(to: CGPoint(x: 4, y: 3))
cizgi.addLine(to: CGPoint(x: 20, y: 21))
goz.setBlendMode(.clear)
goz.setLineWidth(5)
goz.addPath(cizgi)
goz.strokePath()
goz.setBlendMode(.normal)
goz.setLineWidth(2)
goz.addPath(cizgi)
goz.strokePath()

ikon.draw(goz.makeImage()!, in: CGRect(x: 0, y: 0, width: boyut, height: boyut))
try! NSBitmapImageRep(cgImage: ikon.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: cikti))
