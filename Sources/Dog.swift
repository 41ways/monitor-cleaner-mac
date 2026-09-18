import AppKit
import SceneKit

// 로우폴리 강아지 — 상자·공·원기둥을 견종 수치대로 조립한다. 앞이 +z.

let SIZE: CGFloat = 1.6       // 전체 크기 — 유리 위 1 = 100pt

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
            blue: CGFloat(v & 255) / 255, alpha: 1)
}
func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...b) }
func ease(_ v: CGFloat, _ t: CGFloat, _ k: CGFloat) -> CGFloat { v + (t - v) * min(1, k) }
func angleDiff(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
    var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
    if d > .pi { d -= 2 * .pi }
    if d < -.pi { d += 2 * .pi }
    return d
}

func mat(_ c: NSColor, shiny: Bool = false) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = c
    m.lightingModel = shiny ? .blinn : .lambert
    if shiny { m.specular.contents = NSColor(white: 1, alpha: 1); m.shininess = 0.5 }
    return m
}
func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: NSColor, ch: CGFloat = 0.03, at p: SCNVector3) -> SCNNode {
    // 모서리를 세 번 나눠 깎는다 — 각은 살리되 부드럽게
    let g = SCNBox(width: w, height: h, length: l, chamferRadius: min(max(ch, 0.035), min(w, h, l) * 0.45))
    g.chamferSegmentCount = 3
    g.materials = [mat(c)]
    let n = SCNNode(geometry: g)
    n.position = p
    return n
}
func ball(_ r: CGFloat, _ c: NSColor, seg: Int = 18, shiny: Bool = false, at p: SCNVector3) -> SCNNode {
    let g = SCNSphere(radius: r)
    g.segmentCount = max(seg, 14)
    g.materials = [mat(c, shiny: shiny)]
    let n = SCNNode(geometry: g)
    n.position = p
    return n
}
func stick(_ r: CGFloat, _ len: CGFloat, _ c: NSColor) -> SCNNode {
    // 밑동이 원점, +y 로 뻗는 막대
    let g = SCNCylinder(radius: r, height: len)
    g.radialSegmentCount = 14
    g.materials = [mat(c)]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(0, len / 2, 0)
    let p = SCNNode()
    p.addChildNode(n)
    return p
}

enum Ear { case pointy(CGFloat), floppy(CGFloat), fluffy(CGFloat) }
enum Tail { case nub, curl, plume, up, long, sickle, feather }

struct Breed {
    let id: String
    let name: String
    var base: NSColor
    var light: NSColor
    var accent: NSColor = hex(0x2a2522)
    var earColor: NSColor? = nil
    var innerEar: NSColor = hex(0xf2b5a4)
    var eye: NSColor = hex(0x161412)
    var nose: NSColor = hex(0x1d1b1a)
    var bodyLen: CGFloat, bodyW: CGFloat, bodyH: CGFloat
    var legLen: CGFloat, legW: CGFloat = 0.13
    var head: CGFloat, muzzle: CGFloat
    var ear: Ear
    var tail: Tail
    var scale: CGFloat = 1
    var round: CGFloat = 0.12          // 몸 모서리 둥글기
    var lightMuzzle = true
    var blaze = false, chest = true, cheeks = false, mask = false, saddle = false
    var paws = true, ruff = false, tailTip = false
    var model: String? = nil          // 받아 온 모델(Resources/<이름>.json)을 잘라 쓴다
}

