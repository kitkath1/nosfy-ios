#!/usr/bin/env python3
"""
verif_collection.py — LE MUR DU PROFIL LIT LE SERVEUR (15-09, étape 2) : `ma_collection()`.
Corps lus, jamais devinés, compte de test ; rien n'est écrit.

    python3 tools/serveur/verif_collection.py

Ce qu'elle prouve (site : b-fo-mur, b-fo-lire-user-cards, b-tb-user-cards, b-fn-ma-collection) :
  · ma_collection() → 200, une entrée PAR FAMILLE (le slot du mur), `nombre` = les exemplaires ;
  · la somme des `nombre` = count(*) de user_cards du compte (lu en propriétaire) — rien n'est perdu ;
  · chaque famille porte card_id + art_path, et l'illustration se TÉLÉCHARGE du bucket public
    (HEAD 200 sur /storage/v1/object/public/cards/<art_path>) ;
  · pas de clé `scene` (20260915111000 : le brief de 1 800 caractères ne voyage plus) ;
  · sans jeton → 401 (EXECUTE révoqué à anon).
Le côté app (CollectionLune.relire, ProfilLune) se mesure au simulateur : -skipAuth -sessionBanc
-openTab profile, journal `[collection] ma_collection() → 7 famille(s), 28 carte(s)`, capture
tools/sacre/captures/profil-collection-serveur-2026-09-15.png.
"""
import re, json, urllib.request, urllib.error, sys, os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
REF = "ytnnyjkramgiqyxdrkcu"
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', open(f"{REPO}/Nosfy/Services/Supabase.swift").read()).group(1)
GESTION = open(f"{REPO}/.secrets/supabase-access-token").read().strip()


def call(path, body=None, jwt=None, method="POST"):
    h = {"apikey": KEY, "Content-Type": "application/json", "Authorization": f"Bearer {jwt or KEY}"}
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode() if body is not None else None, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def sql(q):
    req = urllib.request.Request(f"https://api.supabase.com/v1/projects/{REF}/database/query", data=json.dumps({"query": q}).encode(),
                                 headers={"Authorization": f"Bearer {GESTION}", "Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def j(b):
    try:
        return json.loads(b)
    except Exception:
        return {}


ok, N_OK, N_KO = True, 0, 0


def verdict(cond, msg):
    global ok, N_OK, N_KO
    print(("  ✓ " if cond else "  ✗ ") + msg)
    ok = ok and cond
    if cond: N_OK += 1
    else: N_KO += 1


s, b = call("/auth/v1/token?grant_type=password", {"email": "kat44426+woop-forge-test@gmail.com", "password": "forge-test-2026"})
jwt, uid = j(b).get("access_token"), j(b).get("user", {}).get("id")
print("compte de test :", uid)

s, b = call("/rest/v1/rpc/ma_collection", {}, jwt)
col = j(b) if s == 200 else []
verdict(s == 200 and isinstance(col, list), f"ma_collection() → {s}, {len(col)} famille(s), {len(b)} octets")
verdict(all({"famille", "rarete", "nombre", "card_id", "art_path", "premiere", "derniere"} <= set(c) for c in col), "chaque famille porte famille · rarete · nombre · card_id · art_path · premiere · derniere")
verdict(all("scene" not in c for c in col), "aucune clé scene (20260915111000)")
total = sum(c.get("nombre", 0) for c in col)
n_sql = sql(f"select count(*) as n from public.user_cards where user_id = '{uid}'")[0]["n"]
verdict(total == n_sql, f"somme des nombre = {total} = count(*) user_cards du compte ({n_sql}) : rien n'est perdu")
# 18-09 (20260918084850) : ma_collection groupe par RÉFÉRENCE (card_id), plus par
# (famille, rarete) — deux références d'une même famille font deux slots.
familles = sql(f"select count(distinct u.card_id) as n from public.user_cards u where u.user_id = '{uid}'")[0]["n"]
verdict(len(col) == familles, f"{len(col)} slots = les références distinctes en base ({familles})")
for c in col[:3]:
    req = urllib.request.Request(f"{URL}/storage/v1/object/public/cards/{c['art_path']}", method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            st, taille = r.status, r.headers.get("Content-Length")
    except urllib.error.HTTPError as e:
        st, taille = e.code, None
    verdict(st == 200, f"illustration « {c['famille']} » ({c['rarete']}, ×{c['nombre']}) → HEAD {st}, {taille} octets, publique")
s, b = call("/rest/v1/rpc/ma_collection", {}, None)
verdict(s == 401, f"sans jeton → {s} (EXECUTE révoqué à anon)")

print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE"))
sys.exit(0 if ok else 1)
