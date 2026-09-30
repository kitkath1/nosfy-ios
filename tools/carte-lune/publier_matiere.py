#!/usr/bin/env python3
"""Publier la MATIÈRE des légendaires dans le bucket public `cards` (30-09-2026).

Pour CHAQUE légendaire publiée EN BASE (la base est la vérité : les
légendaires à venir, que personne n'a encore vues, y passent sans une ligne
de plus) — son kit est cuit s'il manque (l'illustration téléchargée du
bucket, le détourage fait par rembg, `cuire_matiere.cuire`), puis :

    cards/matiere/<sha256>.png     l'atlas, rangé par EMPREINTE (jamais écrasé :
                                   un nouveau kit = un nouveau fichier)
    cards/matiere/<card_id>.json   le pointeur (écrasé à chaque publication) :
                                   atlas, sha256, monde, centre du sujet, noms

L'identifiant de carte est celui du catalogue (uuid5 de la référence, le même
espace que `publier_catalogue.py`), relu en base avant tout dépôt. L'app
(`LuneMatiere.publiee`) lit le pointeur par l'identifiant de la carte : toute
légendaire publiée reçoit sa matière, celles déjà obtenues comprises.

    python3 publier_matiere.py            (le plan : cuit ce qui manque, ne dépose rien)
    python3 publier_matiere.py --upload   (dépose, puis relit les empreintes à distance)
    python3 publier_matiere.py --recuire  (recuit aussi les kits déjà cuits)

À LANCER après chaque publication de nouvelles cartes (publier_catalogue.py) :
c'est ce qui donne aux légendaires à venir leur gravure, leur feu et leur
météo, par la même recette.
"""
import argparse
import hashlib
import json
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ICI = Path(__file__).resolve().parent
R = ICI.parents[1]
REF = "ytnnyjkramgiqyxdrkcu"
URL = f"https://{REF}.supabase.co"
ESPACE = uuid.UUID("2b66d59d-d2ef-52d2-bc01-cddf7984633b")   # publier_catalogue.py


def query(q):
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{REF}/database/query",
        data=json.dumps({"query": q}).encode(),
        headers={"Authorization": "Bearer " + (R / ".secrets/supabase-access-token").read_text().strip(),
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as res:
        return json.loads(res.read())


def deposer(chemin, data, type_, ecraser, cache):
    admin = (R / ".secrets/supabase-service-role").read_text().strip()
    req = urllib.request.Request(
        f"{URL}/storage/v1/object/cards/{chemin}", data=data, method="POST",
        headers={"Authorization": "Bearer " + admin, "apikey": admin, "Content-Type": type_,
                 "x-upsert": "true" if ecraser else "false", "cache-control": cache})
    try:
        with urllib.request.urlopen(req, timeout=90) as res:
            res.read()
    except urllib.error.HTTPError as e:
        detail = e.read()
        if ecraser or e.code not in (400, 409) or (b"Duplicate" not in detail and b"already exists" not in detail):
            raise
        # l'atlas existe déjà sous son empreinte : c'est le même fichier.


def lire(chemin):
    req = urllib.request.Request(f"{URL}/storage/v1/object/public/cards/{chemin}",
                                 headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=90) as res:
        return res.read()


def main():
    import sys
    sys.path.insert(0, str(ICI))
    import cuire_matiere
    a = argparse.ArgumentParser()
    a.add_argument("--upload", action="store_true")
    a.add_argument("--recuire", action="store_true")
    args = a.parse_args()
    lignes = query(
        "select id::text, reference, monde, noms, art_path, art_sha256 from public.cards "
        "where rarete = 'legendary' and publication = 'publiee' order by reference")
    manifeste = []
    for ligne in lignes:
        e = {"reference": ligne["reference"], "rarete": "legendary", "monde": ligne["monde"],
             "noms": ligne["noms"]}
        card_id = ligne["id"]
        assert card_id == str(uuid.uuid5(ESPACE, e["reference"])), f"{card_id} : identifiant hors du catalogue"
        nom = e["reference"].split("/")[1]
        kit = ICI / "matiere" / nom
        atlas_f, meta_f = kit / f"{nom}-matiere.png", kit / f"{nom}-matiere.json"
        if args.recuire or not atlas_f.exists():
            # L'illustration PUBLIÉE (celle que tout le monde reçoit), vérifiée.
            art = lire(ligne["art_path"])
            assert hashlib.sha256(art).hexdigest() == ligne["art_sha256"], f"{nom} : illustration distante différente"
            tmp = Path("/tmp/nosfy-matiere") / f"{ligne['art_sha256']}.png"
            tmp.parent.mkdir(parents=True, exist_ok=True)
            tmp.write_bytes(art)
            e["fichier"] = str(tmp)
            e["illustration"] = "cards/" + ligne["art_path"]
            print(f"· {nom} : kit cuit depuis l'illustration publiée")
            cuire_matiere.cuire(e)
        atlas = atlas_f.read_bytes()
        sha = hashlib.sha256(atlas).hexdigest()
        meta = json.loads(meta_f.read_text())
        pointeur = {"version": 1, "card_id": card_id, "reference": e["reference"],
                    "atlas": f"matiere/{sha}.png", "sha256": sha,
                    "monde": meta["monde"], "monde_code": meta["monde_code"],
                    "centre": meta["centre"], "noms": meta.get("noms", {}),
                    "monde_noms": meta.get("monde_noms", {})}
        manifeste.append(pointeur)
        print(f"· {nom} → {card_id} · atlas {sha[:12]} ({len(atlas) // 1024} Ko)")
        if args.upload:
            deposer(pointeur["atlas"], atlas, "image/png", False, "max-age=31536000")
            deposer(f"matiere/{card_id}.json", json.dumps(pointeur, ensure_ascii=False).encode(),
                    "application/json", True, "max-age=300")
            distant = lire(pointeur["atlas"])
            assert hashlib.sha256(distant).hexdigest() == sha, f"{nom} : atlas distant différent"
            relu = json.loads(lire(f"matiere/{card_id}.json"))
            assert relu["sha256"] == sha, f"{nom} : pointeur distant différent"
            print(f"  ✓ empreinte distante relue · pointeur relu")
    sortie = ICI / "legendaire-2026-09-30" / "publication-matiere.json"
    sortie.write_text(json.dumps(manifeste, ensure_ascii=False, indent=1) + "\n")
    print(("PUBLIÉ" if args.upload else "PLAN (rien déposé)")
          + f" : {len(manifeste)} légendaire(s) publiée(s) en base, toutes avec leur matière → {sortie.name}")


if __name__ == "__main__":
    main()