let BREEDS: [Breed] = [
    Breed(id: "corgi3d", name: "웰시코기 (받은 모델)", base: hex(0xe0883a), light: hex(0xfff5ea),
          bodyLen: 1.3, bodyW: 0.3, bodyH: 0.3, legLen: 0.12, head: 0.3, muzzle: 0.2,
          ear: .pointy(0.3), tail: .nub, scale: 0.85, model: "corgi"),
    Breed(id: "corgi", name: "웰시코기", base: hex(0xe0883a), light: hex(0xfff5ea),
          bodyLen: 1.05, bodyW: 0.5, bodyH: 0.42, legLen: 0.19, legW: 0.14, head: 0.46, muzzle: 0.2,
          ear: .pointy(0.36), tail: .nub, blaze: true),
    Breed(id: "shiba", name: "시바견", base: hex(0xd8772e), light: hex(0xfbf0de),
          bodyLen: 0.84, bodyW: 0.44, bodyH: 0.42, legLen: 0.36, head: 0.46, muzzle: 0.19,
          ear: .pointy(0.24), tail: .curl, cheeks: true),
    Breed(id: "pom", name: "포메라니안", base: hex(0xfbf4ea), light: hex(0xffffff), innerEar: hex(0xf6c9bb),
          bodyLen: 0.58, bodyW: 0.56, bodyH: 0.54, legLen: 0.13, legW: 0.12, head: 0.5, muzzle: 0.1,
          ear: .pointy(0.15), tail: .plume, scale: 0.85, round: 0.24, lightMuzzle: false, chest: false,
          paws: false, ruff: true),
    Breed(id: "husky", name: "시베리안 허스키", base: hex(0x5d6570), light: hex(0xf4f4f6), eye: hex(0x3f9be0),
          bodyLen: 0.95, bodyW: 0.46, bodyH: 0.44, legLen: 0.42, head: 0.46, muzzle: 0.22,
          ear: .pointy(0.3), tail: .sickle, scale: 1.05, round: 0.1, mask: true, ruff: true),
    Breed(id: "dachs", name: "닥스훈트", base: hex(0x8a4822), light: hex(0x9b5630), earColor: hex(0x6e3718),
          bodyLen: 1.2, bodyW: 0.36, bodyH: 0.34, legLen: 0.13, legW: 0.12, head: 0.38, muzzle: 0.3,
          ear: .floppy(0.32), tail: .long, lightMuzzle: false, chest: false, paws: false),
    Breed(id: "beagle", name: "비글", base: hex(0xc8863f), light: hex(0xffffff), earColor: hex(0xa8672b),
          bodyLen: 0.86, bodyW: 0.42, bodyH: 0.4, legLen: 0.34, head: 0.44, muzzle: 0.22,
          ear: .floppy(0.36), tail: .up, blaze: true, saddle: true, tailTip: true),
    Breed(id: "golden", name: "골든 리트리버", base: hex(0xe0a650), light: hex(0xf3cf86), earColor: hex(0xcf9140),
          bodyLen: 1.05, bodyW: 0.48, bodyH: 0.46, legLen: 0.46, legW: 0.15, head: 0.46, muzzle: 0.25,
          ear: .floppy(0.3), tail: .feather, scale: 1.1, round: 0.1, lightMuzzle: false, chest: false, paws: false),
    Breed(id: "maltese", name: "말티즈", base: hex(0xffffff), light: hex(0xffffff), innerEar: hex(0xffffff),
          bodyLen: 0.7, bodyW: 0.46, bodyH: 0.46, legLen: 0.16, legW: 0.13, head: 0.44, muzzle: 0.12,
          ear: .fluffy(0.3), tail: .plume, scale: 0.85, round: 0.2, lightMuzzle: false, chest: false,
          paws: false, ruff: true),
]

final class Dog {
    enum State { case enter, idle, walk, toGlass, rear, lick, down, pet }

    let breed: Breed
    let root = SCNNode()
    let hip = SCNNode()
    let head = SCNNode()
    let tongue = SCNNode()
    let tail = SCNNode()
    let nose = SCNNode()
    var front: [SCNNode] = [], hind: [SCNNode] = []

