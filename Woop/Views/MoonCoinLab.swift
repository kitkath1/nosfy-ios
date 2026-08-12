import SwiftUI
import UIKit

// MARK: - La pièce de lune, et son banc
//
// `-pieceLab` : la pièce seule sur du noir, en grand, tournable au doigt.
// `-pieceFreeze <rad>` fige le lacet (captures comparables d'un tour à
// l'autre — sans ça le fouettage compare deux angles différents et on
// « corrige » du bruit).
// `-coinRim <v>` / `-coinMoon <v>` : les deux curseurs de matière, réglables
// SANS RECOMPILER — un tour de fouettage tombe à trente secondes au lieu de
// dix minutes de build sur une machine chargée.

/// L'objet. Le geste est repris du monolithe (LogoLab) parce qu'il est déjà
/// juste : une FONCTION PURE DU TEMPS — glissement pendant la prise, puis
/// inertie amortie résolue analytiquement, puis retour doux au repos. Rien
/// ne s'accumule par image, donc rien ne dérive.
struct MoonCoinView: View {
    /// Rayon de la face, en points.
    var coinR: CGFloat = 26
    /// Le lacet est-il pris au doigt ? Faux dans le header : la pièce y est
    /// un BOUTON, et un glissement y volerait le défilement de la page.
    var draggable: Bool = true
    /// Lacet imposé (captures).
    var yawOverride: Float? = nil
    var idleLife: Float = 1
    /// LE MAT, 0 → 1. À 0 (partout ailleurs dans l'app) la pièce est en or et
    /// rien ne change. À 1, le MÉTAL SEUL passe à l'anthracite neutre et le
    /// croissant reste en néon : c'est la pièce de la page BRAVO.
    var matte: Float = 0
    /// UN SUPPLÉMENT D'HORLOGE, en secondes, ajouté à `t`. À 0 partout ailleurs
    /// (rien ne change). La page BRAVO s'en sert pendant qu'elle plonge sur la
    /// pièce : le croissant respire sur 5 s et son point chaud voyage en 3,5 s
    /// — sur un zoom de 0,7 s on n'en voyait qu'un cinquième, donc RIEN. En
    /// avançant l'horloge de la pièce à mesure que la caméra approche, le néon
    /// SCINTILLE pendant qu'on le regarde. C'est un décalage MONOTONE et
    /// continu, jamais un facteur : multiplier `t` (qui vaut des centaines)
    /// ferait sauter la phase d'un coup.
    var timeBoost: Double = 0
    var fps: Double = 30
    /// L'INTENSITÉ DU CROISSANT. 1 partout ailleurs. Le tube a un PLANCHER de
    /// 0,85 pt de large : sous 28 pt de rayon il cesse de rétrécir avec la
    /// pièce, donc plus la pièce est petite, plus le néon y est gros — à 10 pt
    /// il mange le métal et la pièce n'est plus qu'un disque orange. Sur une
    /// miniature, on le baisse.
    var reveal: Float = 1
    /// LE MAT. 0 = la pièce d'or du header et du trésor, inchangée. 1 = un
    /// galet d'anthracite neutre qui garde tous ses reflets, sa tranche et son
    /// épaisseur — le métal s'éteint, la lune reste allumée (le néon descend
    /// à 52 % avec lui, sinon le croissant domine une pièce noire).
    var matte: Float = 0
    /// Un toucher SANS glissement. Il vit ici, à côté du lacet, plutôt que
    /// dans un `Button` autour : deux reconnaisseurs empilés se disputent le
    /// doigt, et on perd soit la rotation soit l'ouverture. Ici la
    /// `DragGesture` a une distance minimale de 1 pt, donc un vrai tap ne la
    /// déclenche pas et tombe proprement sur le tap.
    var onTap: (() -> Void)? = nil

    /// Le débord de l'hôte. Le bloom large porte à ~0,9 rayon au-delà du
    /// métal, et le fondu d'hôte du shader en mange 12 de plus.
    static let hostScale: CGFloat = 3.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragging = false
    @State private var yawAtGrab: Float = 0
    @State private var yawLive: Float = 0
    @State private var releaseAt: Date = .distantPast
    @State private var releaseYaw: Float = 0
    @State private var releaseVel: Float = 0

    /// Radians par point glissé. Plus vif que le monolithe (0,0075) : la
    /// pièce est un petit objet léger, elle doit répondre au doigt, pas se
    /// laisser pousser.
    private static let radPerPoint: Float = 0.0125
    /// La butée. « De gauche à droite, pas plus » : au-delà de ~48° une pièce
    /// se referme en trait et le croissant devient illisible — la butée n'est
    /// pas une pudeur, c'est la limite de lecture du sujet.
    private static let yawLimit: Float = 0.84
    private static let damping: Float = 2.6
    private static let restDelay: Float = 1.6
    private static let restFall: Float = 2.4

