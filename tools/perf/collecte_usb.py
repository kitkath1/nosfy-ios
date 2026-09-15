#!/usr/bin/env python3
"""Copie les derniers journaux Woop via HouseArrest, sans relancer l'app.

Repli vérifié le 15-09-2026 quand CoreDevice renvoie 1011 malgré l'USB.
N'accède qu'aux noms vol/nav et copie ces fichiers vers une destination neuve.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess

IPHONE = "00008120-001E4CDC0A85A01E"


def commande(args, entree=None):
    r = subprocess.run(args, input=entree, text=True, capture_output=True, timeout=25)
    if r.returncode:
        raise RuntimeError(r.stdout + r.stderr)
    return r.stdout + r.stderr


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("destination", type=Path)
    p.add_argument("--nav-only", action="store_true")
    args = p.parse_args()
    appareils = commande(["idevice_id", "-l"]).splitlines()
    # afcclient sans -u : ne jamais laisser le choix implicite d'un autre iPhone.
    if appareils != [IPHONE]:
        raise RuntimeError(f"Un seul iPhone USB attendu ({IPHONE}), reçu {appareils}")
    nom = commande(["ideviceinfo", "-u", IPHONE, "-k", "DeviceName"]).strip()
    args.destination.mkdir(parents=True, exist_ok=False)
    afc = ["afcclient", "--container", "fr.kathryn.woop"]
    liste = commande(afc, "ls Documents\nexit\n")
    (args.destination / "liste.log").write_text(liste)
    fichiers = set(re.findall(r"(?:vol|nav)-\d{8}-\d{6}\.jsonl", liste))
    sources = {}
    for genre in (["nav"] if args.nav_only else ["vol", "nav"]):
        candidats = sorted(n for n in fichiers if n.startswith(genre + "-"))
        if not candidats:
            raise RuntimeError(f"Aucun journal {genre} dans la réponse AFC")
        sources[genre] = candidats[-1]
    # Chemins AFC sans espaces ; pas d'interprétation shell.
    destination = args.destination.resolve()
    if any(c.isspace() for c in str(destination)):
        raise ValueError("Choisir un chemin de destination sans espace pour afcclient")
    entree = "".join(f"get Documents/{n} {destination}/{n}\n" for n in sources.values())
    copie = commande(afc, entree + "exit\n")
    (destination / "copie.log").write_text(copie)
    provenance = {"collecte_utc": datetime.now(timezone.utc).isoformat(),
                  "udid": IPHONE, "appareil": nom,
                  "transport": "afcclient --container fr.kathryn.woop", "sources": {}}
    for genre, source in sources.items():
        fichier = destination / source
        lignes = [json.loads(l) for l in fichier.read_text().splitlines() if l.strip()]
        if not lignes:
            raise RuntimeError(f"Journal vide : {source}")
        provenance["sources"][genre] = {"source": source, "lignes": len(lignes)}
    (destination / "sources.json").write_text(json.dumps(provenance, indent=2, ensure_ascii=False))
    print(json.dumps(provenance, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
