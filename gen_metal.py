#!/usr/bin/env python3
"""Émet les silhouettes tracées en constantes Metal.

Un en-tête inclus par NeonIcons.metal — les polygones y sont dans le repère
du banc (origine au centre, y vers le haut, demi-côté = 1), prêts à être
donnés tels quels au SDF de polygone.

    python3 gen_metal.py
"""
import json
import os

CIBLE = "/Users/kathryn/Downloads/woop-icons/Woop/NeonIconsData.h"
ICONES = ["chocolat", "bras", "peche"]


def emettre():
    out = ["// Généré par gen_metal.py — NE PAS ÉDITER À LA MAIN.",
           "//",
           "// Les silhouettes des trois icônes, tracées au pixel sur les",
           "// références (IoU polygone/masque > 99,8 %). Repère du banc :",
           "// origine au centre de la planche, y vers le haut, demi-côté = 1.",
           ""]
    for nom in ICONES:
        d = json.load(open(f"/Users/kathryn/Downloads/woop-icons/trace/{nom}.json"))
        pts = d["pts"]
        var = "kSil" + nom.capitalize()
        out.append(f"constant int {var}N = {len(pts)};")
        out.append(f"constant float2 {var}[{len(pts)}] = {{")
        for i in range(0, len(pts), 4):
            bloc = ", ".join(f"float2({x:+.5f},{y:+.5f})" for x, y in pts[i:i + 4])
            out.append("    " + bloc + ",")
        out.append("};")
        out.append("")
    os.makedirs(os.path.dirname(CIBLE), exist_ok=True)
    open(CIBLE, "w").write("\n".join(out))
    print(f"écrit {CIBLE}  ({sum(1 for _ in open(CIBLE))} lignes)")


if __name__ == "__main__":
    emettre()
