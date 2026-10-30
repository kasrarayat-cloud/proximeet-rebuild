import SwiftUI
import SceneKit
import UIKit
import simd
import ProximeetDomain

/// The invitation's decorative studio objects. Real geometry, broad studio reflections and soft local
/// ground light replace the previous flat approximation. A local display clock moves only this artwork:
/// it never sends, accepts, schedules, stores or changes an invitation. The parent owns every state.
struct PrivateInvitationArtwork: View {
    let intent: BandIntent
    let accepted: Bool
    let width: CGFloat
    var viewerName: String = "Alex"
    var counterpartName: String? = nil
    var isActive: Bool = true
    @Adaptive private var adaptive
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let availableWidth = width.isFinite ? max(0, width) : 0
        let factor = min(1, availableWidth / 376)
        InvitationStudioView(intent: intent, accepted: accepted,
                             viewerName: viewerName, counterpartName: counterpartName ?? "",
                             active: isActive && scenePhase == .active,
                             staticPose: adaptive.reduceMotion || adaptive.voiceOverRunning)
            .frame(width: availableWidth, height: 220 * factor)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("wave.artwork.\(intent.rawValue)")
            .accessibilityHidden(true)
    }
}

private struct InvitationStudioView: UIViewRepresentable {
    let intent: BandIntent
    let accepted: Bool
    let viewerName: String
    let counterpartName: String
    let active: Bool
    let staticPose: Bool

    func makeCoordinator() -> InvitationStudioCoordinator { InvitationStudioCoordinator() }

    func makeUIView(context: Context) -> InvitationSceneView {
        let view = InvitationSceneView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue,
        ])
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ view: InvitationSceneView, context: Context) {
        context.coordinator.update(intent: intent, accepted: accepted, viewerName: viewerName,
                                   counterpartName: counterpartName, active: active, staticPose: staticPose)
    }

    static func dismantleUIView(_ view: InvitationSceneView, coordinator: InvitationStudioCoordinator) {
        coordinator.stop()
        view.visibilityChanged = nil
        view.stopObservingScroll()
        view.scene = nil
    }
}

/// Observe the containing scroll view rather than running an offscreen rendering timer. A clipped
/// hero suspends its display link and resumes from the same decorative time when revealed again.
@MainActor
private final class InvitationSceneView: SCNView {
    var visibilityChanged: (() -> Void)?
    private var scrollObservation: NSKeyValueObservation?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        stopObservingScroll()
        if window != nil {
            var ancestor = superview
            while let item = ancestor {
                if let scroll = item as? UIScrollView {
                    scrollObservation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                        MainActor.assumeIsolated { self?.visibilityChanged?() }
                    }
                    break
                }
                ancestor = item.superview
            }
        }
        visibilityChanged?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        visibilityChanged?()
    }

    var visibleInWindow: Bool {
        guard let window, !isHidden, alpha > 0, bounds.width > 0, bounds.height > 0 else { return false }
        var visible = convert(bounds, to: window).intersection(window.bounds)
        var ancestor = superview
        while let item = ancestor, item !== window {
            if item.isHidden || item.alpha <= 0 { return false }
            if item.clipsToBounds { visible = visible.intersection(item.convert(item.bounds, to: window)) }
            ancestor = item.superview
        }
        return !visible.isNull && visible.width > 1 && visible.height > 1
    }

    func stopObservingScroll() {
        scrollObservation?.invalidate()
        scrollObservation = nil
    }
}

/// Weak indirection prevents CADisplayLink from retaining the coordinator after the SwiftUI subtree
/// is removed by Leave, Block, a closed invitation or navigation.
@MainActor
private final class InvitationDisplayTarget: NSObject {
    weak var owner: InvitationStudioCoordinator?
    @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
}

@MainActor
private final class InvitationStudioCoordinator {
    private weak var view: InvitationSceneView?
    private let scene = SCNScene()
    private let objects = SCNNode()
    private let camera = SCNNode()
    private let lightRig = SCNNode()
    private var sculptures: [SCNNode] = []
    private var markers: [SCNNode] = []
    private var displayLink: CADisplayLink?
    private let displayTarget = InvitationDisplayTarget()
    private var previousTick: CFTimeInterval?
    private var elapsed: Double = 0
    private var intent: BandIntent?
    private var names = [String]()
    private var active = false
    private var staticPose = true
    private var accepted = false
    private var acceptance: Double = 0
    private var acceptanceFrom: Double = 0
    private var acceptanceElapsed: Double = 0.8
    private var ready = false