    // 움직임
    var x: CGFloat = 0, z: CGFloat = -2, yaw: CGFloat = .pi / 2
    var tx: CGFloat = 0, tz: CGFloat = -2
    var speed: CGFloat = 0, maxSpeed: CGFloat = 1.3
    var state: State = .enter
    var timer: CGFloat = 0
    var phase: CGFloat = 0, t: CGFloat = 0
    var rear: CGFloat = 0, headYaw: CGFloat = 0, headNod: CGFloat = 0
    var tongueOut: CGFloat = 0, wag: CGFloat = 4
    var jump: CGFloat = 0, spin: CGFloat = 0
    var licks = 0, lickT: CGFloat = 0, fogT: CGFloat = 0, printed = false
    var wantLick = false
    var hipY: CGFloat = 0
    var height: CGFloat = 1

    init(_ b: Breed) {
        breed = b
        if let m = b.model, let md = ModelData.load(m) {
            buildModel(md)
            return
        }
        let L = b.legLen, bh = b.bodyH, bl = b.bodyLen, bw = b.bodyW, h = b.head
        let hipP = SCNVector3(0, L + bh * 0.5, -bl * 0.38)
        hipY = hipP.y
        height = L + bh + h
        hip.position = hipP
        root.addChildNode(hip)
        func add(_ n: SCNNode, _ p: SCNVector3, to parent: SCNNode? = nil) {
            n.position = SCNVector3(p.x - hipP.x, p.y - hipP.y, p.z - hipP.z)
            (parent ?? hip).addChildNode(n)
        }
        let base = b.base, light = b.light

        // 몸통
        add(box(bw, bh, bl, base, ch: b.round, at: SCNVector3Zero), SCNVector3(0, L + bh / 2, 0))
        if b.chest {
            add(box(bw * 0.84, bh * 0.3, bl * 0.8, light, ch: 0.03, at: SCNVector3Zero), SCNVector3(0, L + bh * 0.14, 0.02))
            add(box(bw * 0.8, bh * 0.78, 0.07, light, ch: 0.03, at: SCNVector3Zero), SCNVector3(0, L + bh * 0.44, bl / 2 - 0.01))
        }
        if b.saddle {
            add(box(bw * 1.04, bh * 0.46, bl * 0.66, b.accent, ch: 0.04, at: SCNVector3Zero), SCNVector3(0, L + bh * 0.8, -0.06))
        }
        if b.ruff {
            add(ball(bw * 0.6, b.mask ? light : base, seg: 8, at: SCNVector3Zero), SCNVector3(0, L + bh * 0.6, bl / 2 - 0.08))
        }

        // 다리
        for (i, zz) in [bl / 2 - b.legW * 0.9, -bl / 2 + b.legW * 0.9].enumerated() {
            for sx in [-1.0, 1.0] as [CGFloat] {
                let pv = SCNNode()
                add(pv, SCNVector3(sx * bw * 0.3, L + bh * 0.25, zz))
                let len = L + bh * 0.25
                let cap = SCNCapsule(capRadius: b.legW / 2, height: len + b.legW * 0.3)
                cap.radialSegmentCount = 14; cap.capSegmentCount = 8
                cap.materials = [mat(base)]
                let leg = SCNNode(geometry: cap)
                leg.position = SCNVector3(0, -len / 2 + b.legW * 0.1, 0)
                pv.addChildNode(leg)
                let paw = ball(b.legW * 0.62, b.paws ? light : base, at: SCNVector3(0, -len + b.legW * 0.28, 0.03))
                paw.scale = SCNVector3(1, 0.62, 1.25)
                pv.addChildNode(paw)
                if i == 0 { front.append(pv) } else { hind.append(pv) }
            }
        }

        // 꼬리
        add(tail, SCNVector3(0, L + bh * 0.82, -bl / 2 + 0.02))
        switch b.tail {
        case .nub:
            tail.addChildNode(ball(0.1, base, seg: 7, at: SCNVector3(0, 0.02, -0.04)))
        case .curl:
            let g = SCNTorus(ringRadius: 0.12, pipeRadius: 0.06)
            g.ringSegmentCount = 24; g.pipeSegmentCount = 12
            g.materials = [mat(base)]
            let n = SCNNode(geometry: g)
            n.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2)
            n.position = SCNVector3(0, 0.16, 0.04)
            tail.addChildNode(n)
        case .plume:
            let n = ball(bw * 0.42, base, seg: 8, at: SCNVector3(0, 0.12, 0.06))
            n.scale = SCNVector3(0.9, 0.75, 1.15)
            tail.addChildNode(n)
        case .up, .long, .sickle, .feather:
            let (r, len, ang): (CGFloat, CGFloat, CGFloat) = {
                switch b.tail {
                case .up: return (0.035, 0.38, -0.35)
                case .long: return (0.032, 0.42, -2.05)
                case .sickle: return (0.07, 0.34, -0.55)
                default: return (0.075, 0.44, -2.25)
                }
            }()
            let s = stick(r, len, base)
            s.eulerAngles = SCNVector3(ang, 0, 0)
            if b.tailTip || b.mask { s.addChildNode(ball(r * 1.35, light, seg: 6, at: SCNVector3(0, len, 0))) }
            if case .sickle = b.tail {       // 허스키는 끝이 등 쪽으로 말린다
                let s2 = stick(r * 0.9, len * 0.6, base)
                s2.position = SCNVector3(0, len, 0)
                s2.eulerAngles = SCNVector3(-0.9, 0, 0)
                s.addChildNode(s2)
            }
            if case .feather = b.tail { s.scale = SCNVector3(0.7, 1, 1.5) }
            tail.addChildNode(s)
        }

