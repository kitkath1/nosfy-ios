import SwiftUI
import AVFoundation
import MetalKit
import CoreVideo

/// Banc opt-in de FondDeuxCalques à e = 0 : deux décodeurs, une seule surface
/// opaque, aucun AVPlayerLayer. Le scrim demeure chez l'hôte SwiftUI.
/// Ce prototype ne reproduit ni la chute, ni les rotations, ni la lueur du départ.
struct FondVideoMetal: UIViewRepresentable {
    var pilule: Double = 1
    var arret: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    private static let ressources = Ressources()
    static var disponible: Bool { ressources != nil }

    final class Ressources {
        let device: MTLDevice
        let pipeline: MTLRenderPipelineState
        let braise: MTLTexture
        let pilule: MTLTexture
        let poseBraise: UIImage
        let posePilule: UIImage

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let library = device.makeDefaultLibrary(),
                  let vertex = library.makeFunction(name: "fondVideoSommet"),
                  let fragment = library.makeFunction(name: "fondVideoFragment"),
                  let poseBraise = UIImage(named: "home-fond-flamme-poster"),
                  let posePilule = UIImage(named: "home-fond-pilule-poster"),
                  let cgBraise = poseBraise.cgImage, let cgPilule = posePilule.cgImage,
                  AssetsVideo.asset("home-fond-flamme") != nil,
                  AssetsVideo.asset("home-fond-pilule") != nil else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            let loader = MTKTextureLoader(device: device)
            let options: [MTKTextureLoader.Option: Any] = [
                .SRGB: false, .origin: MTKTextureLoader.Origin.topLeft.rawValue
            ]
            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor),
                  let braise = try? loader.newTexture(cgImage: cgBraise, options: options),
                  let pilule = try? loader.newTexture(cgImage: cgPilule, options: options)
            else { return nil }
            self.device = device
            self.pipeline = pipeline
            self.braise = braise
            self.pilule = pilule
            self.poseBraise = poseBraise
            self.posePilule = posePilule
        }
    }

    /// Le buffer ET son enveloppe CoreVideo restent vivants jusqu'à la fin GPU.
    final class ImageVideo {
        let buffer: CVPixelBuffer
        let enveloppe: CVMetalTexture
        let texture: MTLTexture
        let temps: CMTime

        init?(buffer: CVPixelBuffer, temps: CMTime, cache: CVMetalTextureCache) {
            var enveloppe: CVMetalTexture?
            let resultat = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, cache, buffer, nil, .bgra8Unorm,
                CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &enveloppe)
            guard resultat == kCVReturnSuccess, let enveloppe,
                  let texture = CVMetalTextureGetTexture(enveloppe) else { return nil }
            self.buffer = buffer
            self.enveloppe = enveloppe
            self.texture = texture
            self.temps = temps
        }
    }

    /// Toutes les opérations de ce flux vivent sur la queue de rendu, y compris
    /// l'installation des outputs des répliques du looper (ils ne sont pas copiés).
    final class Flux {
        let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var observations: [NSKeyValueObservation] = []
        private var outputs: [ObjectIdentifier: (AVPlayerItem, AVPlayerItemVideoOutput)] = [:]
        private let queue: DispatchQueue
        private var termine = false
        private(set) var image: ImageVideo?
        private(set) var imagesRecues: UInt64 = 0

        init?(nom: String, queue: DispatchQueue) {
            guard let item = AssetsVideo.item(nom) else { return nil }
            self.queue = queue
            player.isMuted = true
            player.automaticallyWaitsToMinimizeStalling = false
            let looper = AVPlayerLooper(player: player, templateItem: item)
            self.looper = looper
            observations = [
                looper.observe(\.loopingPlayerItems, options: [.new]) { [weak self] _, _ in
                    self?.actualiserDepuisObservation()
                },
                player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
                    self?.actualiserDepuisObservation()
                }
            ]
            actualiserOutputs()
        }

        private func actualiserDepuisObservation() {
            queue.async { [weak self] in self?.actualiserOutputs() }
        }

        private func actualiserOutputs() {
            guard !termine else { return }
            var items = looper?.loopingPlayerItems ?? []
            if let current = player.currentItem { items.append(current) }
            let identites = Set(items.map(ObjectIdentifier.init))
            for cle in Array(outputs.keys) where !identites.contains(cle) {
                if let (item, output) = outputs.removeValue(forKey: cle) { item.remove(output) }
            }
            for item in items where outputs[ObjectIdentifier(item)] == nil {
                let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferMetalCompatibilityKey as String: true
                ])
                output.suppressesPlayerRendering = true
                item.add(output)
                outputs[ObjectIdentifier(item)] = (item, output)
            }
        }

        func pause(_ pause: Bool) {
            guard !termine else { return }
            if pause { player.pause() } else { player.play() }
        }

        func lire(hostTime: CFTimeInterval, cache: CVMetalTextureCache) {
            guard !termine, let item = player.currentItem else { return }
            // Le changement d'item peut précéder son observation de quelques µs.
            if outputs[ObjectIdentifier(item)] == nil { actualiserOutputs() }
            guard let output = outputs[ObjectIdentifier(item)]?.1 else { return }
            let temps = output.itemTime(forHostTime: hostTime)
            guard temps.isValid, output.hasNewPixelBuffer(forItemTime: temps) else { return }
            var tempsImage = CMTime.invalid
            guard let buffer = output.copyPixelBuffer(forItemTime: temps,
                                                      itemTimeForDisplay: &tempsImage),
                  let nouvelle = ImageVideo(buffer: buffer, temps: tempsImage, cache: cache)
            else { return }
            image = nouvelle
            imagesRecues += 1
        }

        func terminer() {
            termine = true
            player.pause()
            observations.removeAll()
            looper?.disableLooping()
            looper = nil
            for (item, output) in outputs.values { item.remove(output) }
            outputs.removeAll()
            player.removeAllItems()
            image = nil
        }
    }

    struct Uniformes {
        // xy : taille logique de l'hôte, z : opacité d'entrée de la pilule.
        var hote: SIMD4<Float>
        var braise: SIMD4<Float>
        var pilule: SIMD4<Float>
    }

    final class Vue: MTKView {
        private let pose = UIImageView()
        private var poseVisible = true
        private var dernierePose: CGSize = .zero
        private var dernierePilule: Double = -1
        var entreePilule: Double = 1
        var ressources: Ressources?
        private var drawableFixe = false

        override init(frame: CGRect, device: MTLDevice?) {
            super.init(frame: frame, device: device)
            pose.isUserInteractionEnabled = false
            pose.contentMode = .scaleToFill
            addSubview(pose)
        }

        required init(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 0, bounds.height > 0 else { return }
            if !drawableFixe {
                // Une allocation au premier layout ; les hauteurs suivantes
                // changent les uniformes, jamais la taille de la surface GPU.
                let scale = traitCollection.displayScale
                drawableSize = CGSize(width: ceil(bounds.width * scale),
                                      height: ceil(bounds.height * scale))
                drawableFixe = true
            }
            pose.frame = bounds
            actualiserPose()
        }

        func actualiserPose() {
            guard poseVisible, bounds.width > 0, bounds.height > 0,
                  let ressources,
                  dernierePose != bounds.size || dernierePilule != entreePilule else { return }
            dernierePose = bounds.size
            dernierePilule = entreePilule
            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = traitCollection.displayScale
            format.preferredRange = .standard
            // Une seule image de secours : aucun filtre de composition UIKit.
            // Elle disparaît à la première présentation du drawable Metal.
            pose.image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { ctx in
                UIColor.black.setFill()
                ctx.fill(CGRect(origin: .zero, size: bounds.size))
                let braise = CGRect(x: (bounds.width - FondDeuxCalques.braL) / 2,
                                    y: bounds.height - FondDeuxCalques.braH,
                                    width: FondDeuxCalques.braL, height: FondDeuxCalques.braH)
                let pilule = CGRect(x: (bounds.width - FondDeuxCalques.pilL) / 2,
                                    y: FondDeuxCalques.pilTop,
                                    width: FondDeuxCalques.pilL, height: FondDeuxCalques.pilH)
                dessinerPose(ressources.poseBraise, dans: braise, contexte: ctx.cgContext,
                             mode: .normal, alpha: 1)
                dessinerPose(ressources.posePilule, dans: pilule, contexte: ctx.cgContext,
                             mode: .plusLighter, alpha: CGFloat(entreePilule))
            }
        }

        private func dessinerPose(_ image: UIImage, dans rect: CGRect, contexte: CGContext,
                                  mode: CGBlendMode, alpha: CGFloat) {
            let scale = max(rect.width / image.size.width, rect.height / image.size.height)
            let taille = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let cible = CGRect(x: rect.midX - taille.width / 2, y: rect.midY - taille.height / 2,
                               width: taille.width, height: taille.height)
            contexte.saveGState()
            contexte.clip(to: rect)
            image.draw(in: cible, blendMode: mode, alpha: alpha)
            contexte.restoreGState()
        }

        func retirerPose() {
            guard poseVisible else { return }
            poseVisible = false
            pose.removeFromSuperview()
            pose.image = nil
        }
    }

    final class Renderer: NSObject, MTKViewDelegate {
        private let ressources: Ressources
        private let commandes: MTLCommandQueue
        private let cache: CVMetalTextureCache
        private let rendu = DispatchQueue(label: "fr.kathryn.woop.fond-video-metal", qos: .userInteractive)
        private let places = DispatchSemaphore(value: 2)
        private let verrou = NSLock()
        private var termine = false
        private var pauseImmediate = true
        private var completions: UInt64 = 0
        private var dernierDiagnostic: CFTimeInterval = 0
        private var aSignaleDeuxVideos = false
        private var braise: Flux?
        private var pilule: Flux?
        private var enPause = true
        private var pauseDemandee: Bool?
        private var presentationDemandee = false
        weak var vue: Vue?

        init?(ressources: Ressources) {
            guard let commandes = ressources.device.makeCommandQueue() else { return nil }
            var cache: CVMetalTextureCache?
            guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, ressources.device,
                                            nil, &cache) == kCVReturnSuccess, let cache else { return nil }
            self.ressources = ressources
            self.commandes = commandes
            self.cache = cache
            super.init()
            rendu.async { [self] in
                braise = Flux(nom: "home-fond-flamme", queue: rendu)
                pilule = Flux(nom: "home-fond-pilule", queue: rendu)
            }
        }

        func pause(_ pause: Bool) {
            guard pauseDemandee != pause else { return }
            pauseDemandee = pause
            // Fermer immédiatement la porte, même si nextDrawable retient
            // actuellement la queue de rendu. Les lecteurs se règlent ensuite.
            verrou.lock()
            pauseImmediate = pause
            verrou.unlock()
            rendu.async { [self] in
                guard !estTermine else { return }
                enPause = pause
                braise?.pause(pause)
                pilule?.pause(pause)
            }
        }

        private var estTermine: Bool {
            verrou.lock(); defer { verrou.unlock() }
            return termine
        }

        private var renduInterrompu: Bool {
            verrou.lock(); defer { verrou.unlock() }
            return termine || pauseImmediate
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard !view.isPaused, view.bounds.width > 0, view.bounds.height > 0,
                  let vue = view as? Vue, let layer = view.layer as? CAMetalLayer,
                  !estTermine, places.wait(timeout: .now()) == .success else { return }
            let w = Float(view.bounds.width), h = Float(view.bounds.height)
            let bw = Float(FondDeuxCalques.braL), bh = Float(FondDeuxCalques.braH)
            let pw = Float(FondDeuxCalques.pilL), ph = Float(FondDeuxCalques.pilH)
            let uniformes = Uniformes(
                hote: SIMD4(w, h, Float(vue.entreePilule), 0),
                braise: SIMD4((w - bw) / 2, h - bh, bw, bh),
                pilule: SIMD4((w - pw) / 2, Float(FondDeuxCalques.pilTop), pw, ph))
            // Aucun UIView et aucune attente GPU dans la queue de l'interface.
            rendu.async { [self] in
                autoreleasepool { dessiner(layer: layer, uniformes: uniformes) }
            }
        }

        private func dessiner(layer: CAMetalLayer, uniformes: Uniformes) {
            guard !renduInterrompu, !enPause, let drawable = layer.nextDrawable(),
                  !renduInterrompu, let buffer = commandes.makeCommandBuffer() else {
                places.signal()
                return
            }
            let maintenant = CACurrentMediaTime()
            braise?.lire(hostTime: maintenant, cache: cache)
            pilule?.lire(hostTime: maintenant, cache: cache)
            let imageBraise = braise?.image, imagePilule = pilule?.image
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else {
                places.signal()
                return
            }
            var uniformes = uniformes
            encoder.setRenderPipelineState(ressources.pipeline)
            encoder.setFragmentBytes(&uniformes, length: MemoryLayout<Uniformes>.stride, index: 0)
            encoder.setFragmentTexture(imageBraise?.texture ?? ressources.braise, index: 0)
            encoder.setFragmentTexture(imagePilule?.texture ?? ressources.pilule, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            guard !renduInterrompu else {
                places.signal()
                return
            }
            if !presentationDemandee {
                presentationDemandee = true
                drawable.addPresentedHandler { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in self?.vue?.retirerPose() }
                }
            }
            let compteBraise = braise?.imagesRecues ?? 0
            let comptePilule = pilule?.imagesRecues ?? 0
            let pixels = "\(drawable.texture.width)x\(drawable.texture.height)"
            let places = self.places
            buffer.addCompletedHandler { [weak self, imageBraise, imagePilule] commande in
                // Capture explicite des CVPixelBuffer + CVMetalTexture, pas
                // seulement de leurs MTLTexture attachées à l'encodeur.
                withExtendedLifetime((imageBraise, imagePilule)) {
                    if commande.status == .completed {
                        self?.diagnostiquer(braise: imageBraise, pilule: imagePilule,
                                            compteBraise: compteBraise, comptePilule: comptePilule,
                                            pixels: pixels)
                    }
                }
                places.signal()
            }
            buffer.present(drawable)
            buffer.commit()
        }

        private func diagnostiquer(braise: ImageVideo?, pilule: ImageVideo?,
                                    compteBraise: UInt64, comptePilule: UInt64, pixels: String) {
            guard NavDiagnostic.actif else { return }
            let maintenant = CACurrentMediaTime()
            verrou.lock()
            completions += 1
            let deux = braise != nil && pilule != nil
            let premierDeux = deux && !aSignaleDeuxVideos
            guard !termine, premierDeux || maintenant - dernierDiagnostic >= 5 else {
                verrou.unlock()
                return
            }
            dernierDiagnostic = maintenant
            if deux { aSignaleDeuxVideos = true }
            let nombre = completions
            verrou.unlock()
            func detail(_ image: ImageVideo?) -> String {
                guard let image else { return "pose" }
                return "\(image.texture.width)x\(image.texture.height)@\(String(format: "%.3f", image.temps.seconds))"
            }
            let message = "gpuComplete=\(nombre);deuxVideos=\(deux);braise=\(detail(braise));b=\(compteBraise);pilule=\(detail(pilule));p=\(comptePilule);drawable=\(pixels);format=BGRA8;cadenceDemandee=24"
            // Pas de publication SwiftUI ni d'aller-retour UI par image.
            DispatchQueue.main.async {
                NavDiagnostic.noter("fond-metal", destination: message)
            }
        }

        func terminer() {
            verrou.lock()
            termine = true
            verrou.unlock()
            rendu.async { [self] in
                enPause = true
                braise?.terminer()
                pilule?.terminer()
                braise = nil
                pilule = nil
                CVMetalTextureCacheFlush(cache, 0)
            }
        }
    }

    func makeCoordinator() -> Renderer? { Self.ressources.flatMap(Renderer.init) }

    func makeUIView(context: Context) -> Vue {
        let view = Vue(frame: .zero, device: Self.ressources?.device)
        view.ressources = Self.ressources
        view.isOpaque = true
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.autoResizeDrawable = false
        view.preferredFramesPerSecond = 24
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = true
        (view.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        (view.layer as? CAMetalLayer)?.allowsNextDrawableTimeout = true
        view.delegate = context.coordinator
        context.coordinator?.vue = view
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: Vue, context: Context) {
        view.entreePilule = min(max(pilule, 0), 1)
        view.actualiserPose()
        let pause = arret || scenePhase != .active
        view.isPaused = pause || context.coordinator == nil
        context.coordinator?.pause(pause)
    }

    static func dismantleUIView(_ view: Vue, coordinator: Renderer?) {
        view.isPaused = true
        view.delegate = nil
        coordinator?.terminer()
        view.releaseDrawables()
    }
}
