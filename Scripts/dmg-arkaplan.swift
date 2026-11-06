// DMG penceresinin arka planını çizer: swift Scripts/dmg-arkaplan.swift <çıktı.png> [ölçek]
// ikon.swift ile aynı CoreGraphics yaklaşımı; metin dışında SF Symbols kullanılmaz.
// Mantıksal tuval 540×400 noktadır; ölçek 2 verildiğinde Retina için 1080×800 piksel üretir.
import AppKit

let args = CommandLine.arguments.dropFirst()
let cikti = args.first ?? "arkaplan.png"
let olcek = CGFloat(Double(args.dropFirst().first ?? "2") ?? 2)
let enN: CGFloat = 540, boyN: CGFloat = 400            // nokta cinsinden
let en = Int(enN * olcek), boy = Int(boyN * olcek)      // piksel cinsinden
let renkUzayi = CGColorSpace(name: CGColorSpace.sRGB)!

let ctx = CGContext(data: nil, width: en, height: boy, bitsPerComponent: 8, bytesPerRow: 0,
                    space: renkUzayi, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.scaleBy(x: olcek, y: olcek)   // bundan sonra her şey nokta koordinatlarıyla çizilir

// Arka plan: yumuşak açık gradyan. Finder, simge adlarını koyu renk yazar; açık zemin
// etiketlerin her macOS sürümünde okunaklı kalmasını güvenceye alır.
let gradyan = CGGradient(colorsSpace: renkUzayi, colors: [
    CGColor(srgbRed: 0.96, green: 0.97, blue: 0.98, alpha: 1),
    CGColor(srgbRed: 0.89, green: 0.91, blue: 0.94, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradyan, start: CGPoint(x: 0, y: boyN), end: CGPoint(x: 0, y: 0), options: [])

// Ok: iki simgenin (sol: uygulama x≈150, sağ: Uygulamalar x≈390) arasındaki boşlukta,
// README rozetleriyle aynı marka yeşilinde. CG tabanı altta olduğundan y yukarı artar;
// simgeler Finder'da y=200'de, burada da y=200 (boyN−200) ile hizalanır.
let yesil = CGColor(srgbRed: 0.06, green: 0.62, blue: 0.52, alpha: 1)
let okY: CGFloat = 200
ctx.setStrokeColor(yesil)
ctx.setFillColor(yesil)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setLineWidth(10)
ctx.move(to: CGPoint(x: 232, y: okY))
ctx.addLine(to: CGPoint(x: 300, y: okY))
ctx.strokePath()
ctx.move(to: CGPoint(x: 291, y: okY + 12))   // ok ucu
ctx.addLine(to: CGPoint(x: 309, y: okY))
ctx.addLine(to: CGPoint(x: 291, y: okY - 12))
ctx.closePath()
ctx.fillPath()

// Başlık metni (San Francisco her macOS'ta vardır). NSAttributedString, CGContext'i
// saran bir NSGraphicsContext üzerinden çizer.
let ng = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = ng
let paragraf = NSMutableParagraphStyle()
paragraf.alignment = .center
let oznitelik: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.22, alpha: 1),
    .paragraphStyle: paragraf,
]
NSAttributedString(string: "Kurmak için Uygulamalar klasörüne sürükleyin", attributes: oznitelik)
    .draw(in: CGRect(x: 20, y: boyN - 70, width: enN - 40, height: 24))

try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: cikti))