        // 머리
        add(head, SCNVector3(0, L + bh * 0.8, bl / 2 - 0.04))
        let hb = box(h, h * 0.9, h * 0.95, base, ch: max(0.1, b.round * 0.7), at: SCNVector3(0, h * 0.3, h * 0.2))
        head.addChildNode(hb)
        let hf = h * 0.675
        let ml = b.muzzle
        head.addChildNode(box(h * 0.56, h * 0.36, ml, b.lightMuzzle ? light : base, ch: 0.08,
                              at: SCNVector3(0, h * 0.12, hf + ml / 2 - 0.03)))
        let mf = hf + ml - 0.03
        nose.addChildNode(box(h * 0.22, h * 0.13, 0.07, b.nose, ch: 0.03, at: SCNVector3Zero))
        nose.position = SCNVector3(0, h * 0.26, mf + 0.01)
        head.addChildNode(nose)
        for sx in [-1.0, 1.0] as [CGFloat] {
            let e = ball(h * 0.075, b.eye, seg: 8, shiny: true, at: SCNVector3(sx * h * 0.22, h * 0.44, hf + 0.005))
            e.addChildNode(ball(h * 0.025, .white, seg: 6, at: SCNVector3(h * 0.025, h * 0.03, h * 0.06)))
            head.addChildNode(e)
        }
        if b.blaze {
            head.addChildNode(box(h * 0.15, h * 0.52, 0.03, light, ch: 0.01, at: SCNVector3(0, h * 0.5, hf + 0.004)))
            head.addChildNode(box(h * 0.8, h * 0.28, 0.03, light, ch: 0.01, at: SCNVector3(0, h * 0.06, hf + 0.004)))
        }
        if b.cheeks {
            for sx in [-1.0, 1.0] as [CGFloat] {
                head.addChildNode(box(h * 0.3, h * 0.3, 0.03, light, ch: 0.01, at: SCNVector3(sx * h * 0.3, h * 0.12, hf + 0.004)))
                head.addChildNode(box(h * 0.12, h * 0.07, 0.03, light, ch: 0.01, at: SCNVector3(sx * h * 0.22, h * 0.57, hf + 0.004)))
            }
        }
        if b.mask {
            head.addChildNode(box(h * 0.9, h * 0.46, 0.03, light, ch: 0.01, at: SCNVector3(0, h * 0.14, hf + 0.004)))
            head.addChildNode(box(h * 0.12, h * 0.34, 0.03, light, ch: 0.01, at: SCNVector3(0, h * 0.55, hf + 0.004)))
            for sx in [-1.0, 1.0] as [CGFloat] {
                head.addChildNode(box(h * 0.13, h * 0.08, 0.03, light, ch: 0.01, at: SCNVector3(sx * h * 0.22, h * 0.58, hf + 0.004)))
            }
        }
        // 귀
        let earC = b.earColor ?? base
        switch b.ear {
        case .pointy(let e):
            for sx in [-1.0, 1.0] as [CGFloat] {
                let g = SCNCone(topRadius: 0.01, bottomRadius: e * 0.4, height: e)
                g.radialSegmentCount = 16
                g.materials = [mat(earC)]
                let n = SCNNode(geometry: g)
                n.scale = SCNVector3(1, 1, 0.42)
                n.position = SCNVector3(sx * h * 0.27, h * 0.72 + e * 0.5, h * 0.12)
                n.eulerAngles = SCNVector3(0, 0, -sx * 0.2)
                let gi = SCNCone(topRadius: 0.005, bottomRadius: e * 0.25, height: e * 0.72)
                gi.radialSegmentCount = 16
                gi.materials = [mat(b.innerEar)]
                let ni = SCNNode(geometry: gi)
                ni.scale = SCNVector3(1, 1, 0.25)
                ni.position = SCNVector3(0, -e * 0.1, e * 0.34)
                n.addChildNode(ni)
                head.addChildNode(n)
            }
        case .floppy(let e):
            for sx in [-1.0, 1.0] as [CGFloat] {
                let pv = SCNNode()
                pv.position = SCNVector3(sx * (h * 0.5 + 0.025), h * 0.62, h * 0.22)
                pv.eulerAngles = SCNVector3(0, 0, sx * 0.12)
                let ear = ball(e * 0.5, earC, at: SCNVector3(0, -e / 2 + 0.05, 0))
                ear.scale = SCNVector3(0.14, 1, 0.58)
                pv.addChildNode(ear)
                head.addChildNode(pv)
            }
        case .fluffy(let e):
            for sx in [-1.0, 1.0] as [CGFloat] {
                let n = ball(e * 0.42, earC, seg: 8, at: SCNVector3(sx * h * 0.52, h * 0.2, h * 0.18))
                n.scale = SCNVector3(0.8, 1.45, 1)
                head.addChildNode(n)
            }
        }
        // 혀 — 평소엔 입 안에
        tongue.position = SCNVector3(0, h * 0.02, mf - 0.08)
        tongue.addChildNode(box(h * 0.26, 0.035, h * 0.42, hex(0xff7b8c), ch: 0.015, at: SCNVector3(0, -0.02, h * 0.21)))
        tongue.scale = SCNVector3(1, 1, 0.01)
        head.addChildNode(tongue)

