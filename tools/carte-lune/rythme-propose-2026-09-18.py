"""Calcul exact d'une proposition Cartes, sans réseau ni écriture dans l'app.

Comparer des OUVERTURES de boosters ordinaires, toutes réussies et distinctes.
Les boosters noirs, la sélection des références et les doublons sont exclus.
Les poids sont ceux d'une proposition, pas une configuration de production.
"""
import json
import math

WEIGHTS = {"common": 45, "rare": 35, "epic": 15, "legendary": 5}


def cycle(cap, welcome=False):
    # Masse des parcours sans légendaire, classés par communes consécutives.
    states = {0: 1.0}
    first = []
    counts = dict.fromkeys(WEIGHTS, 0.0)
    for opening in range(1, cap + 1):
        following = {}
        legendary = 0.0
        for commons, mass in states.items():
            if opening == cap:
                weights = {"legendary": 1}
            elif commons >= 2 or (welcome and opening == 1):
                weights = {k: v for k, v in WEIGHTS.items() if k != "common"}
            else:
                weights = WEIGHTS
            total = sum(weights.values())
            for rarity, weight in weights.items():
                probability = mass * weight / total
                counts[rarity] += probability
                if rarity == "legendary":
                    legendary += probability
                else:
                    key = commons + 1 if rarity == "common" else 0
                    following[key] = following.get(key, 0.0) + probability
        first.append(legendary)
        states = following
    assert math.isclose(sum(first), 1.0, abs_tol=1e-12)
    expected = sum((i + 1) * p for i, p in enumerate(first))
    assert math.isclose(expected, sum(counts.values()), abs_tol=1e-12)
    assert math.isclose(counts["legendary"], 1.0, abs_tol=1e-12)
    return {
        "limite_ouvertures": cap,
        "moyenne_ouvertures": round(expected, 3),
        "distribution_premiere_legendaire": [round(p, 8) for p in first],
        "part_effective_sur_cycles_pourcent": {
            k: round(100 * v / expected, 3) for k, v in counts.items()
        },
    }


if __name__ == "__main__":
    first = cycle(6, welcome=True)
    following = cycle(12)
    print(json.dumps({
        "statut": "proposition non déployée ; modèle exact, pas une mesure produit",
        "poids_de_base": WEIGHTS,
        "regles": [
            "premier booster ordinaire rare ou mieux",
            "après deux communes, prochain booster rare ou mieux",
            "première légendaire au plus tard au sixième booster ordinaire",
            "ensuite douze boosters ordinaires maximum entre légendaires",
            "un rejeu ne compte pas ; pas de reset sur absence",
        ],
        "premiere": first,
        "suivantes": following,
        "scenarios_a_deux_seances_par_semaine": [
            {"boosters_ouverts_par_seance": b,
             "actuel_chance_aucune_legendaire_apres_6_seances_pct": round(100 * .97 ** (6 * b), 2),
             "proposition_premiere_max_seances": math.ceil(6 / b),
             "proposition_suivante_max_seances": math.ceil(12 / b),
             "proposition_premiere_max_semaines": math.ceil(6 / b) / 2,
             "proposition_suivante_max_semaines": math.ceil(12 / b) / 2}
            for b in (1, 2, 3, 5)
        ],
        "limites": "Pas de boosters noirs, de doublons, de quotas de catalogue ni de séances sans ouverture ; les semaines supposent deux séances et le nombre fixe de boosters indiqué.",
    }, ensure_ascii=False, indent=2))