    func attach(_ view: InvitationSceneView) {
        self.view = view
        displayTarget.owner = self
        view.scene = scene
        #if DEBUG
        let scalarBridge: Any = CGFloat(0.97)
        NSLog("PRIVATE_INVITATION_RENDERER api=\(view.renderingAPI.rawValue) isMetal=\(view.renderingAPI == .metal) metalDevice=\(view.device != nil) cgFloatBridgesNSNumber=\(scalarBridge is NSNumber) metalnessNSNumber=\(InvitationStudioMaterials.chrome.metalness.contents is NSNumber)")
        #endif
        scene.rootNode.addChildNode(objects)
        scene.rootNode.addChildNode(lightRig)
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.72
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 40
        camera.camera?.wantsHDR = true
        // This authored studio has fixed exposure. Automatic HDR adaptation would animate
        // brightness even while geometry is paused for Reduce Motion or VoiceOver.
        camera.camera?.wantsExposureAdaptation = false
        camera.camera?.exposureOffset = -0.2
        camera.camera?.bloomIntensity = 0.06
        camera.camera?.bloomThreshold = 1.35
        camera.camera?.bloomBlurRadius = 4
        camera.position = SCNVector3(0, 1.75, 8)
        camera.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        scene.lightingEnvironment.contents = InvitationStudioMaterials.environment
        scene.lightingEnvironment.intensity = 1.0
        addLight(type: .directional, color: .white, intensity: 700,
                 position: SCNVector3(-3, 5, 4), castsShadow: true)
        addLight(type: .directional, color: UIColor(red: 0.79, green: 0.87, blue: 1, alpha: 1),
                 intensity: 260, position: SCNVector3(4, 2, 1), castsShadow: false)
        addLight(type: .ambient, color: UIColor(white: 0.8, alpha: 1), intensity: 90,
                 position: SCNVector3Zero, castsShadow: false)
        // The scene stays transparent around the sculpture. A local soft pool of light below
        // supplies grounding without an infinite lit floor creating a charcoal rectangular panel.
        view.visibilityChanged = { [weak self] in self?.refreshPlayback() }
    }

    private func addLight(type: SCNLight.LightType, color: UIColor, intensity: CGFloat,
                          position: SCNVector3, castsShadow: Bool) {
        let light = SCNLight()
        light.type = type
        light.color = color
        light.intensity = intensity
        light.castsShadow = castsShadow
        if castsShadow {
            light.shadowMode = .deferred
            light.shadowColor = UIColor.black.withAlphaComponent(0.5)
            light.shadowRadius = 7
            light.shadowMapSize = CGSize(width: 1024, height: 1024)
            light.orthographicScale = 5
            light.zNear = 0.1
            light.zFar = 18
        }
        let node = SCNNode()
        node.light = light
        node.position = position
        if type != .ambient { node.look(at: SCNVector3Zero) }
        lightRig.addChildNode(node)
    }

    func update(intent: BandIntent, accepted: Bool, viewerName: String, counterpartName: String,
                active: Bool, staticPose: Bool) {
        let newNames = [viewerName, counterpartName]
        let rebuild = self.intent != intent || names != newNames
        let motionChanged = self.staticPose != staticPose
        self.active = active
        self.staticPose = staticPose
        if rebuild {
            self.intent = intent
            names = newNames
            elapsed = 0
            sculptures.removeAll()
            markers.removeAll()
            objects.childNodes.forEach { $0.removeFromParentNode() }
            build(intent, names: newNames)
            acceptance = accepted ? 1 : 0
            acceptanceFrom = acceptance
            acceptanceElapsed = 0.8
            self.accepted = accepted
            ready = true
        } else if self.accepted != accepted {
            acceptanceFrom = acceptance
            acceptanceElapsed = 0
            self.accepted = accepted
        }
        if staticPose || motionChanged {
            elapsed = 0
            acceptance = accepted ? 1 : 0
            acceptanceElapsed = 0.8
        }
        pose()
        refreshPlayback()
    }