        // 발밑 그림자
        let sh = SCNPlane(width: bw * 2.2, height: bl * 1.7)
        let sm = SCNMaterial()
        sm.diffuse.contents = Tex.shadow
        sm.lightingModel = .constant
        sm.writesToDepthBuffer = false
        sh.materials = [sm]
        let shn = SCNNode(geometry: sh)
        shn.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        shn.position = SCNVector3(0, 0.005, 0)
        shn.renderingOrder = -1
        root.addChildNode(shn)

        let k = b.scale * SIZE
        root.scale = SCNVector3(k, k, k)
        maxSpeed = 1.1 + L * 1.6
    }

    func worldNose() -> SCNVector3 { nose.convertPosition(SCNVector3Zero, to: nil) }

    func pet() {
        state = .pet
        timer = 0
        wag = 16
    }

    func goLick() { wantLick = true; if state == .idle || state == .walk { state = .idle; timer = 0 } }

    // 한 프레임
    func update(_ dt: CGFloat, _ st: Stage, mouse: CGPoint?) {
        t += dt
        timer -= dt
        var walking = false
        var targetYaw = yaw
        var targetRear: CGFloat = 0
        var tongueTarget: CGFloat = 0
        var nodTarget: CGFloat = 0
        func moveTo(_ gx: CGFloat, _ gz: CGFloat, _ sp: CGFloat) -> Bool {
            let dx = gx - x, dz = gz - z, d = hypot(dx, dz)
            if d < 0.06 { speed = ease(speed, 0, dt * 8); return true }
            targetYaw = atan2(dx, dz)
            let turn = abs(angleDiff(yaw, targetYaw))
            speed = ease(speed, sp * max(0.15, 1 - turn / 1.4) * min(1, d / 0.35 + 0.25), dt * 4)
            x += sin(yaw) * speed * dt
            z += cos(yaw) * speed * dt
            walking = true
            return false
        }

        switch state {
        case .enter:
            if moveTo(tx, tz, maxSpeed) { state = .idle; timer = rnd(0.6, 1.6) }
        case .idle:
            speed = ease(speed, 0, dt * 6)
            if timer <= 0 {
                let r = CGFloat.random(in: 0...1)
                if wantLick || r < 0.3 {
                    wantLick = false
                    state = .toGlass
                    tx = max(-st.halfWidth(at: -1) + 1, min(st.halfWidth(at: -1) - 1, x + rnd(-2, 2)))
                    tz = -1.0
                } else {
                    state = .walk
                    tz = rnd(-3.2, -1.2)
                    let hw = st.halfWidth(at: tz) - 0.9
                    tx = r < 0.45 ? (x > 0 ? -hw : hw) * rnd(0.6, 1) : rnd(-hw, hw)   // 가끔 반대편 끝까지 달린다
                    maxSpeed = (1.1 + breed.legLen * 1.6) * (r < 0.45 ? 1.9 : 1)
                }
            }
        case .walk:
            if moveTo(tx, tz, maxSpeed) { state = .idle; timer = rnd(0.8, 3) }
        case .toGlass:
            if moveTo(tx, tz, 1.2) {
                targetYaw = 0
                if abs(angleDiff(yaw, 0)) < 0.08 { state = .rear; printed = false }
            }
        case .rear, .lick:
            targetYaw = 0
            targetRear = 1
            speed = 0
            // 코가 유리(z=0)에 닿도록 몸을 앞으로 민다
            let nz = worldNose().z
            z += (-0.07 - nz) / (breed.scale * SIZE) * min(1, dt * 5)
            if state == .rear, rear > 0.95, abs(nz + 0.07) < 0.05 {
                state = .lick
                licks = Int.random(in: 5...9)
                lickT = 0
                if !printed { printed = true; let n = worldNose(); st.addSmear(.nose, n.x, n.y) }
            }
            fogT -= dt
            if fogT <= 0, rear > 0.8 {   // 입김
                fogT = rnd(0.8, 1.3)
                let n = worldNose()
                st.addSmear(.fog, n.x, n.y - 0.1)
            }
            if state == .lick {
                let period: CGFloat = 0.5
                let before = lickT
                lickT += dt
                let p = lickT / period
                tongueTarget = p < 0.75 ? 1 : 0
                nodTarget = -0.22 * sin(min(1, p) * .pi)
                let n = worldNose()
                let fy = n.y - 0.36 * breed.scale * SIZE + min(1, p / 0.7) * 0.28 * breed.scale * SIZE
                if p > 0.1 && p < 0.75 {
                    st.showFlatTongue(n.x, fy, breed.scale * SIZE)
                } else { st.hideFlatTongue() }
                for mark: CGFloat in [0.25, 0.5] where before / period < mark && p >= mark {
                    st.addSmear(.drool, n.x + rnd(-0.05, 0.05), fy + rnd(-0.03, 0.03))
                }
                if before / period < 0.12 && p >= 0.12 { st.onLick?() }
                if p >= 1 {
                    lickT = 0
                    licks -= 1
                    x += rnd(-0.18, 0.18)        // 옆으로 조금씩 옮겨 가며
                    if licks <= 0 { state = .down; timer = 0.9; st.hideFlatTongue() }
                }
            }
        case .down:
            targetRear = 0
            if timer < 0.3 { z = ease(z, -1.4, dt * 2) }
            if timer <= 0 { state = .idle; timer = rnd(0.5, 1.5) }
        case .pet:
            let p = -timer / 0.7       // 0 → 1
            jump = p < 1 ? sin(p * .pi) * 0.45 : 0
            spin = p < 1 ? p * 2 * .pi : 0
            if timer > -0.02 { st.addHeart(x, height * breed.scale * SIZE + st.floorY + 0.4, z) }
            if p >= 1.6 { state = .idle; timer = rnd(0.8, 1.5); jump = 0; spin = 0; wag = 4 }
        }
        if state != .pet { wag = ease(wag, walking ? 7 : (state == .lick ? 12 : 4), dt * 2) }

        // 방향·자세
        yaw += angleDiff(yaw, targetYaw) * min(1, dt * 7)
        rear = ease(rear, targetRear, dt * 4)
        tongueOut = ease(tongueOut, max(tongueTarget, speed > 1.6 ? 0.55 : 0), dt * 14)
        headNod = ease(headNod, nodTarget, dt * 10)
        // 유리 쪽 마우스를 쳐다본다
        var hy: CGFloat = 0
        if let m = mouse, state != .lick, state != .rear {
            let want = atan2(m.x - x, -z)
            hy = max(-0.7, min(0.7, angleDiff(yaw, want)))
        }
        headYaw = ease(headYaw, hy, dt * 4)

        if walking || speed > 0.05 { phase += dt * (4 + speed * 5) }
        let sw = sin(phase) * min(0.65, speed * 0.5)
        root.position = SCNVector3(x, st.floorY + jump, z)
        root.eulerAngles = SCNVector3(0, yaw + spin, 0)
        let R = rear * 0.95
        hip.eulerAngles = SCNVector3(-R, 0, 0)
        hip.position.y = hipY + abs(cos(phase)) * min(0.04, speed * 0.02)
        for (i, l) in front.enumerated() {
            l.eulerAngles = SCNVector3((i == 0 ? sw : -sw) * (1 - rear) - rear * 0.55 + sin(t * 9 + CGFloat(i)) * 0.12 * rear, 0, 0)
        }
        for (i, l) in hind.enumerated() {
            l.eulerAngles = SCNVector3((i == 0 ? -sw : sw) * (1 - rear) + R, 0, 0)
        }
        head.eulerAngles = SCNVector3(rear * 0.8 + headNod + sin(phase * 2) * 0.03, headYaw, 0)
        tail.eulerAngles = SCNVector3(0, sin(t * wag) * 0.5, 0)
        tongue.scale = SCNVector3(1, 1, max(0.01, tongueOut))
        tongue.eulerAngles = SCNVector3(0.35 * tongueOut * (1 - rear), 0, 0)
    }
}


