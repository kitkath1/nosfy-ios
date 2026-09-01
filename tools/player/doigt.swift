// doigt.swift — §3.4undecies B4 : de VRAIS touchers sur le Simulator.
//
// Le doigt fantôme (`-playerDoigt`) appelle le MODÈLE : il ne teste
// jamais le routage tactile (recognizers, ScrollView, priorités). Cet
// outil poste de vrais événements souris sur la FENÊTRE du Simulator —
// le sim les traduit en UITouch réels qui traversent le VRAI routage.
//
// Compilation : swiftc tools/player/doigt.swift -o <sortie>
// Usage :
//   doigt tap  <fx> <fy>                — un tap à la fraction (fx,fy)
//   doigt drag <fx> <fy0> <fy1> <durée> — un drag vertical lent
// Les fractions sont relatives à la fenêtre Simulator au premier plan
// (0,0 = coin haut-gauche ; la barre de titre ~0,03 est à éviter).
//
// ⚠️ Poster des CGEvent exige l'autorisation Accessibilité pour le
// terminal. Si les événements sont muets (aucun log GESTE-SONDE,
// aucun tap témoin), c'est ELLE qui manque — le dire, pas deviner.

import AppKit
import CoreGraphics

func fenetreSimulator() -> CGRect? {
    let opts = CGWindowListOption([.optionOnScreenOnly,
                                   .excludeDesktopElements])
    guard let liste = CGWindowListCopyWindowInfo(opts, kCGNullWindowID)
        as? [[String: Any]] else { return nil }
    // z-order top-first : la PREMIÈRE fenêtre Simulator assez grande
    // est celle du premier plan.
    for w in liste {
        guard let owner = w[kCGWindowOwnerName as String] as? String,
              owner == "Simulator",
              let b = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = b["X"], let y = b["Y"],
              let wi = b["Width"], let h = b["Height"],
              h > 400, wi > 200 else { continue }
        return CGRect(x: x, y: y, width: wi, height: h)
    }
    return nil
}

func poste(_ type: CGEventType, _ pt: CGPoint) {
    let e = CGEvent(mouseEventSource: nil, mouseType: type,
                    mouseCursorPosition: pt, mouseButton: .left)
    e?.post(tap: .cghidEventTap)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: doigt tap fx fy | doigt drag fx fy0 fy1 duree")
    exit(1)
}
guard let cadre = fenetreSimulator() else {
    print("ERREUR : fenêtre Simulator introuvable (au premier plan ?)")
    exit(2)
}

switch args[1] {
case "fenetres":
    // Toutes les fenêtres Simulator (z-order top-first) + SELF-TEST
    // d'injection : un mouseMoved posté puis la position RELUE — si le
    // curseur n'a pas bougé, le post est refusé (permission
    // Accessibilité manquante) et tout verdict de drag est invalide.
    let opts = CGWindowListOption([.optionOnScreenOnly,
                                   .excludeDesktopElements])
    if let liste = CGWindowListCopyWindowInfo(opts, kCGNullWindowID)
        as? [[String: Any]] {
        for w in liste {
            guard let owner = w[kCGWindowOwnerName as String] as? String,
                  owner == "Simulator",
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }
            let nom = w[kCGWindowName as String] as? String ?? "(sans nom)"
            print("fenetre Simulator \(nom) bounds=\(b)")
        }
    }
    let cibleTest = CGPoint(x: 200, y: 200)
    poste(.mouseMoved, cibleTest)
    usleep(150_000)
    let ou = NSEvent.mouseLocation  // origine BAS-gauche
    let ecranH = NSScreen.screens.first?.frame.height ?? 0
    let ouHaut = CGPoint(x: ou.x, y: ecranH - ou.y)
    let bouge = abs(ouHaut.x - cibleTest.x) < 8
        && abs(ouHaut.y - cibleTest.y) < 8
    print("self-test injection : curseur demandé (200,200), "
        + "lu (\(Int(ouHaut.x)),\(Int(ouHaut.y))) → "
        + (bouge ? "INJECTION OK" : "REFUSÉE (permission Accessibilité)"))
case "tap":
    guard args.count >= 4, let fx = Double(args[2]),
          let fy = Double(args[3]) else { exit(1) }
    let pt = CGPoint(x: cadre.origin.x + cadre.width * fx,
                     y: cadre.origin.y + cadre.height * fy)
    poste(.mouseMoved, pt)
    usleep(120_000)
    poste(.leftMouseDown, pt)
    usleep(80_000)
    poste(.leftMouseUp, pt)
    print("tap joué @(\(Int(pt.x)),\(Int(pt.y))) fenêtre=\(cadre)")
case "drag":
    guard args.count >= 6, let fx = Double(args[2]),
          let fy0 = Double(args[3]), let fy1 = Double(args[4]),
          let duree = Double(args[5]) else { exit(1) }
    let x = cadre.origin.x + cadre.width * fx
    let y0 = cadre.origin.y + cadre.height * fy0
    let y1 = cadre.origin.y + cadre.height * fy1
    let n = max(Int(duree * 120), 4)
    poste(.mouseMoved, CGPoint(x: x, y: y0))
    usleep(150_000)
    poste(.leftMouseDown, CGPoint(x: x, y: y0))
    for i in 1...n {
        let t = Double(i) / Double(n)
        poste(.leftMouseDragged,
              CGPoint(x: x, y: y0 + (y1 - y0) * t))
        usleep(useconds_t(duree * 1_000_000 / Double(n)))
    }
    poste(.leftMouseUp, CGPoint(x: x, y: y1))
    print("drag joué x=\(Int(x)) y \(Int(y0))→\(Int(y1)) "
        + "en \(duree)s fenêtre=\(cadre)")
default:
    print("verbe inconnu \(args[1])")
    exit(1)
}
