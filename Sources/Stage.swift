import AppKit
import SceneKit

// 화면 한 장에 해당하는 무대. 유리(z=0) 위의 1 은 100pt 이고, 강아지는 유리 뒤(z<0)를 걷는다.
let U: CGFloat = 100
let EYE: CGFloat = 0.6        // 카메라 눈높이 — 바닥에서. 낮을수록 멀리 있는 강아지가 덜 떠 보인다
let DIST: CGFloat = 7         // 카메라에서 유리까지 — 짧을수록 유리에 붙을 때 커 보인다

// 그림 — 한 번만 만든다
enum Tex {
    static func make(_ size: Int, _ draw: (CGContext, CGFloat) -> Void) -> CGImage {
        let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(c, CGFloat(size))
        return c.makeImage()!
    }
    static func radial(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ cols: [CGColor], _ locs: [CGFloat]) {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: cols as CFArray, locations: locs)!
        c.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y),
                             endRadius: r, options: [])
    }
    static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static let shadow = make(128) { c, s in
        radial(c, s / 2, s / 2, s / 2, [rgba(0, 0, 0, 0.32), rgba(0, 0, 0, 0.12), rgba(0, 0, 0, 0)], [0, 0.55, 1])
    }
    // 침 — 번들번들한 얼룩 몇 개를 겹치고 반사광과 거품을 얹는다
    static let drool: [CGImage] = (0..<5).map { _ in
        make(256) { c, s in
            for _ in 0..<5 {
                let x = s / 2 + rnd(-s * 0.14, s * 0.14), y = s / 2 + rnd(-s * 0.14, s * 0.14)
                radial(c, x, y, s * rnd(0.22, 0.34),
                       [rgba(0.92, 0.96, 1, 0.34), rgba(0.85, 0.92, 1, 0.2), rgba(0.85, 0.92, 1, 0)], [0, 0.6, 1])
            }
            radial(c, s * 0.4, s * 0.62, s * 0.12, [rgba(1, 1, 1, 0.85), rgba(1, 1, 1, 0)], [0, 1])
            for _ in 0..<Int.random(in: 2...5) {
                let r = rnd(3, 9), x = s / 2 + rnd(-s * 0.25, s * 0.25), y = s / 2 + rnd(-s * 0.25, s * 0.25)
                c.setFillColor(rgba(0.9, 0.95, 1, 0.35)); c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                c.setFillColor(rgba(1, 1, 1, 0.9)); c.fillEllipse(in: CGRect(x: x - r * 0.5, y: y + r * 0.1, width: r * 0.6, height: r * 0.6))
            }
        }
    }
    static let drip = make(64) { c, s in
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [rgba(0.9, 0.95, 1, 0.0), rgba(0.9, 0.95, 1, 0.45)] as CFArray, locations: [0, 1])!
        c.saveGState()
        c.addPath(CGPath(roundedRect: CGRect(x: s * 0.3, y: 0, width: s * 0.4, height: s), cornerWidth: s * 0.2, cornerHeight: s * 0.2, transform: nil))
        c.clip()
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: s), options: [])
        c.restoreGState()
        c.setFillColor(rgba(1, 1, 1, 0.8)); c.fillEllipse(in: CGRect(x: s * 0.36, y: s * 0.02, width: s * 0.14, height: s * 0.14))
    }
    static let fog = make(128) { c, s in
        radial(c, s / 2, s / 2, s / 2, [rgba(1, 1, 1, 0.42), rgba(1, 1, 1, 0.2), rgba(1, 1, 1, 0)], [0, 0.5, 1])
    }
    static let nose = make(128) { c, s in
        radial(c, s / 2, s / 2, s / 2, [rgba(0.75, 0.8, 0.85, 0.35), rgba(0.8, 0.85, 0.9, 0.12), rgba(1, 1, 1, 0)], [0, 0.5, 1])
        for sx in [-1.0, 1.0] as [CGFloat] {
            radial(c, s / 2 + sx * s * 0.12, s * 0.45, s * 0.08, [rgba(0.4, 0.42, 0.46, 0.4), rgba(0.4, 0.42, 0.46, 0)], [0, 1])
        }
    }
    static let tongue = make(128) { c, s in
        c.setFillColor(rgba(1, 0.48, 0.56, 1))
        c.fillEllipse(in: CGRect(x: s * 0.08, y: s * 0.04, width: s * 0.84, height: s * 0.92))
        c.setStrokeColor(rgba(0.85, 0.3, 0.4, 0.6)); c.setLineWidth(s * 0.03)
        c.move(to: CGPoint(x: s / 2, y: s * 0.2)); c.addLine(to: CGPoint(x: s / 2, y: s * 0.8)); c.strokePath()
        radial(c, s * 0.36, s * 0.7, s * 0.2, [rgba(1, 1, 1, 0.55), rgba(1, 1, 1, 0)], [0, 1])
    }
    static let heart: CGImage = make(128) { c, s in
        let ctx = NSGraphicsContext(cgContext: c, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ("💗" as NSString).draw(at: NSPoint(x: s * 0.1, y: s * 0.12), withAttributes: [.font: NSFont.systemFont(ofSize: s * 0.72)])
        NSGraphicsContext.restoreGraphicsState()
    }
}

