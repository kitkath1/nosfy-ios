#!/usr/bin/env python3
"""Preuve REST du départ : compte QA, UUID isolés, nettoyage ciblé.

WOOP_QA_EMAIL et WOOP_QA_PASSWORD sont fournis par l'environnement.
--seance-app lit puis nettoie l'UUID créé par CountdownUITests, app arrêtée.
Les jetons et mots de passe ne sont jamais écrits dans le rapport.
"""
import argparse
from datetime import datetime, timezone, timedelta
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request
import uuid

repo = Path(__file__).resolve().parents[2]
source = (repo / "Woop/Services/Supabase.swift").read_text()
base = re.search(r'https://[a-z0-9]+\.supabase\.co', source).group()
cle = re.search(r'sb_publishable_[A-Za-z0-9_-]+', source).group()


def appel(path, token, method="GET", body=None, prefer=None):
    headers = {"apikey": cle, "Authorization": "Bearer " + token,
               "Content-Type": "application/json"}
    if prefer:
        headers["Prefer"] = prefer
    r = urllib.request.Request(base + path, method=method, headers=headers,
                               data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(r, timeout=20) as rep:
            raw = rep.read()
            return rep.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as err:
        return err.code, None


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--seance-app", type=uuid.UUID)
    args = p.parse_args()
    status, auth = appel("/auth/v1/token?grant_type=password", cle, "POST", {
        "email": os.environ["WOOP_QA_EMAIL"], "password": os.environ["WOOP_QA_PASSWORD"]})
    assert status == 200, f"auth QA refusée : HTTP{status}"
    token, uid = auth["access_token"], auth["user"]["id"]
    preuves, nettoyage = [], []

    def lire(id):
        s, rows = appel(f"/rest/v1/workouts?id=eq.{id}&select=id,started_at,ended_at,user_id", token)
        assert s == 200 and isinstance(rows, list), f"lecture : HTTP{s}"
        return rows

    def note(nom):
        preuves.append(nom)
        print("PASS", nom)

    try:
        if args.seance_app:
            ident = str(args.seance_app)
            rows = lire(ident)
            assert len(rows) == 1 and rows[0]["user_id"] == uid and rows[0]["ended_at"] is None
            nettoyage.append(ident)
            note("UUID créé dans l'app relu au serveur, une seule séance ouverte du compte QA")
            s, home = appel("/rest/v1/rpc/home", token, "POST", {})
            assert s == 200 and home["en_seance"] is True
            note("home() voit la séance ouverte")

        ident = str(uuid.uuid4())
        debut = datetime.now(timezone.utc).replace(microsecond=0)
        row = {"id": ident, "user_id": uid, "started_at": debut.isoformat()}
        pref = "resolution=ignore-duplicates,return=representation"
        s, rows = appel("/rest/v1/workouts?on_conflict=id", token, "POST", [row], pref)
        assert s == 201 and len(rows) == 1
        nettoyage.append(ident)
        note("insertion du départ avec ended_at null")
        row["started_at"] = (debut + timedelta(minutes=1)).isoformat()
        s, rows = appel("/rest/v1/workouts?on_conflict=id", token, "POST", [row], pref)
        assert s in (200, 201) and rows == []
        rows = lire(ident)
        assert len(rows) == 1 and datetime.fromisoformat(rows[0]["started_at"]) == debut
        note("double envoi : une ligne et départ initial conservé")

        fin = (debut + timedelta(seconds=1)).isoformat()
        s, _ = appel(f"/rest/v1/workouts?id=eq.{ident}", token, "PATCH", {"ended_at": fin})
        assert s == 204
        s, _ = appel("/rest/v1/workouts?on_conflict=id", token, "POST", [row], pref)
        assert s in (200, 201) and lire(ident)[0]["ended_at"] is not None
        note("départ retardé : la séance terminée ne se rouvre pas")
        s, _ = appel(f"/rest/v1/workouts?id=eq.{ident}&ended_at=is.null", token, "DELETE")
        assert s == 204 and len(lire(ident)) == 1
        note("annulation retardée : la séance terminée reste conservée")
    finally:
        for ident in nettoyage:
            s, _ = appel(f"/rest/v1/workouts?id=eq.{ident}&user_id=eq.{uid}", token, "DELETE")
            assert s == 204 and not lire(ident), f"nettoyage QA incomplet : {ident}"
        print("NETTOYAGE", len(nettoyage), "UUID QA retirés, aucune clôture ni récompense appelée")
    print(json.dumps({"preuves": preuves, "nettoyees": len(nettoyage)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
