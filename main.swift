import Cocoa
import WebKit
import ServiceManagement

// Panel melayang tanpa bingkai yang tidak pernah mencuri fokus.
final class Panel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// Lapisan transparan di atas web view: seret = pindahkan, klik 2x = beri makan, klik kanan = menu.
final class DragOverlay: NSView {
    var onFeed: (() -> Void)?
    var menuProvider: (() -> NSMenu)?
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onFeed?(); return }
        window?.performDrag(with: event)
    }
    override func rightMouseDown(with event: NSEvent) {
        if let m = menuProvider?() { NSMenu.popUpContextMenu(m, with: event, for: self) }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    let baseW = 128.0, baseH = 80.0
    var panel: Panel!
    var web: WKWebView!
    var statusItem: NSStatusItem!
    let defaults = UserDefaults.standard
    var snapshotPath: String? = nil
    var snapshotJS: String? = nil

    var onTop: Bool {
        get { defaults.object(forKey: "onTop") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "onTop") }
    }
    var cycle: String {
        get { defaults.string(forKey: "cycle") ?? "real" }
        set { defaults.set(newValue, forKey: "cycle") }
    }
    var scale: Int {
        get { let s = defaults.integer(forKey: "scale"); return s == 0 ? 3 : s }
        set { defaults.set(newValue, forKey: "scale") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: baseW * Double(scale), height: baseH * Double(scale))
        var origin = NSPoint(x: 100, y: 100)
        if let vf = NSScreen.main?.visibleFrame {
            origin = NSPoint(x: vf.maxX - size.width - 24, y: vf.minY + 24)
        }
        panel = Panel(contentRect: NSRect(origin: origin, size: size),
                      styleMask: [.borderless, .nonactivatingPanel],
                      backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        if snapshotPath == nil { panel.setFrameAutosaveName("PixelAquarium") }

        let config = WKWebViewConfiguration()
        web = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: config)
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        web.underPageBackgroundColor = .clear
        panel.contentView?.addSubview(web)

        let overlay = DragOverlay(frame: NSRect(origin: .zero, size: size))
        overlay.autoresizingMask = [.width, .height]
        overlay.onFeed = { [weak self] in self?.feed() }
        overlay.menuProvider = { [weak self] in self?.buildMenu() ?? NSMenu() }
        panel.contentView?.addSubview(overlay)

        if let url = Bundle.main.url(forResource: "aquarium", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐠"
        refreshMenu()

        applySize(keepOrigin: true)
        applyLevel()
        panel.orderFrontRegardless()

        if let path = snapshotPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.web.takeSnapshot(with: nil) { image, _ in
                    if let image = image, let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: path))
                    }
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("window.setCycle('\(cycle)')", completionHandler: nil)
        if let js = snapshotJS { webView.evaluateJavaScript(js, completionHandler: nil) }
    }

    // MARK: Window state
    func applySize(keepOrigin: Bool) {
        let size = NSSize(width: baseW * Double(scale), height: baseH * Double(scale))
        var f = panel.frame
        f.size = size
        panel.setFrame(f, display: true)
    }

    func applyLevel() {
        if onTop {
            panel.level = .floating
        } else {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }

    // MARK: Menu
    func buildMenu() -> NSMenu {
        let m = NSMenu()
        func add(_ title: String, _ action: Selector, state: Bool = false, tag: Int = 0) {
            let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
            it.target = self; it.state = state ? .on : .off; it.tag = tag
            m.addItem(it)
        }
        add("Selalu di atas jendela", #selector(setTop), state: onTop)
        add("Di belakang jendela", #selector(setBack), state: !onTop)
        m.addItem(.separator())

        let sizeMenu = NSMenu()
        for (label, s) in [("Kecil (2×)", 2), ("Sedang (3×)", 3), ("Besar (4×)", 4)] {
            let it = NSMenuItem(title: label, action: #selector(setScale(_:)), keyEquivalent: "")
            it.target = self; it.tag = s; it.state = (scale == s) ? .on : .off
            sizeMenu.addItem(it)
        }
        let sizeItem = NSMenuItem(title: "Ukuran", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        m.addItem(sizeItem)

        let cycleMenu = NSMenu()
        for (label, key) in [("Waktu nyata (sesuai jam Mac)", "real"), ("Dipercepat (1 hari = 4 menit)", "fast"), ("Siang terus", "day"), ("Malam terus", "night")] {
            let it = NSMenuItem(title: label, action: #selector(setCycle(_:)), keyEquivalent: "")
            it.target = self; it.representedObject = key; it.state = (cycle == key) ? .on : .off
            cycleMenu.addItem(it)
        }
        let cycleItem = NSMenuItem(title: "Siklus siang-malam", action: nil, keyEquivalent: "")
        cycleItem.submenu = cycleMenu
        m.addItem(cycleItem)

        add("Panggil hiu atau penyu", #selector(summonVisitor))
        add("Beri makan ikan (klik 2×)", #selector(feedAction))
        add(panel.isVisible ? "Sembunyikan akuarium" : "Tampilkan akuarium", #selector(toggleVisible))
        add("Buka saat login", #selector(toggleLogin), state: SMAppService.mainApp.status == .enabled)
        m.addItem(.separator())
        add("Keluar", #selector(quit))
        return m
    }

    func refreshMenu() { statusItem.menu = buildMenu() }

    @objc func setTop() { onTop = true; applyLevel(); refreshMenu() }
    @objc func setBack() { onTop = false; applyLevel(); refreshMenu() }
    @objc func setScale(_ sender: NSMenuItem) { scale = sender.tag; applySize(keepOrigin: true); refreshMenu() }
    @objc func setCycle(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        cycle = key
        web.evaluateJavaScript("window.setCycle('\(key)')", completionHandler: nil)
        refreshMenu()
    }
    @objc func summonVisitor() { web.evaluateJavaScript("window.spawn && window.spawn()", completionHandler: nil) }
    @objc func feedAction() { feed() }
    func feed() { web.evaluateJavaScript("window.feed && window.feed()", completionHandler: nil) }
    @objc func toggleVisible() {
        if panel.isVisible {
            panel.orderOut(nil)
            web.evaluateJavaScript("window.setPaused && window.setPaused(true)", completionHandler: nil)
        } else {
            panel.orderFrontRegardless()
            web.evaluateJavaScript("window.setPaused && window.setPaused(false)", completionHandler: nil)
        }
        refreshMenu()
    }
    @objc func toggleLogin() {
        let s = SMAppService.mainApp
        do {
            if s.status == .enabled { try s.unregister() } else { try s.register() }
        } catch { NSSound.beep() }
        refreshMenu()
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
    delegate.snapshotPath = CommandLine.arguments[i + 1]
}
if let i = CommandLine.arguments.firstIndex(of: "--js"), i + 1 < CommandLine.arguments.count {
    delegate.snapshotJS = CommandLine.arguments[i + 1]
}
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
