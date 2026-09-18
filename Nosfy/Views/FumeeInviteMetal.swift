import SwiftUI
import MetalKit

/// La même fumée que `panacheInvite`, dans une petite surface indépendante.
/// Aucun état SwiftUI n'est écrit par image. À 1,5 pixel/point, le panache doux
/// occupe 315 × 300 pixels, contre 630 × 600 sur l'iPhone à échelle 3.
/// `-fumeeSwiftUI` garde le rendu précédent pour comparer ; `-fumeeNative`
/// conserve ici la résolution native pour isoler le changement de moteur.
struct FumeeInviteMetal: UIViewRepresentable {
    var dort: Bool

    final class Renderer: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let pipeline: MTLRenderPipelineState
        // Ne jamais attendre le GPU sur le fil principal : si les deux images
        // précédentes sont encore en vol, ce décor peut sauter une image.
        private let places = DispatchSemaphore(value: 2)
        private let rendu = DispatchQueue(label: "fr.kathryn.woop.fumee", qos: .userInteractive)

        init?(device: MTLDevice) {
            guard let queue = device.makeCommandQueue(),
                  let library = device.makeDefaultLibrary(),
                  let vertex = library.makeFunction(name: "panacheSommet"),
                  let fragment = library.makeFunction(name: "panacheFragment") else {
                return nil
            }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
                return nil
            }
            self.device = device
            self.queue = queue
            self.pipeline = pipeline
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard !view.isPaused, let layer = view.layer as? CAMetalLayer,
                  places.wait(timeout: .now()) == .success else { return }
            let t = Date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 900)
            let souffle = 0.52 + 0.26 * sin(t * 2 * .pi / 7.3)
                + 0.14 * sin(t * 2 * .pi / 11.7 + 1.7)
            // xy = taille du drawable, z = temps, w = souffle. Les coordonnées
            // de dessin restent celles de la vue d'origine (210 × 200 points).
            let uniforms = SIMD4<Float>(Float(view.drawableSize.width),
                                        Float(view.drawableSize.height),
                                        Float(t), Float(max(souffle, 0)))
            // nextDrawable peut attendre jusqu'à une seconde quand le GPU est
            // en retard. Même cette acquisition est donc HORS du fil de l'UI.
            // Aucun accès UIView dans la queue ; seulement la couche Metal et
            // les paramètres copiés ici. Deux images au plus, jamais une dette.
            rendu.async { [self] in
                autoreleasepool { dessiner(layer: layer, uniforms: uniforms) }
            }
            SondeVol.shared.tic(4)
        }

        private func dessiner(layer: CAMetalLayer, uniforms: SIMD4<Float>) {
            guard let drawable = layer.nextDrawable(),
                  let buffer = queue.makeCommandBuffer() else {
                places.signal()
                return
            }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else {
                places.signal()
                return
            }
            var uniforms = uniforms
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            let places = self.places
            buffer.addCompletedHandler { _ in places.signal() }
            buffer.present(drawable)
            buffer.commit()
        }
    }

    // Compilation une fois, jamais dans draw(). Si Metal n'est pas disponible,
    // l'hôte choisit l'ancien shader SwiftUI au lieu d'afficher du vide.
    static let renderer: Renderer? = MTLCreateSystemDefaultDevice().flatMap(Renderer.init)
    static var disponible: Bool { renderer != nil }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: Self.renderer?.device)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.colorPixelFormat = .bgra8Unorm
        (view.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.autoResizeDrawable = false
        view.preferredFramesPerSecond = 20
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = true
        view.delegate = Self.renderer
        // Une surface indisponible ne doit pas immobiliser la navigation.
        (view.layer as? CAMetalLayer)?.allowsNextDrawableTimeout = true
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        let scale = CommandLine.arguments.contains("-fumeeNative")
            ? view.traitCollection.displayScale : 1.5
        let size = CGSize(width: ceil(210 * scale), height: ceil(200 * scale))
        if view.drawableSize != size { view.drawableSize = size }
        view.isPaused = dort
    }

    static func dismantleUIView(_ view: MTKView, coordinator: ()) {
        view.isPaused = true
        view.delegate = nil
        view.releaseDrawables()
    }
}