    /// Les arguments de lancement arrivent en `NSNumber` : `as? Double`
    /// ÉCHOUE quand la valeur s'écrit sans décimale (`-coinRim 1`), et on
    /// repart alors sur la valeur par défaut sans le savoir — on croit avoir
    /// tourné un curseur qui n'a pas bougé. On passe donc par `NSNumber`.
    static func knob(_ key: String, _ fallback: Float) -> Float {
        (UserDefaults.standard.object(forKey: key) as? NSNumber)?.floatValue
            ?? fallback
    }

    private static let rimIn = knob("coinRim", 0.946)
    private static let moonFit = knob("coinMoon", 0.865)

    private func userYaw(at date: Date) -> Float {
        if let yawOverride { return yawOverride }
        if dragging { return yawLive }
        let age = Float(date.timeIntervalSince(releaseAt))
        guard age.isFinite, age >= 0, age < 3600 else { return 0 }
        var y = releaseYaw + releaseVel * (1 - exp(-Self.damping * age)) / Self.damping
        y *= exp(-max(age - Self.restDelay, 0) / Self.restFall)
        return max(-Self.yawLimit, min(Self.yawLimit, y))
    }

    var body: some View {
        let side = coinR * Self.hostScale
        TimelineView(.animation(minimumInterval: 1.0 / fps,
                                paused: reduceMotion && !dragging)) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900))
            let tilt = SkyMotion.shared.tilt
            Rectangle()
                .fill(.white)
                .frame(width: side, height: side)
                .colorEffect(ShaderLibrary.moonCoin(
                    .float2(Float(side), Float(side)),
                    .float(t + Float(timeBoost)),
                    .float2(Float(tilt.dx), Float(tilt.dy)),
                    .float(userYaw(at: tl.date)),
                    .float(Float(coinR)),
                    .float(reveal),
                    .float(reduceMotion ? 0 : idleLife),
                    .float3(MoonSDF.padding, MoonSDF.tightRange, MoonSDF.wideRange),
                    .float3(0.5, 0.485, 0.71),
                    .float4(Self.rimIn, Self.moonFit, matte, 0),
                    .image(MoonSDF.image)))
        }
        .frame(width: side, height: side)
        // La prise ne vaut que sur le MÉTAL, pas sur le halo : sinon la pièce
        // capte le doigt bien au-delà d'elle-même.
        .contentShape(Circle().inset(by: side / 2 - coinR * 1.06))
        .gesture(draggable ? drag : nil)
        .onTapGesture {
            guard onTap != nil else { return }
            // Vibration + tintement AVANT l'action : le retour physique doit
            // partir dans la même image que le doigt, pas après le travail
            // que le tap déclenche.
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.75)
            CoinChime.shared.chink()
            onTap?()
        }
        .accessibilityHidden(onTap == nil)
        .accessibilityLabel("Ton trésor")
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
        .accessibilityAction { onTap?() }
        .onAppear { if onTap != nil { CoinChime.shared.prepare() } }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if !dragging {
                    dragging = true
                    yawAtGrab = userYaw(at: .now)
                }
                yawLive = max(-Self.yawLimit,
                              min(Self.yawLimit,
                                  yawAtGrab + Float(v.translation.width) * Self.radPerPoint))
            }
            .onEnded { v in
                releaseYaw = yawLive
                // La vitesse de lâcher, en rad/s — `predictedEndTranslation`
                // porte l'élan que SwiftUI a mesuré.
                let fling = Float(v.predictedEndTranslation.width - v.translation.width)
                releaseVel = fling * Self.radPerPoint * 2.4
                releaseAt = .now
                dragging = false
            }
    }
}

// MARK: - Le banc

/// `-pieceLab` : la pièce en grand sur du noir. C'est là qu'on la fouette.
struct MoonCoinLab: View {
    /// `-pieceFreeze <rad>` : le lacet est imposé ET la vie au repos coupée.
    /// Sans couper le flottement, deux captures du même réglage diffèrent de
    /// ±3,3° et on « corrige » du bruit d'angle au lieu de la matière.
    private static let freeze: Float? =
        (UserDefaults.standard.object(forKey: "pieceFreeze") as? NSNumber)?
            .floatValue
    /// `-pieceSmall` : la voit-on encore à la taille du header ? Un objet
    /// jugé à 110 pt et livré à 26 ment sur tout — c'est le piège de Nyquist
    /// déjà payé sur la carte Objectif.
    private static let small = CommandLine.arguments.contains("-pieceSmall")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if Self.small {
                VStack(spacing: 44) {
                    MoonCoinView(coinR: 26, yawOverride: Self.freeze,
                                 idleLife: Self.freeze == nil ? 1 : 0)
                    MoonCoinView(coinR: 34, yawOverride: Self.freeze,
                                 idleLife: Self.freeze == nil ? 1 : 0)
                    MoonCoinView(coinR: 46, yawOverride: Self.freeze,
                                 idleLife: Self.freeze == nil ? 1 : 0)
                }
            } else {
                MoonCoinView(coinR: 110, yawOverride: Self.freeze,
                                 idleLife: Self.freeze == nil ? 1 : 0)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
