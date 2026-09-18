import AppKit
import SceneKit

// 모니터 클리너 — 화면 위를 뛰어다니다 유리를 핥는 로우폴리 강아지.
// 모니터마다 투명한 창을 하나씩 깔고, 강아지 위에 마우스가 있을 때만 클릭을 받는다.

final class PetView: SCNView {
    weak var stage: Stage?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) {
        guard let st = stage else { return }
        let p = convert(e.locationInWindow, from: nil)
        st.dog(at: p, in: self)?.pet()
    }
}

final class Overlay {
    let screen: NSScreen
    let window: NSWindow
    let view: PetView
    let stage: Stage

    init(_ screen: NSScreen) {
        self.screen = screen
        let f = screen.frame
        stage = Stage(widthPt: f.width, heightPt: f.height, floorPt: screen.visibleFrame.minY - f.minY + 2)
        window = NSWindow(contentRect: f, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(f, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        view = PetView(frame: NSRect(origin: .zero, size: f.size), options: nil)
        view.stage = stage
        view.scene = stage.scene
        view.pointOfView = stage.cam
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        window.contentView = view
        window.orderFrontRegardless()
    }
    func close() { view.isPlaying = false; window.orderOut(nil); window.close() }
}

// 핥는 소리 — 잡음을 걸러 짧게 만든다
func slurpSound() -> Data {
    let sr = 22050, n = Int(0.24 * Double(sr))
    var pcm = [Int16](repeating: 0, count: n)
    var lp = 0.0, lp2 = 0.0
    for i in 0..<n {
        let t = Double(i) / Double(n)
        let env = pow(sin(.pi * t), 1.5) * (0.75 + 0.25 * sin(t * 55))
        let k = 0.04 + 0.3 * t
        lp += (Double.random(in: -1...1) - lp) * k
        lp2 += (lp - lp2) * k
        let wet = sin(2 * .pi * (220 + 700 * t) * Double(i) / Double(sr)) * 0.25
        pcm[i] = Int16(max(-1, min(1, (lp2 * 3 + wet * lp2 * 4) * env)) * 20000)
    }
    var d = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
    d.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + n * 2)); d.append("WAVEfmt ".data(using: .ascii)!)
    u32(16); u16(1); u16(1); u32(UInt32(sr)); u32(UInt32(sr * 2)); u16(2); u16(16)
    d.append("data".data(using: .ascii)!); u32(UInt32(n * 2))
    pcm.withUnsafeBytes { d.append(contentsOf: $0) }
    return d
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var overlays: [Overlay] = []
    var status: NSStatusItem!
    var timer: Timer?
    var last = CACurrentMediaTime()
    var lastMouse = NSEvent.mouseLocation
    var frame = 0
    let defaults = UserDefaults.standard
    var breedID: String { get { defaults.string(forKey: "breed") ?? "corgi" } set { defaults.set(newValue, forKey: "breed") } }
    var soundOn: Bool { get { defaults.bool(forKey: "sound") } set { defaults.set(newValue, forKey: "sound") } }
    var sounds: [NSSound] = []
    var soundIdx = 0
    var breed: Breed { BREEDS.first { $0.id == breedID } ?? BREEDS[0] }

