#!/usr/bin/env python3
"""Résume une fenêtre de SondeVol sans confondre Home, surcouche et protection.

Lecture seule, sans accès à l'iPhone. Les bornes sont start < t <= end.
Code 2 si la fenêtre ne contient aucune ligne Home exploitable ou si le fichier
est invalide. Les résultats ne constituent pas un verdict énergétique.
"""

import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import statistics
import sys


METRICS = ("t", "cpu", "img", "pire", "therm", "protection")
OVERLAYS = ("seance", "player", "ile", "drag", "chemin", "welcome", "premiere")
REQUIRED = METRICS + OVERLAYS + ("onglet", "bancHome")


def load_rows(path):
    rows = []
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise ValueError(f"ligne {line_number} : objet JSON attendu")
        missing = [key for key in REQUIRED if key not in row]
        if missing:
            raise ValueError(f"ligne {line_number} : champs absents {missing}")
        for key in METRICS + OVERLAYS:
            value = row[key]
            if (not isinstance(value, (int, float)) or isinstance(value, bool)
                    or not math.isfinite(value)):
                raise ValueError(f"ligne {line_number} : {key} doit être fini et numérique")
        if row["therm"] not in (0, 1, 2, 3) or row["protection"] not in (0, 1):
            raise ValueError(f"ligne {line_number} : catégorie thermique/protection invalide")
        if any(row[key] not in (0, 1) for key in OVERLAYS):
            raise ValueError(f"ligne {line_number} : contexte binaire invalide")
        if any(row[key] < 0 for key in ("t", "cpu", "img", "pire")):
            raise ValueError(f"ligne {line_number} : métrique négative")
        if rows and row["t"] <= rows[-1]["t"]:
            raise ValueError(f"ligne {line_number} : temps non croissant ; sessions mélangées ?")
        rows.append(row)
    if not rows:
        raise ValueError("journal vide")
    return rows


def stats(rows):
    if not rows:
        return {"n": 0}
    return {
        "n": len(rows), "premier_t": rows[0]["t"], "dernier_t": rows[-1]["t"],
        "etendue_s": round(rows[-1]["t"] - rows[0]["t"], 2),
        "cpu_median_pct_un_coeur": statistics.median(row["cpu"] for row in rows),
        "cpu_max_pct_un_coeur": max(row["cpu"] for row in rows),
        "callbacks_median_par_s": statistics.median(row["img"] for row in rows),
        "callbacks_min_par_s": min(row["img"] for row in rows),
        "intervalle_max_ms": max(row["pire"] for row in rows),
        "lignes_intervalle_sup_100ms": sum(row["pire"] > 100 for row in rows),
        "lignes_gel_signale": sum(row.get("gel", 0) == 1 for row in rows),
    }


def analyse(rows, start, end):
    window = [row for row in rows if start < row["t"] <= end]
    kept = []
    exclusions = Counter()
    groups = defaultdict(list)
    for row in window:
        reasons = [key for key in OVERLAYS if row[key] != 0]
        if row["onglet"] != "home":
            reasons.append("autre_onglet")
        if row["bancHome"] != "inactif":
            reasons.append("banc_de_variantes_actif")
        if reasons:
            exclusions["+".join(reasons)] += 1
            continue
        kept.append(row)
        groups[(row["therm"], row["protection"])].append(row)

    transitions = []
    previous = None
    for row in window:
        state = (row["therm"], row["protection"])
        if state != previous:
            transitions.append({"t": row["t"], "therm": state[0], "protection": state[1]})
            previous = state
    gaps = [{"de_t": a["t"], "a_t": b["t"], "ecart_s": round(b["t"] - a["t"], 2)}
            for a, b in zip(window, window[1:]) if b["t"] - a["t"] > 2.5]
    return {
        "fenetre": {"debut_exclu": start, "fin_incluse": None if math.isinf(end) else end},
        "lignes_journal": len(rows), "lignes_fenetre": len(window),
        "contexte_exclu": dict(exclusions), "home_retenue": stats(kept),
        "groupes": [{"therm": key[0], "protection": key[1], **stats(values)}
                    for key, values in sorted(groups.items())],
        "transitions_fenetre": transitions, "ecarts_journal_sup_2_5s": gaps,
        "limites": [
            "CPU et callbacks ne mesurent ni watts, ni GPU, ni température en degrés.",
            "Les catégories thermiques égales ne garantissent pas des fréquences égales.",
            "L'étendue d'un groupe peut contenir des interruptions : ce n'est pas sa durée continue.",
            "Corroborer le contexte avec nav et l'écran ; les surcouches non instrumentées restent invisibles.",
            "Les écarts du journal peuvent être des gels ou des suspensions ; lire le contexte.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("journal", type=Path)
    parser.add_argument("--start", type=float, default=15)
    parser.add_argument("--end", type=float, default=math.inf)
    args = parser.parse_args()
    if not math.isfinite(args.start) or math.isnan(args.end) or args.start >= args.end:
        parser.error("bornes invalides : début fini et strictement inférieur à la fin")
    try:
        result = analyse(load_rows(args.journal), args.start, args.end)
    except (ValueError, OSError) as error:
        print(f"Mesure non analysable : {error}", file=sys.stderr)
        return 2
    print(json.dumps({"source": str(args.journal), **result}, ensure_ascii=False, indent=2, allow_nan=False))
    return 0 if result["home_retenue"]["n"] else 2


if __name__ == "__main__":
    sys.exit(main())