    private func refreshPlayback() {
        guard let view else { return }
        let plays = ready && active && !staticPose && view.visibleInWindow
        if plays && displayLink == nil {
            previousTick = nil
            let link = CADisplayLink(target: displayTarget, selector: #selector(InvitationDisplayTarget.tick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else if !plays {
            displayLink?.invalidate()
            displayLink = nil
            previousTick = nil
        }
        // The main-actor display link changes only scene transforms. Rendering is capped at 30 fps,
        // pauses with the scene, and introduces no repeating UIView animation for XCTest to await.
        view.isPlaying = plays
        view.rendersContinuously = false
        if !plays { view.setNeedsDisplay() }
    }

    func tick(_ link: CADisplayLink) {
        let delta = previousTick.map { min(0.1, max(0, link.timestamp - $0)) } ?? 0
        previousTick = link.timestamp
        elapsed += delta
        acceptanceElapsed = min(0.8, acceptanceElapsed + delta)
        let t = acceptanceElapsed / 0.8
        let eased = 1 - pow(1 - t, 3)
        acceptance = acceptanceFrom + ((accepted ? 1.0 : 0.0) - acceptanceFrom) * eased
        pose()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        displayTarget.owner = nil
        view?.isPlaying = false
        view?.rendersContinuously = false
        view?.visibilityChanged = nil
        view = nil
    }

    private func build(_ intent: BandIntent, names: [String]) {
        let accent = UIColor(intent.tint)
        let glow = InvitationStudioGeometry.glow(color: accent)
        glow.position = SCNVector3(0, -1.285, 0)
        objects.addChildNode(glow)
        switch intent {
        case .business:
            sculptures = names.enumerated().map { InvitationStudioGeometry.card(name: $0.element, corner: $0.offset == 0) }
        case .social:
            sculptures = [InvitationStudioGeometry.bubble(), InvitationStudioGeometry.bubble()]
            sculptures[1].scale.x = -1
        case .dating:
            sculptures = [InvitationStudioGeometry.petal(), InvitationStudioGeometry.petal()]
            sculptures[1].scale.x = -1
        case .activity:
            let route = InvitationStudioGeometry.trail()
            objects.addChildNode(route)
            sculptures = [route]
            markers = [InvitationStudioGeometry.marker(), InvitationStudioGeometry.marker()]
            markers.forEach { route.addChildNode($0) }
        }
        if intent != .activity { sculptures.forEach { objects.addChildNode($0) } }
    }

    private func pose() {
        guard let intent else { return }
        let t = staticPose ? 0 : elapsed
        let wave = Float(sin(t * .pi / 3.4))
        let otherWave = Float(sin(t * .pi / 3.4 + 1.2))
        let floatAmount: Float = staticPose ? 0 : 0.095
        let turn: Float = staticPose ? 0 : 0.15
        let join = Float(acceptance)
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        lightRig.eulerAngles.y = staticPose ? 0 : Float(sin(t * .pi / 5.8)) * 0.12
        switch intent {
        case .business:
            sculptures[0].position = SCNVector3(-1.12 + 0.17 * join, 0.36 + wave * floatAmount, -0.12)
            sculptures[0].eulerAngles = SCNVector3(0.04, -0.22 + wave * turn, 0.11 - join * 0.04)
            sculptures[1].position = SCNVector3(1.16 - 0.17 * join, -0.34 + otherWave * floatAmount, 0.28)
            sculptures[1].eulerAngles = SCNVector3(-0.03, -0.20 - otherWave * turn, 0.08 - join * 0.03)
        case .social:
            sculptures[0].position = SCNVector3(-1.25 + 0.20 * join, 0.16 + wave * floatAmount, 0)
            sculptures[0].eulerAngles = SCNVector3(0.02, -0.25 + wave * turn, 0.10 - join * 0.07)
            sculptures[1].position = SCNVector3(1.23 - 0.20 * join, -0.16 + otherWave * floatAmount, 0.20)
            sculptures[1].eulerAngles = SCNVector3(-0.03, 0.25 - otherWave * turn, -0.10 + join * 0.07)
        case .dating:
            sculptures[0].position = SCNVector3(-0.98 + 0.15 * join, 0.06 + wave * floatAmount, 0)
            sculptures[0].eulerAngles = SCNVector3(-0.08, -0.24 + wave * turn, 0.12 - join * 0.05)
            sculptures[1].position = SCNVector3(0.98 - 0.15 * join, -0.10 + otherWave * floatAmount, 0.16)
            sculptures[1].eulerAngles = SCNVector3(0.04, 0.24 - otherWave * turn, -0.12 + join * 0.05)
        case .activity:
            let route = sculptures[0]
            route.position = SCNVector3(0, -0.10, 0)
            route.eulerAngles = SCNVector3(0.32, staticPose ? 0 : wave * 0.035, 0)
            // Their intervals remain separate; idle movement never implies a recipient response.
            let travel = staticPose ? 0 : Float(sin(t * .pi / 4.2)) * 0.085
            let locations: [Float] = [0.16 + join * 0.17 + travel, 0.83 - join * 0.17 - travel]
            for (index, marker) in markers.enumerated() {
                let position = InvitationStudioGeometry.trailPoint(locations[index])
                marker.position = SCNVector3(position.x, position.y + 0.40, position.z)
                marker.eulerAngles = SCNVector3(0, (index == 0 ? -0.35 : 0.35) + wave * turn, 0.12)
            }
        }
        SCNTransaction.commit()
    }
}

@MainActor
private enum InvitationStudioMaterials {
    static let chrome = material(UIColor(red: 0.86, green: 0.88, blue: 0.87, alpha: 1), metal: 0.97, roughness: 0.19)
    static let ivory = material(UIColor(red: 0.93, green: 0.90, blue: 0.83, alpha: 1), metal: 0.05, roughness: 0.30)
    static let rose = material(UIColor(red: 0.80, green: 0.17, blue: 0.38, alpha: 1), metal: 0.65, roughness: 0.23)
    static let graphite = material(UIColor(red: 0.075, green: 0.085, blue: 0.07, alpha: 1), metal: 0.84, roughness: 0.26)