// 받아 온 모델 — split.py 가 부위별로 잘라 둔 것
struct ModelData {
    struct Part { let pivot: SCNVector3; let geo: SCNGeometry }
    var parts: [String: Part] = [:]
    var nose = SCNVector3Zero
    var size = SCNVector3Zero

    static var cache: [String: ModelData] = [:]
    static func url(_ file: String) -> URL? {
        if let u = Bundle.main.resourceURL?.appendingPathComponent(file), FileManager.default.fileExists(atPath: u.path) { return u }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).absoluteURL.deletingLastPathComponent()
        for base in [exe.appendingPathComponent("../Resources"), URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")] {
            let u = base.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: u.path) { return u.absoluteURL.standardizedFileURL }
        }
        return nil
    }
    static func load(_ name: String) -> ModelData? {
        if let c = cache[name] { return c }
        let uu = url(name + ".json"); if ProcessInfo.processInfo.environment["MC_DEBUG"] != nil { print("model url", uu as Any) }
        guard let u = uu, let d = try? Data(contentsOf: u),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let ps = j["parts"] as? [String: [String: Any]] else { return nil }
        let tex = (j["texture"] as? String).flatMap { url($0) }.flatMap { NSImage(contentsOf: $0) }
        let m = SCNMaterial()
        m.diffuse.contents = tex ?? NSColor.orange
        m.lightingModel = .lambert
        m.isDoubleSided = true
        var md = ModelData()
        func v3(_ a: Any?) -> SCNVector3 {
            let x = (a as? [Double]) ?? [0, 0, 0]
            return SCNVector3(x[0], x[1], x[2])
        }
        md.nose = v3(j["nose"]); md.size = v3(j["size"])
        for (name, p) in ps {
            let v = (p["v"] as? [Double]) ?? [], n = (p["n"] as? [Double]) ?? [], t = (p["uv"] as? [Double]) ?? []
            let cnt = v.count / 3
            var vs = [SCNVector3](), ns = [SCNVector3](), ts = [CGPoint]()
            for i in 0..<cnt {
                vs.append(SCNVector3(v[i * 3], v[i * 3 + 1], v[i * 3 + 2]))
                ns.append(SCNVector3(n[i * 3], n[i * 3 + 1], n[i * 3 + 2]))
                ts.append(CGPoint(x: t[i * 2], y: t[i * 2 + 1]))
            }
            let el = SCNGeometryElement(indices: (0..<Int32(cnt)).map { $0 }, primitiveType: .triangles)
            let g = SCNGeometry(sources: [SCNGeometrySource(vertices: vs), SCNGeometrySource(normals: ns),
                                          SCNGeometrySource(textureCoordinates: ts)], elements: [el])
            g.materials = [m]
            md.parts[name] = Part(pivot: v3(p["pivot"]), geo: g)
        }
        cache[name] = md
        return md
    }
}

