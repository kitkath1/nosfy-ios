#!/usr/bin/env python3
"""Pose les 2 édits hooks du banc nav DANS LA COPIE, par ancres exactes
(refuse si une ancre manque ou est ambiguë — le code de prod a bougé et
il faut ré-ancrer À LA MAIN, jamais à l'aveugle). Idempotent.
Usage: applique_hooks.py <racine-copie>"""
import sys

base = sys.argv[1]


def edite(chemin, vieux, neuf, temoin):
    src = open(chemin, encoding="utf-8").read()
    if temoin in src:
        print(f"déjà posé : {chemin}")
        return
    n = src.count(vieux)
    if n != 1:
        print(f"ANCRE x{n} dans {chemin}: {vieux[:70]!r}")
        sys.exit(2)
    open(chemin, "w", encoding="utf-8").write(src.replace(vieux, neuf))
    print(f"EDIT OK {chemin}")


# B) WoopApp — la sonde d'état en overlay de la racine
edite(base + "/Nosfy/NosfyApp.swift",
      """            RootView()
                .preferredColorScheme(.dark)
                .tint(.woopViolet)""",
      """            RootView()
                .preferredColorScheme(.dark)
                .tint(.woopViolet)
                .overlay(alignment: .topTrailing) { FouettageNavSonde() }""",
      "FouettageNavSonde()")

# C) PageCard — la marque de bande, DERNIER modificateur de la computed
#    `bande` (le code actuel finit par .onGeometryChange ; l'ancienne
#    ancre `.background { PanBande }` N'EXISTE PLUS).
edite(base + "/Nosfy/Views/PageCard.swift",
      """            NavEtat.shared.bandeVisiblePubliee = bandeVisible
        }
    }
""",
      """            NavEtat.shared.bandeVisiblePubliee = bandeVisible
        }
        .modifier(FouettageBandeMarque(enSeance: enSeance))
    }
""",
      "FouettageBandeMarque(enSeance:")