func glassMat(_ img: CGImage) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = img
    m.lightingModel = .constant
    m.isDoubleSided = true
    m.writesToDepthBuffer = false
    m.readsFromDepthBuffer = false     // 유리에 묻은 것 — 강아지보다 항상 앞
    m.blendMode = .alpha
    return m
}

final class Smear {
    enum Kind { case drool, fog, nose }
    let kind: Kind
    let node: SCNNode
    var wet: CGFloat = 1
    var age: CGFloat = 0
    let life: CGFloat
    var drip: SCNNode?
    var dripLen: CGFloat = 0, dripMax: CGFloat = 0
    let x: CGFloat, y: CGFloat
    init(_ k: Kind, _ x: CGFloat, _ y: CGFloat) {
        kind = k; self.x = x; self.y = y
        let size: CGFloat = k == .fog ? rnd(0.55, 0.75) : k == .nose ? 0.34 : rnd(0.28, 0.46)
        let p = SCNPlane(width: size * rnd(0.9, 1.3), height: size)
        p.materials = [glassMat(k == .fog ? Tex.fog : k == .nose ? Tex.nose : Tex.drool.randomElement()!)]
        node = SCNNode(geometry: p)
        node.position = SCNVector3(x, y, -0.003)
        node.eulerAngles = SCNVector3(0, 0, rnd(-0.6, 0.6))
        node.renderingOrder = 10
        life = k == .fog ? 1.6 : k == .nose ? 40 : rnd(25, 45)
        if k == .drool && Int.random(in: 0..<10) < 4 {     // 주르륵
            let d = SCNPlane(width: 0.045, height: 1)
            d.materials = [glassMat(Tex.drip)]
            let dn = SCNNode(geometry: d)
            dn.pivot = SCNMatrix4MakeTranslation(0, 0.5, 0)        // 위 끝을 기준으로 아래로 늘어난다
            dn.position = SCNVector3(x + rnd(-0.06, 0.06), y - 0.04, -0.002)
            dn.scale = SCNVector3(1, 0.01, 1)
            dn.renderingOrder = 11
            drip = dn
            dripMax = rnd(0.25, 0.9)
        }
    }
    var alpha: CGFloat {
        switch kind {
        case .fog: return max(0, 1 - age / life)
        default: return wet * (age < life ? 1 : max(0, 1 - (age - life) / 15))
        }
    }
}

final class Stage {
    let scene = SCNScene()
    let cam = SCNNode()
    let W: CGFloat, H: CGFloat      // 유리 위 크기 (단위)
    let floorY: CGFloat
    var dogs: [Dog] = []
    var smears: [Smear] = []
    let flat = SCNNode()
    var onLick: (() -> Void)?

    init(widthPt: CGFloat, heightPt: CGFloat, floorPt: CGFloat) {
        W = widthPt / U; H = heightPt / U
        floorY = floorPt / U - H / 2

        // 카메라 — 눈을 바닥 가까이 두고, 유리 면(z=0)이 창과 딱 맞게 비스듬한 절두체를 만든다
        let yc = floorY + EYE
        let c = SCNCamera()
        c.zNear = 0.5; c.zFar = 60
        let n: CGFloat = 0.5, f: CGFloat = 60
        let l = -W / 2 * n / DIST, r = W / 2 * n / DIST
        let b = (-H / 2 - yc) * n / DIST, t = (H / 2 - yc) * n / DIST
        var m = SCNMatrix4()
        m.m11 = 2 * n / (r - l); m.m22 = 2 * n / (t - b)
        m.m31 = (r + l) / (r - l); m.m32 = (t + b) / (t - b); m.m33 = -(f + n) / (f - n); m.m34 = -1
        m.m43 = -2 * f * n / (f - n)
        c.projectionTransform = m
        cam.camera = c
        cam.position = SCNVector3(0, yc, DIST)
        scene.rootNode.addChildNode(cam)

        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient
        amb.light!.intensity = 520; amb.light!.color = NSColor(srgbRed: 1, green: 0.97, blue: 0.94, alpha: 1)
        scene.rootNode.addChildNode(amb)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light!.type = .directional; sun.light!.intensity = 820
        sun.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(sun)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .directional; fill.light!.intensity = 260
        fill.eulerAngles = SCNVector3(-0.2, -2.4, 0)
        scene.rootNode.addChildNode(fill)
        let face = SCNNode(); face.light = SCNLight(); face.light!.type = .directional; face.light!.intensity = 380
        face.eulerAngles = SCNVector3(0.25, 0, 0)       // 화면 쪽에서 비추는 빛 — 일어섰을 때 배가 어둡지 않게
        scene.rootNode.addChildNode(face)

        let tp = SCNPlane(width: 0.22, height: 0.28)
        let tm = glassMat(Tex.tongue)
        tm.readsFromDepthBuffer = true
        tp.materials = [tm]
        flat.geometry = tp
        flat.isHidden = true
        flat.renderingOrder = 5
        scene.rootNode.addChildNode(flat)
    }

