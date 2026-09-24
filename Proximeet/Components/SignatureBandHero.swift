import SwiftUI
import RealityKit
import UIKit
import Combine
import ProximeetDomain

/// The same editable mesh in Band, Signal and Ready. Selection belongs to DemoSession;
/// this renderer never delays or owns a product-state transition.
struct SignatureBandHero: View {
    let intent: BandIntent
    var signal: ApproachSignal?
    var height: CGFloat = 220
    var interactive = true
    @Adaptive private var adaptive
    @State private var renderState = SignatureRenderState.loading

    var body: some View {
        ZStack(alignment: .bottom) {
            SignatureBandView(
                intent: intent,
                signal: signal,
                reduceMotion: adaptive.reduceMotion || adaptive.voiceOverRunning,
                interactive: interactive && !adaptive.voiceOverRunning,
                renderState: $renderState
            )
            .accessibilityHidden(true)

            if renderState == .failed {
                VStack(spacing: 8) {
                    Image(systemName: "wristwatch").font(.largeTitle)
                    Text("3D preview unavailable")
                        .font(.caption)
                    Text("Your choices still work below.")
                        .font(.caption2)
                }
                .foregroundStyle(Palette.quietText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if renderState == .loading {
                ProgressView().tint(intent.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: height)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(intent.title) band\(signal.map { ", \($0.title) plate attached" } ?? "")"))
        .accessibilityValue(Text(renderState.rawValue))
        .accessibilityIdentifier("signature.hero")
    }
}

private enum SignatureRenderState: String {
    case loading = "Loading 3D preview"
    case ready = "3D model ready"
    case failed = "3D preview unavailable"
}

private struct SignatureBandView: UIViewRepresentable {
    let intent: BandIntent
    let signal: ApproachSignal?
    let reduceMotion: Bool
    let interactive: Bool
    @Binding var renderState: SignatureRenderState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(Palette.carbon))
        view.renderOptions.insert(.disableMotionBlur)
        view.renderOptions.insert(.disableDepthOfField)
        view.isAccessibilityElement = false
        context.coordinator.attach(to: view) { state in
            renderState = state
        }
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.update(intent: intent, signal: signal, reduceMotion: reduceMotion, interactive: interactive)
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.cancel()
        view.scene.anchors.removeAll()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var view: ARView?
        private let anchor = AnchorEntity(world: .zero)
        private let turntable = Entity()
        private var asset: Entity?
        private var plate: Entity?
        private var plateRest = Transform()
        private var glyph: ModelEntity?
        private var load: AnyCancellable?
        private var studioLoad: AnyCancellable?
        private var plateAnimation: AnimationPlaybackController?
        private var rotationAnimation: AnimationPlaybackController?
        private var stateChanged: ((SignatureRenderState) -> Void)?
        private var lastIntent: BandIntent?
        private var lastSignal: ApproachSignal?
        private var currentIntent: BandIntent = .social
        private var currentSignal: ApproachSignal?
        private var reducesMotion = false
        private var canRotate = true
        private var yaw: Float = 0
        private var dragStart: Float = 0
        private var textureCache: [ApproachSignal: TextureResource] = [:]

        func attach(to view: ARView, onState: @escaping (SignatureRenderState) -> Void) {
            self.view = view
            stateChanged = onState
            view.scene.addAnchor(anchor)
            anchor.addChild(turntable)

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 24
            camera.camera.near = 0.001
            camera.camera.far = 2
            camera.look(at: [0, 0.013, 0], from: [0.020, 0.060, 0.140], relativeTo: nil)
            anchor.addChild(camera)

            // The baked studio environment supplies broad metal reflections. Directional
            // lights keep the weave readable while that optional resource is loading.
            addLight(position: [-0.12, 0.18, 0.14], intensity: 1800, color: .white)
            addLight(position: [0.12, 0.08, -0.08], intensity: 900, color: UIColor(red: 0.72, green: 0.84, blue: 1, alpha: 1))
            studioLoad = EnvironmentResource.loadAsync(named: "SignatureStudio")
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Signature studio environment failed: \(error.localizedDescription)")
                    }
                }, receiveValue: { [weak view] resource in
                    view?.environment.lighting.resource = resource
                    view?.environment.lighting.intensityExponent = 0
                })

            let pan = UIPanGestureRecognizer(target: self, action: #selector(rotate(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            view.addGestureRecognizer(pan)

            guard let url = Bundle.main.url(forResource: "ProximeetSignature", withExtension: "usdz") else {
                report(.failed)
                return
            }
            load = Entity.loadAsync(contentsOf: url)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Signature asset load failed: \(error.localizedDescription)")
                        self?.report(.failed)
                    }
                }, receiveValue: { [weak self] model in
                    self?.install(model)
                })
        }

        private func addLight(position: SIMD3<Float>, intensity: Float, color: UIColor) {
            let light = DirectionalLight()
            light.light.intensity = intensity
            light.light.color = color
            light.look(at: [0, 0.013, 0], from: position, relativeTo: nil)
            anchor.addChild(light)
        }

        private func install(_ model: Entity) {
            guard model.findEntity(named: "Band_Core") != nil,
                  let mount = model.findEntity(named: "Plate_Root") else {
                print("Signature asset is missing its named band or plate root.")
                report(.failed)
                return
            }
            asset = model
            plate = mount
            plateRest = mount.transform
            turntable.addChild(model)
            applyIntent()
            applySignal(animated: false)
            report(.ready)
        }

        func update(intent: BandIntent, signal: ApproachSignal?, reduceMotion: Bool, interactive: Bool) {
            let motionChanged = reducesMotion != reduceMotion
            currentIntent = intent
            currentSignal = signal
            reducesMotion = reduceMotion
            canRotate = interactive
            if asset != nil {
                if lastIntent != intent { applyIntent() }
                if lastSignal != signal || motionChanged { applySignal(animated: !reduceMotion && !motionChanged) }
            }
            if reduceMotion {
                rotationAnimation?.stop()
                turntable.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                yaw = 0
            }
        }

        private func applyIntent() {
            guard let asset else { return }
            tintFabric(in: asset, color: UIColor(currentIntent.tint))
            lastIntent = currentIntent
        }

        private func tintFabric(in entity: Entity, color: UIColor) {
            if entity.name == "Band_Core" || entity.name.hasPrefix("Band_Edge_") {
                recolor(entity, color: color)
                return
            }
            for child in entity.children { tintFabric(in: child, color: color) }
        }

        private func recolor(_ entity: Entity, color: UIColor) {
            if var model = entity.components[ModelComponent.self] {
                model.materials = model.materials.map { source in
                    guard var material = source as? PhysicallyBasedMaterial else { return source }
                    // Preserve the authored fabric normal map, texture and roughness.
                    material.baseColor.tint = color
                    return material
                }
                entity.components.set(model)
            }
            for child in entity.children { recolor(child, color: color) }
        }

        private func applySignal(animated: Bool) {
            plateAnimation?.stop()
            glyph?.removeFromParent()
            glyph = nil
            lastSignal = currentSignal
            guard let plate else { return }
            plate.transform = plateRest
            guard let signal = currentSignal else {
                plate.isEnabled = false
                return
            }
            plate.isEnabled = true
            attachGlyph(signal, to: plate)
            guard animated, !reducesMotion else { return }

            // The UI already shows the new choice. This small physical seating motion is
            // entirely decorative; a rapid second selection cancels this presentation.
            var arrival = plateRest
            arrival.translation += [0.002, 0.009, 0.022]
            arrival.rotation = simd_quatf(angle: -.pi / 12, axis: [1, 0, 0]) * plateRest.rotation
            plate.transform = arrival
            plateAnimation = plate.move(to: plateRest, relativeTo: plate.parent, duration: 0.51, timingFunction: .easeInOut)
        }

        private func attachGlyph(_ signal: ApproachSignal, to plate: Entity) {
            do {
                let texture: TextureResource
                if let cached = textureCache[signal] {
                    texture = cached
                } else {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 384), format: format)
                    let image = renderer.image { _ in
                        let symbol = UIImage(systemName: signal.symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 240, weight: .medium))?
                            .withTintColor(UIColor(white: 0.035, alpha: 1), renderingMode: .alwaysOriginal)
                        let source = symbol?.size ?? CGSize(width: 1, height: 1)
                        let scale = min(340 / source.width, 270 / source.height)
                        let size = CGSize(width: source.width * scale, height: source.height * scale)
                        symbol?.draw(in: CGRect(x: (512 - size.width) / 2, y: (384 - size.height) / 2, width: size.width, height: size.height))
                    }
                    guard let cgImage = image.cgImage else { return }
                    texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
                    textureCache[signal] = texture
                }
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: .white, texture: .init(texture))
                material.roughness = .init(floatLiteral: 0.45)
                material.metallic = .init(floatLiteral: 0.35)
                material.opacityThreshold = 0.15
                let mark = ModelEntity(mesh: .generatePlane(width: 0.018, height: 0.014), materials: [material])
                mark.name = "NativeSignalGlyph"
                mark.position = [0, 0, 0.00156]
                plate.addChild(mark)
                glyph = mark
            } catch {
                print("Signal glyph texture failed: \(error.localizedDescription)")
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard canRotate, !reducesMotion, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }

        @objc private func rotate(_ gesture: UIPanGestureRecognizer) {
            guard canRotate, !reducesMotion else { return }
            switch gesture.state {
            case .began:
                rotationAnimation?.stop()
                dragStart = yaw
            case .changed:
                yaw = min(0.55, max(-0.55, dragStart + Float(gesture.translation(in: view).x) * 0.004))
                turntable.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            case .ended, .cancelled, .failed:
                var rest = turntable.transform
                rest.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
                rotationAnimation = turntable.move(to: rest, relativeTo: anchor, duration: 0.5, timingFunction: .easeOut)
                yaw = 0
            default: break
            }
        }

        private func report(_ state: SignatureRenderState) {
            DispatchQueue.main.async { [weak self] in self?.stateChanged?(state) }
        }

        func cancel() {
            plateAnimation?.stop()
            rotationAnimation?.stop()
            load?.cancel()
            studioLoad?.cancel()
            stateChanged = nil
        }
    }
}