    static func material(_ color: UIColor, metal: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.metalness.contents = NSNumber(value: Double(metal))
        material.roughness.contents = NSNumber(value: Double(roughness))
        material.isDoubleSided = true
        return material
    }

    static func luminous(_ color: UIColor) -> SCNMaterial {
        let result = material(color, metal: 0.4, roughness: 0.22)
        result.emission.contents = color
        result.emission.intensity = 0.15
        return result
    }

    /// Six authored softbox faces form a deterministic local reflection environment. They need no
    /// download, camera, location, texture loader or separately licensed photographic asset.
    static let environment: [UIImage] = (0..<6).map { face in
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
            UIColor(white: face == 3 ? 0.04 : 0.12, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            if face != 3 {
                context.cgContext.setShadow(offset: .zero, blur: 18, color: UIColor.white.cgColor)
                UIColor(white: face == 2 ? 1 : 0.92, alpha: 1).setFill()
                let rectangle = face == 2 ? CGRect(x: 25, y: 24, width: 205, height: 160)
                    : CGRect(x: face % 2 == 0 ? 28 : 150, y: 16, width: 50, height: 216)
                UIBezierPath(roundedRect: rectangle, cornerRadius: 12).fill()
                context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor(white: 0.35, alpha: 1).setFill()
                context.fill(CGRect(x: 10, y: 210, width: 235, height: 18))
            }
        }
    }
}

@MainActor
private enum InvitationStudioGeometry {
    static func card(name: String, corner: Bool) -> SCNNode {
        let group = SCNNode()
        let body = SCNBox(width: 2.40, height: 1.56, length: 0.20, chamferRadius: 0.085)
        body.chamferSegmentCount = 6
        body.firstMaterial = InvitationStudioMaterials.chrome
        group.addChildNode(SCNNode(geometry: body))
        let face = SCNPlane(width: 2.26, height: 1.42)
        face.cornerRadius = 0.055
        let paper = SCNMaterial()
        paper.lightingModel = .constant
        paper.diffuse.contents = cardPrint(name: name, corner: corner)
        paper.isDoubleSided = true
        face.firstMaterial = paper
        let surface = SCNNode(geometry: face)
        surface.position.z = 0.105
        group.addChildNode(surface)
        return group
    }