    func halfWidth(at z: CGFloat) -> CGFloat { W / 2 * (DIST - z) / DIST }

    // 창 좌표(pt, 왼쪽 아래 원점) → 유리 위 좌표
    func glass(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / U - W / 2, y: p.y / U - H / 2) }

    @discardableResult
    func addDog(_ b: Breed, from side: CGFloat? = nil) -> Dog {
        let d = Dog(b)
        let s = side ?? (Bool.random() ? -1 : 1)
        d.z = rnd(-2.6, -1.4)
        d.x = s * (halfWidth(at: d.z) + 1.2)
        d.yaw = s > 0 ? -.pi / 2 : .pi / 2
        d.tz = d.z
        d.tx = rnd(-halfWidth(at: d.z) * 0.6, halfWidth(at: d.z) * 0.6)
        d.state = .enter
        dogs.append(d)
        scene.rootNode.addChildNode(d.root)
        d.update(0, self, mouse: nil)
        return d
    }
    func remove(_ d: Dog) {
        d.root.removeFromParentNode()
        dogs.removeAll { $0 === d }
        if dogs.isEmpty { hideFlatTongue() }
    }
    func replace(_ d: Dog, with b: Breed) -> Dog {
        let n = Dog(b)
        n.x = d.x; n.z = d.z; n.yaw = d.yaw; n.tx = d.x; n.tz = d.z; n.state = .idle; n.timer = 0.5
        d.root.removeFromParentNode()
        if let i = dogs.firstIndex(where: { $0 === d }) { dogs[i] = n }
        scene.rootNode.addChildNode(n.root)
        n.update(0, self, mouse: nil)
        return n
    }

    func addSmear(_ k: Smear.Kind, _ x: CGFloat, _ y: CGFloat) {
        let s = Smear(k, x, y)
        scene.rootNode.addChildNode(s.node)
        if let d = s.drip { scene.rootNode.addChildNode(d) }
        smears.append(s)
        if smears.count > 400 { drop(smears[0]) }
    }
    func drop(_ s: Smear) {
        s.node.removeFromParentNode(); s.drip?.removeFromParentNode()
        smears.removeAll { $0 === s }
    }
    func clearSmears() { for s in smears { s.node.removeFromParentNode(); s.drip?.removeFromParentNode() }; smears = [] }

    func showFlatTongue(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) {
        flat.isHidden = false
        flat.position = SCNVector3(x, y, -0.012)
        flat.scale = SCNVector3(s, s, s)
    }
    func hideFlatTongue() { flat.isHidden = true }

    func addHeart(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        let p = SCNPlane(width: 0.4, height: 0.4)
        p.materials = [glassMat(Tex.heart)]
        p.materials[0].readsFromDepthBuffer = true
        let n = SCNNode(geometry: p)
        n.position = SCNVector3(x, y, z)
        n.constraints = [SCNBillboardConstraint()]
        n.renderingOrder = 20
        scene.rootNode.addChildNode(n)
        n.runAction(.sequence([.group([.moveBy(x: 0, y: 0.8, z: 0, duration: 1.1), .fadeOut(duration: 1.1)]), .removeFromParentNode()]))
    }

    // mouse: 유리 위 마우스 자리, rub: 이번 프레임에 움직인 거리(단위)
    func update(_ dt: CGFloat, mouse: CGPoint?, rub: CGFloat) {
        for d in dogs { d.update(dt, self, mouse: mouse) }
        // 강아지끼리 너무 겹치지 않게 앞뒤 순서만 맞춘다 (SceneKit 이 깊이로 알아서 그림)
        var gone: [Smear] = []
        for s in smears {
            s.age += dt
            if let m = mouse, rub > 0.02, s.kind != .fog, hypot(m.x - s.x, m.y - s.y) < 0.3 {
                s.wet -= rub * 1.6          // 문지르면 닦인다
            }
            if let d = s.drip {
                if s.dripLen < s.dripMax { s.dripLen += dt * 0.1 * (1.2 - s.dripLen / s.dripMax) }
                d.scale = SCNVector3(1, max(0.01, s.dripLen), 1)
                d.opacity = s.alpha
            }
            s.node.opacity = s.alpha
            if s.alpha <= 0.01 { gone.append(s) }
        }
        for s in gone { drop(s) }
    }

    func dog(at p: CGPoint, in view: SCNView) -> Dog? {
        let hits = view.hitTest(p, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .ignoreHiddenNodes: true])
        for h in hits {
            var n: SCNNode? = h.node
            while let c = n {
                if let d = dogs.first(where: { $0.root === c }) { return d }
                n = c.parent
            }
        }
        return nil
    }
}
