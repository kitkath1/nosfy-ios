#!/usr/bin/env python3
"""LE TEMPS D'UNE SÉRIE, VÉRIFIÉ AU SERVEUR (30-09, migration 20260930150000).

Sur le compte de TEST de la forge, jamais un vrai compte :
  ① strength_sets.duree_s existe (et une colonne bidon, témoin, est refusée) ;
  ② exercices.saisie porte les trois façons de saisir (20260930150100) ;
  ③ synchroniser_seance accepte une série de gainage (0 rep, 0 kg, 45 s),
     et le REJEU rend la même chose ;
  ④ seances_depuis la rend avec duree_s = 45 ;
  ⑤ un client d'avant (sans duree_s) écrit 0 ; une durée négative est refusée ;
  ⑥ les séances de la sonde sont effacées à la fin.

    python3 tools/serveur/verif_series_au_temps.py
"""
import json, re, sys, uuid, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"',
                (REPO / "Nosfy/Services/Supabase.swift").read_text()).group(1)
EMAIL, MDP = "kat44426+woop-forge-test@gmail.com", "forge-test-2026"
fautes = []


def appel(methode, chemin, corps=None, jeton=None, entetes=None):
    req = urllib.request.Request(URL + chemin, method=methode,
                                 data=None if corps is None else json.dumps(corps).encode())
    req.add_header("apikey", KEY)
    req.add_header("Content-Type", "application/json")
    if jeton:
        req.add_header("Authorization", "Bearer " + jeton)
    for k, v in (entetes or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            texte = r.read().decode()
            return r.status, (json.loads(texte) if texte else None)
    except urllib.error.HTTPError as e:
        texte = e.read().decode()
        try:
            return e.code, json.loads(texte)
        except ValueError:
            return e.code, texte


def attendre(cond, quoi, detail):
    print(("✔ " if cond else "✘ ") + quoi + " — " + json.dumps(detail, ensure_ascii=False)[:220])
    if not cond:
        fautes.append(quoi)


code, auth = appel("POST", "/auth/v1/token?grant_type=password", {"email": EMAIL, "password": MDP})
if code != 200:
    sys.exit(f"✘ connexion du compte de test : {code} {auth}")
jeton, uid = auth["access_token"], auth["user"]["id"]
print(f"compte de test {uid[:8]}…")

# ① la colonne, et son témoin qui doit échouer
code, corps = appel("GET", "/rest/v1/strength_sets?select=duree_s&limit=1", jeton=jeton)
attendre(code == 200, "① strength_sets.duree_s existe", {"code": code, "corps": corps})
code, corps = appel("GET", "/rest/v1/strength_sets?select=duree_bidon&limit=1", jeton=jeton)
attendre(code == 400, "① témoin : une colonne bidon est refusée", {"code": code, "corps": corps})

# ② le catalogue
code, corps = appel("GET", "/rest/v1/exercices?select=id,saisie&id=in.(gainage,crunch-sol,chevilles,developpe-couche)",
                    jeton=jeton)
saisies = {e["id"]: e["saisie"] for e in corps} if code == 200 else {}
attendre(saisies == {"gainage": "tempsSeul", "crunch-sol": "repsSeules", "chevilles": "repsSeules",
                     "developpe-couche": "repsEtCharge"}, "② exercices.saisie", saisies)


def seance(exo, serie):
    w, e = str(uuid.uuid4()), str(uuid.uuid4())
    fin = datetime.now(timezone.utc) - timedelta(minutes=1)
    serie = dict(serie, id=str(uuid.uuid4()), logged_exercise_id=e, position=0)
    return w, {"p_workout": {"id": w, "started_at": (fin - timedelta(minutes=9)).isoformat(),
                             "ended_at": fin.isoformat(), "notes": "sonde 30-09 duree_s",
                             "fuseau": "Europe/Paris"},
               "p_exercices": [{"id": e, "workout_id": w, "exercise_id": exo, "position": 0}],
               "p_series": [serie], "p_phases": [], "p_piscines": []}


def relire(w):
    depuis = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    code, corps = appel("POST", "/rest/v1/rpc/seances_depuis", {"p_depuis": depuis, "p_limite": 50}, jeton)
    for s in (corps or {}).get("seances", []) if code == 200 else []:
        if s["id"] == w:
            return s["exercices"][0]["series"][0]
    return None


a_effacer = []
# ③ le gainage, deux fois
w, corps_rpc = seance("gainage", {"reps": 0, "weight": 0, "duree_s": 45})
a_effacer.append(w)
code1, r1 = appel("POST", "/rest/v1/rpc/synchroniser_seance", corps_rpc, jeton)
code2, r2 = appel("POST", "/rest/v1/rpc/synchroniser_seance", corps_rpc, jeton)
attendre(code1 == 200 and (r1 or {}).get("ok") is True, "③ synchroniser_seance accepte 0 rep · 0 kg · 45 s",
         {"code": code1, "corps": r1})
attendre(code2 == 200 and r2 == r1, "③ le rejeu rend la même réponse", {"code": code2, "corps": r2})
# ④ le pull
serie = relire(w)
attendre(serie is not None and serie.get("duree_s") == 45 and serie.get("reps") == 0,
         "④ seances_depuis rend duree_s = 45", serie)

# ⑤ un client d'avant, puis une durée négative
w2, corps_ancien = seance("developpe-couche", {"reps": 10, "weight": 40})
a_effacer.append(w2)
code, r = appel("POST", "/rest/v1/rpc/synchroniser_seance", corps_ancien, jeton)
serie2 = relire(w2) if code == 200 else None
attendre(code == 200 and serie2 is not None and serie2.get("duree_s") == 0,
         "⑤ un client sans duree_s écrit 0", {"code": code, "serie": serie2})
w3, corps_neg = seance("gainage", {"reps": 0, "weight": 0, "duree_s": -1})
code, r = appel("POST", "/rest/v1/rpc/synchroniser_seance", corps_neg, jeton)
if code == 200:
    a_effacer.append(w3)
attendre(code == 400 and "travail_invalide" in json.dumps(r), "⑤ une durée négative est refusée",
         {"code": code, "corps": r})

# ⑥ le ménage
for w in a_effacer:
    code, r = appel("DELETE", f"/rest/v1/workouts?id=eq.{w}", jeton=jeton,
                    entetes={"Prefer": "return=representation"})
    attendre(code == 200 and isinstance(r, list) and len(r) == 1, f"⑥ séance de la sonde effacée {w[:8]}",
             {"code": code, "lignes": len(r) if isinstance(r, list) else r})

print("\n" + ("✔ TOUT EST VERT" if not fautes else f"✘ {len(fautes)} faute(s) : " + " · ".join(fautes)))
sys.exit(1 if fautes else 0)