    func applicationDidFinishLaunching(_ n: Notification) {
        let data = slurpSound()
        sounds = (0..<4).compactMap { _ in NSSound(data: data) }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "🐶"
        let menu = NSMenu()
        menu.delegate = self
        status.menu = menu
        addDog()
        timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        // 확인용: MC_SNAP=폴더 로 띄우면 몇 초마다 실제 창의 장면을 그림으로 남긴다
        if let dir = ProcessInfo.processInfo.environment["MC_SNAP"] {
            var k = 0
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                guard let o = self?.overlays.first else { return }
                k += 1
                let img = o.view.snapshot()
                if let t = img.tiffRepresentation, let r = NSBitmapImageRep(data: t), let png = r.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir + "/snap\(k).png"))
                }
                if k == 2 { self?.lickNow() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.rebuild() }
    }

    // 메뉴는 열 때마다 새로 — 체크 표시를 맞추려고
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func item(_ t: String, _ a: Selector, _ key: String = "", tag: Int = 0) -> NSMenuItem {
            let i = NSMenuItem(title: t, action: a, keyEquivalent: key)
            i.target = self; i.tag = tag
            return i
        }
        menu.addItem(item("지금 핥아!", #selector(lickNow), "l"))
        menu.addItem(.separator())
        let bm = NSMenu()
        for (i, b) in BREEDS.enumerated() {
            let it = item(b.name, #selector(pickBreed(_:)), tag: i)
            it.state = b.id == breedID ? .on : .off
            bm.addItem(it)
        }
        let bi = NSMenuItem(title: "견종: " + breed.name, action: nil, keyEquivalent: "")
        bi.submenu = bm
        menu.addItem(bi)
        let n = overlays.reduce(0) { $0 + $1.stage.dogs.count }
        menu.addItem(item("한 마리 더 (마우스 있는 화면)", #selector(addDogMenu), "n"))
        let rm = item("한 마리 보내기", #selector(removeDog))
        rm.isEnabled = n > 1
        menu.addItem(rm)
        menu.addItem(.separator())
        menu.addItem(item("침 다 닦기", #selector(wipe), "w"))
        let s = item("소리", #selector(toggleSound))
        s.state = soundOn ? .on : .off
        menu.addItem(s)
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "강아지를 누르면 좋아함 · 침은 마우스로 문질러 닦기", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(item("종료", #selector(quit), "q"))
    }

    func mouseScreen() -> NSScreen {
        let m = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(m, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    func overlay(for s: NSScreen) -> Overlay {
        if let o = overlays.first(where: { $0.screen == s }) { return o }
        let o = Overlay(s)
        o.stage.onLick = { [weak self] in self?.lickSound() }
        overlays.append(o)
        return o
    }
    func addDog() { overlay(for: mouseScreen()).stage.addDog(breed) }

    @objc func addDogMenu() { addDog() }
    @objc func removeDog() {
        guard let o = overlays.last(where: { !$0.stage.dogs.isEmpty }), let d = o.stage.dogs.last else { return }
        o.stage.remove(d)
        if o.stage.dogs.isEmpty { o.close(); overlays.removeAll { $0 === o } }
    }
    @objc func lickNow() { for o in overlays { for d in o.stage.dogs { d.goLick() } } }
    @objc func pickBreed(_ sender: NSMenuItem) {
        breedID = BREEDS[sender.tag].id
        for o in overlays { o.stage.dogs.map { $0 }.forEach { _ = o.stage.replace($0, with: breed) } }
    }
    @objc func wipe() { for o in overlays { o.stage.clearSmears() } }
    @objc func toggleSound() { soundOn.toggle(); if soundOn { lickSound() } }
    @objc func quit() { NSApp.terminate(nil) }

    func lickSound() {
        guard soundOn, !sounds.isEmpty else { return }
        let s = sounds[soundIdx % sounds.count]
        soundIdx += 1
        s.stop(); s.volume = 0.5; s.play()
    }

    func rebuild() {
        let count = max(1, overlays.reduce(0) { $0 + $1.stage.dogs.count })
        for o in overlays { o.close() }
        overlays = []
        for _ in 0..<count { addDog() }
    }

    func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(0.05, now - last))
        last = now
        frame += 1
        let m = NSEvent.mouseLocation
        let moved = hypot(m.x - lastMouse.x, m.y - lastMouse.y) / U
        lastMouse = m
        for o in overlays {
            let f = o.screen.frame
            let inside = NSMouseInRect(m, f, false)
            let local = CGPoint(x: m.x - f.minX, y: m.y - f.minY)
            o.stage.update(dt, mouse: inside ? o.stage.glass(local) : nil, rub: inside ? moved : 0)
            // 강아지 위에 있을 때만 클릭을 받는다 — 나머지는 아래 창으로 그냥 통과
            if frame % 3 == 0 {
                let over = inside && o.stage.dog(at: local, in: o.view) != nil
                if o.window.ignoresMouseEvents == over { o.window.ignoresMouseEvents = !over }
            }
        }
    }
}

// 확인용: 화면 없이 장면을 그려 PNG 로 저장한다
//   MonitorCleaner --shot out.png lineup|walk|lick [견종]
func shot(_ args: [String]) {
    let out = args[0], mode = args.count > 1 ? args[1] : "lineup"
    let b = BREEDS.first { $0.id == (args.count > 2 ? args[2] : "corgi") } ?? BREEDS[0]
    let st = Stage(widthPt: 1400, heightPt: 800, floorPt: 60)
    st.scene.background.contents = NSColor(srgbRed: 0.86, green: 0.89, blue: 0.94, alpha: 1)
    let dt: CGFloat = 1.0 / 60
    switch mode {
    case "lineup":
        for (i, br) in BREEDS.enumerated() {
            let d = st.addDog(br)
            d.x = -5.6 + CGFloat(i) * 1.6; d.z = i % 2 == 0 ? -1.2 : -2.2
            d.yaw = 0.7; d.state = .idle; d.timer = 99; d.speed = 0
            d.update(dt, st, mouse: nil)
        }
    case "walk":
        let d = st.addDog(b)
        d.x = 0; d.z = -1.4; d.tx = 5; d.tz = -1.4; d.yaw = .pi / 2; d.state = .walk
        for _ in 0..<50 { st.update(dt, mouse: nil, rub: 0) }
    default:
        let d = st.addDog(b)
        d.x = -1; d.z = -1.4; d.yaw = 0.3; d.state = .idle; d.timer = 0; d.wantLick = true
        let sec = args.count > 3 ? Double(args[3]) ?? 7 : 7
        for _ in 0..<Int(60 * sec) { st.update(dt, mouse: nil, rub: 0) }
    }
    let r = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    r.scene = st.scene
    r.pointOfView = st.cam
    let img = r.snapshot(atTime: 0, with: CGSize(width: 1400, height: 800), antialiasingMode: .multisampling4X)
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
    print("saved", out)
}

let args = Array(CommandLine.arguments.dropFirst())
if let i = args.firstIndex(of: "--shot") {
    shot(Array(args[(i + 1)...]))
    exit(0)
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