extension Dog {
    func buildModel(_ md: ModelData) {
        let hipP = md.parts["body"]?.pivot ?? SCNVector3(0, 0.3, -0.3)
        hip.position = hipP
        hipY = hipP.y
        height = md.size.y
        root.addChildNode(hip)
        func rel(_ p: SCNVector3, _ to: SCNVector3) -> SCNVector3 { SCNVector3(p.x - to.x, p.y - to.y, p.z - to.z) }
        for (name, p) in md.parts {
            let n: SCNNode
            switch name {
            case "head": n = head
            case "tail": n = tail
            case "body": n = SCNNode()
            default: n = SCNNode(); if name.hasPrefix("legF") { front.append(n) } else { hind.append(n) }
            }
            n.geometry = p.geo
            n.position = rel(p.pivot, hipP)
            hip.addChildNode(n)
        }
        // 코와 혀 — 머리 관절 기준
        let hp = md.parts["head"]?.pivot ?? hipP
        nose.position = rel(md.nose, hp)
        head.addChildNode(nose)
        tongue.position = SCNVector3(nose.position.x, nose.position.y - 0.1, nose.position.z - 0.1)
        tongue.addChildNode(box(0.1, 0.03, 0.18, hex(0xff7b8c), ch: 0.012, at: SCNVector3(0, -0.02, 0.09)))
        tongue.scale = SCNVector3(1, 1, 0.01)
        head.addChildNode(tongue)

        let sh = SCNPlane(width: CGFloat(md.size.x) * 2.6, height: CGFloat(md.size.z) * 1.3)
        let sm = SCNMaterial()
        sm.diffuse.contents = Tex.shadow
        sm.lightingModel = .constant
        sm.writesToDepthBuffer = false
        sh.materials = [sm]
        let shn = SCNNode(geometry: sh)
        shn.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        shn.position = SCNVector3(0, 0.005, 0.15)
        shn.renderingOrder = -1
        root.addChildNode(shn)

        let k = breed.scale * SIZE
        root.scale = SCNVector3(k, k, k)
        maxSpeed = 1.3
    }
}
