#!/usr/bin/env python3
"""Pose les hooks du banc PILULE (lot 2, pivot 04-09) DANS LA COPIE, par
ancres exactes — refuse si une ancre manque ou est ambiguë : le code de
prod a bougé et il faut ré-ancrer À LA MAIN, jamais à l'aveugle.
Idempotent.

Usage: applique_hooks_pilule.py <racine-copie>
"""
import sys

base = sys.argv[1]


def edite(chemin, vieux, neuf, temoin):
    src = open(chemin, encoding="utf-8").read()
    if temoin in src:
        print(f"déjà posé : {chemin}")
        return
    n = src.count(vieux)
    if n != 1:
        print(f"ANCRE x{n} dans {chemin}: {vieux[:80]!r}")
        sys.exit(2)
    open(chemin, "w", encoding="utf-8").write(src.replace(vieux, neuf))
    print(f"EDIT OK {chemin}")


# A) WoopApp — la sonde d'état en overlay de la racine.
edite(base + "/Woop/WoopApp.swift",
      """            RootView()
                .preferredColorScheme(.dark)
                .tint(.woopViolet)""",
      """            RootView()
                .preferredColorScheme(.dark)
                .tint(.woopViolet)
                .overlay(alignment: .topTrailing) { FouettagePiluleSonde() }""",
      "FouettagePiluleSonde()")

# B) PageCard — la marque de bande, sur le CORPS de la card.
#    ⚠️ SURTOUT PAS sur la computed `bande` (l'ancre de l'ancien banc) :
#    depuis que la nav a déménagé au châssis (pivot 04-09), `bande` est
#    DÉCLARÉE MAIS JAMAIS MONTÉE — du code mort. Une marque posée là ne
#    s'exécute jamais et le banc croit que la séance n'existe pas.
#    (Payé une fois, le 04-09 : 8 cas rouges sur `seance=0`.)
edite(base + "/Woop/Views/PageCard.swift",
      """        .onDisappear { NavEtat.shared.retirerBande(jeton) }""",
      """        .onDisappear { NavEtat.shared.retirerBande(jeton) }
        .modifier(FouettageBandeMarque(enSeance: enSeance))""",
      "FouettageBandeMarque(enSeance:")

# C) PiluleVagabonde — la marque du CORPS de la pilule (son rect visible).
edite(base + "/Woop/Views/PiluleVagabonde.swift",
      """            .sondeCadence("pilule")
            .accessibilityIdentifier("seance-pastille")
    }""",
      """            .sondeCadence("pilule")
            .accessibilityIdentifier("seance-pastille")
            .modifier(FouettagePiluleMarque())
    }""",
      "FouettagePiluleMarque()")

# D) PiluleVagabonde — la marque de L'ÎLE (dernier modificateur de `ile`).
# (05-09 : `isSource:` est arrivé avec le fondu croisé ; 06-09 V2 : la
#  position suit l'état fine/gonflée — l'ancre suit, encore.)
edite(base + "/Woop/Views/PiluleVagabonde.swift",
      """        .position(x: UIScreen.main.bounds.width / 2,
                  y: doigtIle || SouffleBanc.horloge
                      ? IleGeo.capsuleCentreY : IleGeo.babyCentreY)
        .accessibilityIdentifier("seance-ile")
    }""",
      """        .position(x: UIScreen.main.bounds.width / 2,
                  y: doigtIle || SouffleBanc.horloge
                      ? IleGeo.capsuleCentreY : IleGeo.babyCentreY)
        .accessibilityIdentifier("seance-ile")
        .modifier(FouettageIleMarque())
    }""",
      "FouettageIleMarque()")

# D bis) Compter l'action réelle du stop, maintenant placé à droite.
edite(base + "/Woop/Views/PiluleVagabonde.swift",
      """                    .highPriorityGesture(TapGesture().onEnded {
                        Haptique.moyen()
                        onStop()
                    })""",
      """                    .highPriorityGesture(TapGesture().onEnded {
                        FouettagePiluleFaits.shared.nbStop += 1
                        Haptique.moyen()
                        onStop()
                    })""",
      "nbStop += 1")

# E) PiluleVagabonde — la marque du GRAND PLAYER (sa présence EST le test).
edite(base + "/Woop/Views/PiluleVagabonde.swift",
      """        .sondeCadence("player-morph")""",
      """        .sondeCadence("player-morph")
        .modifier(FouettageGrandPlayerMarque())""",
      "FouettageGrandPlayerMarque()")

# F) DIAGNOSTIC DE GESTE — des prints DANS le geste de la pastille (copie
#    jetable seulement). Un compteur d'état ne dit pas si `onChanged` a
#    été appelé : seul le geste lui-même peut le dire.
edite(base + "/Woop/Views/PiluleVagabonde.swift",
      """                    .onChanged { v in etat.suivre(v.translation) }""",
      """                    .onChanged { v in
                        FouettagePiluleFaits.shared.nbChanged += 1
                        etat.suivre(v.translation)
                    }""",
      "nbChanged += 1")

edite(base + "/Woop/Views/PiluleVagabonde.swift",
      """                    .exclusively(before: TapGesture().onEnded {
                        guard !etat.enVol, !etat.enDrag else { return }""",
      """                    .exclusively(before: TapGesture().onEnded {
                        FouettagePiluleFaits.shared.nbTap += 1
                        guard !etat.enVol, !etat.enDrag else { return }""",
      "nbTap += 1")

# (LA SONDE DE GESTE EXTÉRIEURE A ÉTÉ RETIRÉE le 04-09, sa preuve faite :
#  elle comptait 9 événements de doigt pendant que le geste de la pastille
#  en comptait 0 — c'est elle qui a désigné le verre `.interactive()`.
#  Un `simultaneousGesture(minimumDistance: 0)` affame les taps : le laisser
#  aurait fait mentir tous les cas suivants.)

# G) EXPÉRIENCE (copie jetable) : le `matchedGeometryEffect` du corps
#    est-il ce qui déplace les PIXELS sans la zone tactile ? Piloté par
#    la variable d'environnement FOUET_SANS_MATCHED=1.
import os
if os.environ.get("FOUET_SANS_MATCHED") == "1":
    edite(base + "/Woop/Views/PiluleVagabonde.swift",
          """            .matchedGeometryEffect(id: "pilule-vol", in: vol,
                                   isSource: !etat.dansIle)
            .position(x: UIScreen.main.bounds.width / 2, y: y)""",
          """            .position(x: UIScreen.main.bounds.width / 2, y: y)""",
          "// SANS-MATCHED")

print("hooks pilule : OK")
