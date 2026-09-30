#!/usr/bin/env python3
"""
verif_depart_serie.py — LE DÉPART DE SÉRIE AU SERVEUR (30-09, session Réglages).

    python3 tools/reglages/verif_depart_serie.py

Compte de TEST seulement (kat44426+woop-forge-test), jamais un vrai compte.
Ce qu'elle prouve (site : b-tb-user-prefs, b-fn-depart-serie, b-fn-definir-depart-serie) :
  1. la colonne `user_prefs.depart_serie` existe — et une colonne bidon, témoin, est REFUSÉE ;
  2. sans session, les deux fonctions sont fermées (anon révoqué) ;
  3. `depart_serie()` rend le choix ou le défaut de `reward_rules` ;
  4. `definir_depart_serie('galet')` écrit et rend le nouvel état ; le REJEU rend la même chose ;
  5. un format inconnu répond 200 avec un motif (`format_inconnu`), sans rien écrire ;
  6. l'objectif hebdo du compte n'a pas bougé ;
  7. l'état de départ est remis à la fin.
Chaque corps est imprimé : on le LIT, on ne l'interprète pas.
"""
import re, json, os, sys, urllib.request, urllib.error

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', open(f"{REPO}/Nosfy/Services/Supabase.swift").read()).group(1)


def call(path, body=None, jwt=None, method="POST"):
    h = {"apikey": KEY, "Content-Type": "application/json", "Authorization": f"Bearer {jwt or KEY}"}
    data = None if method == "GET" else json.dumps(body or {}).encode()
    req = urllib.request.Request(URL + path, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


ok, N_OK, N_KO = True, 0, 0


def verdict(cond, msg):
    global ok, N_OK, N_KO
    print(("  ✓ " if cond else "  ✗ ") + msg)
    ok = ok and cond
    N_OK, N_KO = (N_OK + 1, N_KO) if cond else (N_OK, N_KO + 1)


s, b = call("/auth/v1/token?grant_type=password",
            {"email": "kat44426+woop-forge-test@gmail.com", "password": "forge-test-2026"})
jwt = b.get("access_token") if isinstance(b, dict) else None
if not jwt:
    print("✗ connexion du compte de test impossible :", s, b)
    sys.exit(1)
print("compte de test :", b.get("user", {}).get("id"))

print("\n[1] la colonne, et son témoin")
st, j = call("/rest/v1/user_prefs?select=depart_serie&limit=1", jwt=jwt, method="GET")
print("     ", st, j)
verdict(st == 200, "user_prefs.depart_serie → 200")
st, j = call("/rest/v1/user_prefs?select=colonne_temoin_inexistante&limit=1", jwt=jwt, method="GET")
print("     ", st, str(j)[:140])
verdict(st == 400 and "does not exist" in str(j), "colonne témoin → 400 « does not exist » (la sonde sait échouer)")

print("\n[2] sans session : fermé")
st, j = call("/rest/v1/rpc/depart_serie")
print("     ", st, str(j)[:160])
verdict(st in (401, 403) or (st == 404 and "permission" in str(j).lower()) or "permission denied" in str(j), "depart_serie() sans session → refusé")
st, j = call("/rest/v1/rpc/definir_depart_serie", {"p_format": "galet"})
print("     ", st, str(j)[:160])
verdict(st in (401, 403) or "permission denied" in str(j), "definir_depart_serie() sans session → refusé")

print("\n[3] la lecture")
st, avant = call("/rest/v1/rpc/depart_serie", jwt=jwt)
print("     ", st, avant)
verdict(st == 200 and isinstance(avant, dict) and avant.get("depart_serie") in ("galet", "slider"), "depart_serie() → 200, galet|slider")
st, obj_avant = call("/rest/v1/rpc/objectif_hebdo", jwt=jwt)
print("      objectif_hebdo() avant :", st, obj_avant)

print("\n[4] l'écriture, et son rejeu")
st, j = call("/rest/v1/rpc/definir_depart_serie", {"p_format": "galet"}, jwt)
print("     ", st, j)
verdict(st == 200 and j.get("ok") is True and j.get("depart_serie") == "galet", "definir_depart_serie('galet') → ok, rend « galet »")
st, j2 = call("/rest/v1/rpc/definir_depart_serie", {"p_format": "galet"}, jwt)
print("     ", st, j2)
verdict(st == 200 and j2 == j, "rejeu identique")
st, lu = call("/rest/v1/rpc/depart_serie", jwt=jwt)
print("     ", st, lu)
verdict(lu.get("depart_serie") == "galet" and lu.get("choisi") is True, "relu : galet, choisi")

print("\n[5] un format inconnu : 200 et un motif, rien d'écrit")
st, j = call("/rest/v1/rpc/definir_depart_serie", {"p_format": "trottinette"}, jwt)
print("     ", st, j)
verdict(st == 200 and j.get("ok") is False and j.get("raison") == "format_inconnu", "→ 200 {ok:false, raison:format_inconnu}")
st, lu = call("/rest/v1/rpc/depart_serie", jwt=jwt)
verdict(lu.get("depart_serie") == "galet", "relu : toujours galet")

print("\n[6] le slider, et l'objectif intact")
st, j = call("/rest/v1/rpc/definir_depart_serie", {"p_format": "slider"}, jwt)
print("     ", st, j)
verdict(st == 200 and j.get("depart_serie") == "slider", "definir_depart_serie('slider') → slider")
st, obj_apres = call("/rest/v1/rpc/objectif_hebdo", jwt=jwt)
print("      objectif_hebdo() après :", st, obj_apres)
verdict(obj_apres == obj_avant, f"objectif hebdo inchangé ({obj_avant})")

print("\n[7] remise de l'état de départ")
if avant.get("choisi"):
    st, j = call("/rest/v1/rpc/definir_depart_serie", {"p_format": avant["depart_serie"]}, jwt)
    verdict(j.get("depart_serie") == avant["depart_serie"], f"remis à « {avant['depart_serie']} »")
else:
    # Jamais choisi au départ : l'API ne sait pas rendre « null » (c'est voulu) —
    # le compte de test garde le choix « slider », qui est aussi le défaut.
    print("      le compte n'avait jamais choisi : il garde « slider » (= le défaut), dit ici")

print(f"\n{'PASS' if ok else 'FAIL'} — {N_OK} ✓, {N_KO} ✗")
sys.exit(0 if ok else 1)
