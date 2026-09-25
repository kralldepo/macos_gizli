// Gizli Dosyalar — menü çubuğundan Finder'da gizli dosyaları göster / gizle.
import AppKit
import ServiceManagement

/// Finder'ın `AppleShowAllFiles` ayarını okur/yazar ve Finder'ı yeniden başlatır.
enum FinderAyari {
    private static let alan = "com.apple.finder" as CFString
    private static let anahtar = "AppleShowAllFiles" as CFString
    private static let finderKimligi = "com.apple.finder"

    /// Gizli dosyalar şu an görünüyor mu?
    static var gizlilerGorunuyor: Bool {
        CFPreferencesAppSynchronize(alan)
        guard let deger = CFPreferencesCopyAppValue(anahtar, alan) else { return false }
        // `defaults write ... -bool true` Bool yazar; eski rehberlerdeki
        // `defaults write ... AppleShowAllFiles YES` ise metin ("YES") yazar.
        if let metin = deger as? String {
            return ["yes", "true", "1"].contains(metin.lowercased())
        }
        return (deger as? NSNumber)?.boolValue ?? false
    }

    static func ayarla(goster: Bool) {
        CFPreferencesSetAppValue(anahtar, goster as CFBoolean, alan)
        CFPreferencesAppSynchronize(alan)
        finderiYenidenBaslat()
    }

    /// Finder ayarı yalnızca açılışta okur; `killall Finder` sonrası Finder kendiliğinden
    /// yeniden açılır. Açılmazsa birkaç saniye sonra biz açarız.
    private static func finderiYenidenBaslat() {
        let islem = Process()
        islem.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        islem.arguments = ["Finder"]
        try? islem.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard NSRunningApplication.runningApplications(withBundleIdentifier: finderKimligi).isEmpty,
                  let adres = NSWorkspace.shared.urlForApplication(withBundleIdentifier: finderKimligi)
            else { return }
            NSWorkspace.shared.openApplication(at: adres, configuration: .init())
        }
    }
}

@MainActor
final class UygulamaDelegesi: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let durumOgesi = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let gosterOgesi = NSMenuItem(title: "Gizli Dosyaları Göster",
                                         action: #selector(gosterDegistir), keyEquivalent: "")
    private let giristeOgesi = NSMenuItem(title: "Girişte Başlat",
                                          action: #selector(giristeDegistir), keyEquivalent: "")

    func applicationDidFinishLaunching(_ bildirim: Notification) {
        // Başka bir kopya çalışıyorsa (eski derleme, /Applications kopyası) onu kapat; son açılan kalır.
        let benimPid = ProcessInfo.processInfo.processIdentifier
        for diger in NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            where diger.processIdentifier != benimPid {
            diger.terminate()
        }

        gosterOgesi.target = self
        giristeOgesi.target = self

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(gosterOgesi)
        menu.addItem(.separator())
        menu.addItem(giristeOgesi)
        menu.addItem(NSMenuItem(title: "Çıkış", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        durumOgesi.menu = menu

        guncelle()
    }

    // Menü her açıldığında kayıtlı ayarı yeniden oku (ör. Terminal'den değişmiş olabilir).
    // Not: Finder'daki ⌘⇧. ayarı kaydetmez, yalnızca o oturumu etkiler.
    func menuNeedsUpdate(_ menu: NSMenu) { guncelle() }

    private func guncelle() {
        let gorunuyor = FinderAyari.gizlilerGorunuyor
        gosterOgesi.state = gorunuyor ? .on : .off
        durumOgesi.button?.image = NSImage(
            systemSymbolName: gorunuyor ? "eye" : "eye.slash",
            accessibilityDescription: gorunuyor ? "Gizli dosyalar görünüyor" : "Gizli dosyalar gizli")
        durumOgesi.button?.toolTip = gorunuyor ? "Gizli dosyalar görünüyor" : "Gizli dosyalar gizli"
        giristeOgesi.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func gosterDegistir() {
        FinderAyari.ayarla(goster: !FinderAyari.gizlilerGorunuyor)
        guncelle()
    }

    @objc private func giristeDegistir() {
        let servis = SMAppService.mainApp
        // Zaten kayıtlı ama kullanıcı onayı bekliyor: hata göstermeden Ayarlar'ı aç.
        if servis.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if servis.status == .enabled {
                try servis.unregister()
            } else {
                try servis.register()
            }
        } catch {
            let uyari = NSAlert()
            uyari.messageText = "Girişte başlatma ayarlanamadı"
            uyari.informativeText = error.localizedDescription
            NSApp.activate()
            uyari.runModal()
        }
        if servis.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        guncelle()
    }
}

@main
enum GizliDosyalar {
    @MainActor static func main() {
        let uygulama = NSApplication.shared
        let delege = UygulamaDelegesi()  // NSApp.delegate zayıf referans; run() dönene dek yaşar
        uygulama.delegate = delege
        uygulama.setActivationPolicy(.accessory)
        uygulama.run()
    }
}