    private static func cardPrint(name: String, corner: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 768, height: 480), format: format).image { context in
            UIColor(red: 0.97, green: 0.95, blue: 0.89, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 768, height: 480))
            if !name.isEmpty {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byTruncatingTail
                (name as NSString).draw(in: CGRect(x: 72, y: 170, width: 620, height: 100), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 72, weight: .medium),
                    .foregroundColor: UIColor(white: 0.07, alpha: 1), .paragraphStyle: paragraph,
                ])
                UIColor(white: 0.12, alpha: 1).setFill()
                context.fill(CGRect(x: 76, y: 298, width: 86, height: 4))
            }
            UIColor(red: 1, green: 0.79, blue: 0.10, alpha: 1).setFill()
            if corner {
                let triangle = UIBezierPath()
                triangle.move(to: CGPoint(x: 650, y: 0))
                triangle.addLine(to: CGPoint(x: 768, y: 0))
                triangle.addLine(to: CGPoint(x: 768, y: 118))
                triangle.close()
                triangle.fill()
            } else {
                UIBezierPath(roundedRect: CGRect(x: 635, y: 390, width: 60, height: 12), cornerRadius: 6).fill()
            }
        }
    }

    static func bubble() -> SCNNode {
        let path = UIBezierPath()
        // UIKit's 0.6-point default is coarse relative to a two-unit scene-space object.
        path.flatness = 0.003
        path.move(to: CGPoint(x: -0.83, y: -0.65))
        path.addLine(to: CGPoint(x: -0.98, y: -1.03))
        path.addQuadCurve(to: CGPoint(x: -0.41, y: -0.65), controlPoint: CGPoint(x: -0.69, y: -0.91))
        path.addLine(to: CGPoint(x: 0.62, y: -0.65))
        path.addQuadCurve(to: CGPoint(x: 0.98, y: -0.29), controlPoint: CGPoint(x: 0.98, y: -0.65))
        path.addLine(to: CGPoint(x: 0.98, y: 0.51))
        path.addQuadCurve(to: CGPoint(x: 0.62, y: 0.87), controlPoint: CGPoint(x: 0.98, y: 0.87))
        path.addLine(to: CGPoint(x: -0.62, y: 0.87))
        path.addQuadCurve(to: CGPoint(x: -0.98, y: 0.51), controlPoint: CGPoint(x: -0.98, y: 0.87))
        path.addLine(to: CGPoint(x: -0.98, y: -0.32))
        path.addQuadCurve(to: CGPoint(x: -0.83, y: -0.65), controlPoint: CGPoint(x: -0.98, y: -0.55))
        path.close()
        let group = SCNNode()
        let shell = slab(path, depth: 0.24, bevel: 0.08, material: InvitationStudioMaterials.chrome)
        group.addChildNode(shell)
        let edge = slab(path, depth: 0.04, bevel: 0.035,
                        material: InvitationStudioMaterials.luminous(UIColor(red: 0, green: 0.84, blue: 0.96, alpha: 1)))
        edge.scale = SCNVector3(0.965, 0.965, 1)
        edge.position.z = 0.13
        group.addChildNode(edge)
        let face = slab(path, depth: 0.035, bevel: 0.025, material: InvitationStudioMaterials.ivory)
        face.scale = SCNVector3(0.91, 0.91, 1)
        face.position.z = 0.165
        group.addChildNode(face)
        return group
    }

    private static func slab(_ path: UIBezierPath, depth: CGFloat, bevel: CGFloat, material: SCNMaterial) -> SCNNode {
        let shape = SCNShape(path: path, extrusionDepth: depth)
        shape.chamferRadius = min(bevel, depth * 0.45)
        shape.chamferMode = .both
        shape.firstMaterial = material
        return SCNNode(geometry: shape)
    }

    /// Closed, curved petal shells with a rose inset; unlike a torus/ring, every cross-section is solid.
    static func petal() -> SCNNode {
        let group = SCNNode()
        let front = surface(rows: 80, columns: 24, material: InvitationStudioMaterials.chrome) { u, v in
            petalPoint(u, v * 2 - 1, front: true)
        }
        let back = surface(rows: 80, columns: 24, material: InvitationStudioMaterials.chrome) { u, v in
            petalPoint(u, 1 - v * 2, front: false)
        }
        group.addChildNode(front)
        group.addChildNode(back)
        for edge in [-1.0 as Float, 1.0] {
            group.addChildNode(surface(rows: 80, columns: 6, material: InvitationStudioMaterials.chrome) { u, v in
                let a = petalPoint(u, edge, front: false)
                let b = petalPoint(u, edge, front: true)
                return a + (b - a) * v
            })
        }
        let rose = surface(rows: 80, columns: 24, material: InvitationStudioMaterials.rose) { u, v in
            var point = petalPoint(0.025 + u * 0.95, (v * 2 - 1) * 0.81, front: true)
            point.z += 0.009
            return point
        }
        group.addChildNode(rose)
        return group
    }

    private static func petalPoint(_ u: Float, _ v: Float, front: Bool) -> SIMD3<Float> {
        let arc = max(0, sin(.pi * u))
        let width = 0.62 * pow(arc, 0.72)
        let center = 0.34 * sin(2 * .pi * u) - 0.38 * arc + 0.40 * (1 - u)
        let twist = 0.34 * sin(2 * .pi * u) + 0.22 * arc
        let thickness = 0.08 * arc
        let bowl = 0.21 * (1 - v * v) * arc
        return SIMD3(center + width * v, -1.22 + 2.53 * u,
                     twist + v * 0.22 * arc + (front ? thickness + bowl : -thickness + bowl * 0.35))
    }

    static func trailPoint(_ t: Float) -> SIMD3<Float> {
        SIMD3(-2.0 + 4.0 * t + 1.15 * sin(2 * .pi * t), 0.03 + 0.08 * sin(.pi * t), 2.0 - 4.0 * t)
    }

    private static func trailSide(_ t: Float) -> SIMD3<Float> {
        let tangent = SIMD3<Float>(4.0 + 2 * .pi * 1.15 * cos(2 * .pi * t), 0, -4.0)
        return simd_normalize(simd_cross(tangent, SIMD3(0, 1, 0)))
    }

    static func trail() -> SCNNode {
        let group = SCNNode()
        let deck = surface(rows: 120, columns: 12, material: InvitationStudioMaterials.graphite) { u, v in
            trailPoint(u) + trailSide(u) * ((v * 2 - 1) * 0.34)
        }
        group.addChildNode(deck)
        for side in [-1.0 as Float, 1.0] {
            let wall = surface(rows: 120, columns: 8, material: InvitationStudioMaterials.chrome) { u, v in
                var point = trailPoint(u) + trailSide(u) * (side * (0.32 + 0.02 * sin(v * .pi)))
                point.y -= v * 0.22
                return point
            }
            group.addChildNode(wall)
            let edge = tube(samples: 120, radius: 0.024,
                            material: InvitationStudioMaterials.luminous(UIColor(red: 0.47, green: 1, blue: 0.15, alpha: 1))) { u in
                trailPoint(u) + trailSide(u) * (side * 0.32) + SIMD3(0, 0.025, 0)
            }
            group.addChildNode(edge)
        }
        // Semicircular end caps continue the same deck, chrome wall and thin lime rim.
        // There are no square road-cut ends or disconnected route lines.
        for t in [0.0 as Float, 1.0] {
            let center = trailPoint(t)
            let side = trailSide(t)
            let tangent = simd_normalize(SIMD3<Float>(4.0 + 2 * .pi * 1.15 * cos(2 * .pi * t), 0, -4.0))
            let outward = tangent * (t == 0 ? -1 : 1)
            func edge(_ angle: Float) -> SIMD3<Float> {
                center + 0.34 * (side * cos(angle) + outward * sin(angle))
            }
            group.addChildNode(surface(rows: 8, columns: 40, material: InvitationStudioMaterials.graphite) { u, v in
                center + (edge(v * .pi) - center) * u
            })
            group.addChildNode(surface(rows: 40, columns: 8, material: InvitationStudioMaterials.chrome) { u, v in
                edge(u * .pi) + SIMD3(0, -v * 0.22, 0)
            })
            group.addChildNode(tube(samples: 40, radius: 0.024,
                material: InvitationStudioMaterials.luminous(UIColor(red: 0.47, green: 1, blue: 0.15, alpha: 1))) { u in
                edge(u * .pi) + SIMD3(0, 0.025, 0)
            })
        }
        return group
    }

    static func marker() -> SCNNode {
        let group = SCNNode()
        let rim = SCNCylinder(radius: 0.37, height: 0.105)
        rim.radialSegmentCount = 64
        rim.firstMaterial = InvitationStudioMaterials.chrome
        let body = SCNNode(geometry: rim)
        body.eulerAngles.x = .pi / 2
        group.addChildNode(body)
        let ring = SCNTorus(ringRadius: 0.345, pipeRadius: 0.019)
        ring.ringSegmentCount = 64
        ring.pipeSegmentCount = 12
        ring.firstMaterial = InvitationStudioMaterials.luminous(UIColor(red: 0.47, green: 1, blue: 0.15, alpha: 1))
        let edge = SCNNode(geometry: ring)
        edge.eulerAngles.x = .pi / 2
        edge.position.z = 0.058
        group.addChildNode(edge)
        let face = SCNSphere(radius: 0.325)
        face.segmentCount = 48
        face.firstMaterial = InvitationStudioMaterials.material(
            UIColor(red: 0.76, green: 0.79, blue: 0.73, alpha: 1), metal: 0.55, roughness: 0.24)
        let pearl = SCNNode(geometry: face)
        pearl.scale.z = 0.13
        pearl.position.z = 0.062
        group.addChildNode(pearl)
        return group
    }

    static func glow(color: UIColor) -> SCNNode {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
            let colors = [color.withAlphaComponent(0.16).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 128, y: 128), startRadius: 0,
                    endCenter: CGPoint(x: 128, y: 128), endRadius: 128, options: [])
            }
        }
        let plane = SCNPlane(width: 5.0, height: 3)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = image
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        plane.firstMaterial = material
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2
        node.renderingOrder = 1
        return node
    }

    /// Parametric surfaces carry explicit smooth normals. No triangulation ridges, flattened artwork,
    /// raster animation frames or network-loaded meshes are involved.
    private static func surface(rows: Int, columns: Int, material: SCNMaterial,
                                point: (Float, Float) -> SIMD3<Float>) -> SCNNode {
        var vertices = [SCNVector3](), normals = [SCNVector3](), uv = [CGPoint](), indices = [UInt32]()
        for row in 0...rows {
            let u = Float(row) / Float(rows)
            for column in 0...columns {
                let v = Float(column) / Float(columns)
                let p = point(u, v)
                let du = point(min(1, u + 0.001), v) - point(max(0, u - 0.001), v)
                let dv = point(u, min(1, v + 0.001)) - point(u, max(0, v - 0.001))
                // Normalize the finite-difference tangents before crossing them. Their raw
                // magnitudes include the 0.002 sample interval: testing that tiny raw cross against
                // a world-space epsilon would incorrectly flatten valid curved surfaces.
                let validTangents = simd_length_squared(du) > 1e-14 && simd_length_squared(dv) > 1e-14
                let cross = validTangents ? simd_cross(simd_normalize(dv), simd_normalize(du)) : SIMD3<Float>.zero
                let normal = simd_length_squared(cross) > 1e-12 ? simd_normalize(cross) : SIMD3<Float>(0, 0, 1)
                vertices.append(SCNVector3(p.x, p.y, p.z))
                normals.append(SCNVector3(normal.x, normal.y, normal.z))
                uv.append(CGPoint(x: CGFloat(v), y: CGFloat(u)))
                if row < rows && column < columns {
                    let a = UInt32(row * (columns + 1) + column), b = a + UInt32(columns + 1)
                    indices += [a, a + 1, b, a + 1, b + 1, b]
                }
            }
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals),
                                             SCNGeometrySource(textureCoordinates: uv)],
                                   elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        geometry.firstMaterial = material
        return SCNNode(geometry: geometry)
    }

    private static func tube(samples: Int, radius: Float, material: SCNMaterial,
                             center: (Float) -> SIMD3<Float>) -> SCNNode {
        surface(rows: samples, columns: 12, material: material) { u, v in
            let tangent = simd_normalize(center(min(1, u + 0.001)) - center(max(0, u - 0.001)))
            let side = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 1, 0)))
            let up = simd_normalize(simd_cross(side, tangent))
            let theta = v * 2 * .pi
            return center(u) + radius * (side * cos(theta) + up * sin(theta))
        }
    }
}
