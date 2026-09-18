#!/usr/bin/env python3
"""
verif_portes.py — LE SERVEUR FERME SES PORTES : la preuve, corps lus, jamais devinés,
sur le COMPTE DE TEST (kat44426+woop-forge-test). Ne crédite rien, n'écrit rien :
chaque écriture tentée DOIT être refusée — c'est ce qu'on prouve.

    python3 tools/serveur/verif_portes.py

Ce qu'elle prouve (site : page Serveur — b-rls-argent-ferme, b-rg-rare,
b-fn-solde-noir, b-fn-solde-argent, b-fn-solde-or, b-tb-syntheses, b-migrations-posees) :
  0. le jeton LIT (coin_ledger, user_boosters → 200) : le témoin qui donne leur sens
     aux refus qui suivent — un refus avec un jeton mort ne prouverait rien ;
  1. L'ARGENT EST FERMÉ AU CLIENT : insérer dans coin_ledger, user_boosters, user_cards,
     workout_facts, reward_rules → 403 / 42501 (RLS, aucune policy d'écriture) ;
     modifier ou effacer → 0 ligne (`Prefer: return=representation` rend [] — ⚠️ le
     204 d'un PATCH/DELETE refusé par RLS ne prouve RIEN, mesuré le 15-09), et les
     valeurs relues sont inchangées (solde_or, lignes négatives, sachets, pieces_par_serie) ;
  2. LES DÉS SONT CACHÉS (20260915090000) : reward_rules?key=like.rare_* → [] ; les cinq
     chemin_* que l'app lit en direct → 5 ; regles_annonces() rend exactement les clés
     que le REST montre ; etat_coffre() rend toujours prix_booster (le security definer
     lit la table entière, la policy ne le concerne pas) ;
  3. solde_noir → 404 PGRST202 (retirée le 28-08, wallet_coffre.sql:94) avec ses deux
     témoins : la fonction inventée → 404 aussi, solde_argent → 200 ; claim_booster →
     403 (fermée, pas absente) ; solde_or → 200 (appelable — la carte disait « interne ») ;
  4. syntheses → 404 PGRST205 (la table N'EST PAS au serveur), témoin workout_facts → 200 ;
     booster_progress → 404 et welcome_* → [] (le ménage du 15-09, 20260915100000), et
     etat_coffre() rend toujours retour_disponible et reste (le pop-up et la jauge s'en passent) ;
  5. les migrations : `supabase migration list --linked` (jeton .secrets, JAMAIS celui de
     ~/.zshenv qui voit un autre projet) — chaque fichier de supabase/migrations/ est
     posé, rien n'est en attente, rien n'est orphelin. Sautée (⚠️, pas ✗) sans jeton.
"""
import re, json, base64, subprocess, urllib.request, urllib.error, sys, os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
src = open(f"{REPO}/Nosfy/Services/Supabase.swift").read()
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', src).group(1)


def call3(path, body=None, jwt=None, method="POST", extra=None):
    h = {"apikey": KEY, "Content-Type": "application/json",
         "Authorization": f"Bearer {jwt or KEY}"}
    if extra:
        h.update(extra)
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode() if body is not None else None,
                                 headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode(), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(), dict(e.headers)


def call(path, body=None, jwt=None, method="POST", extra=None):
    s, b, _ = call3(path, body, jwt, method, extra)
    return s, b


def j(b):
    try:
        return json.loads(b)
    except Exception:
        return {}


ok = True
N_OK = 0
N_KO = 0


def verdict(cond, msg):
    global ok, N_OK, N_KO
    print(("  ✓ " if cond else "  ✗ ") + msg)
    ok = ok and cond
    if cond:
        N_OK += 1
    else:
        N_KO += 1


def compte(path, jwt):
    """le nombre de lignes d'une requête REST, par Content-Range (count=exact), sans les lire."""
    _, _, h = call3(path + ("&" if "?" in path else "?") + "select=*&limit=1", None, jwt, "GET", {"Prefer": "count=exact"})
    cr = h.get("Content-Range") or h.get("content-range") or "*/0"
    try:
        return int(cr.split("/")[1])
    except Exception:
        return -1


REPR = {"Prefer": "return=representation"}
ZERO = "00000000-0000-0000-0000-000000000000"

st, b = call("/auth/v1/token?grant_type=password",
             {"email": "kat44426+woop-forge-test@gmail.com", "password": "forge-test-2026"})
jwt = j(b).get("access_token") if st == 200 else None
print("auth :", st, "(jeton reçu)" if jwt else b[:200])
if not jwt:
    sys.exit("pas de jeton — arrêt")
uid = json.loads(base64.urlsafe_b64decode(jwt.split(".")[1] + "==")).get("sub")
print("compte de test :", uid)

print("\n[0] le témoin : le jeton LIT")
s0, b0 = call("/rest/v1/coin_ledger?select=delta&limit=1", None, jwt, "GET")
verdict(s0 == 200 and isinstance(j(b0), list), f"GET coin_ledger → {s0} {b0[:60]} : le jeton lit son carnet")
s0b, b0b = call("/rest/v1/user_boosters?select=id&limit=1", None, jwt, "GET")
verdict(s0b == 200, f"GET user_boosters → {s0b} : le jeton lit ses sachets")

print("\n[1] l'argent est fermé au client — insérer")
for table, corps in (("coin_ledger", {"user_id": uid, "delta": 1000000, "raison": "serie_faite", "currency": "yellow"}),
                     ("user_boosters", {"user_id": uid, "origine": "conversion"}),
                     ("user_cards", {"user_id": uid, "card_id": ZERO}),
                     ("workout_facts", {"user_id": uid, "workout_id": ZERO, "kind": "top_muscu"}),
                     ("reward_rules", {"key": "sonde_bidon", "value": 1})):
    s, b = call(f"/rest/v1/{table}", corps, jwt, "POST", REPR)
    verdict(s == 403 and "42501" in b and "row-level security" in b,
            f"POST {table} → {s} / 42501 « new row violates row-level security policy »")

print("\n[1] l'argent est fermé au client — modifier, effacer (0 ligne, valeurs relues inchangées)")
solde_avant = j(call("/rest/v1/rpc/solde_or", {}, jwt)[1])
neg_avant = compte(f"/rest/v1/coin_ledger?user_id=eq.{uid}&delta=lt.0", jwt)
fermes_avant = compte(f"/rest/v1/user_boosters?user_id=eq.{uid}&opened_at=is.null", jwt)
taux_avant = j(call("/rest/v1/reward_rules?select=value&key=eq.pieces_par_serie", None, jwt, "GET")[1])
print(f"    avant : solde_or {solde_avant} · lignes négatives {neg_avant} · sachets fermés {fermes_avant} · pieces_par_serie {taux_avant}")
s, b = call(f"/rest/v1/coin_ledger?user_id=eq.{uid}", {"delta": 1000000}, jwt, "PATCH", REPR)
verdict(s == 200 and j(b) == [], f"PATCH coin_ledger delta=1000000 → {s} {b[:20]} : 0 ligne modifiée")
s, b = call(f"/rest/v1/coin_ledger?user_id=eq.{uid}&delta=lt.0", None, jwt, "DELETE", REPR)
verdict(s == 200 and j(b) == [], f"DELETE coin_ledger delta<0 → {s} {b[:20]} : 0 ligne effacée")
s, b = call(f"/rest/v1/user_boosters?user_id=eq.{uid}", {"opened_at": None}, jwt, "PATCH", REPR)
verdict(s == 200 and j(b) == [], f"PATCH user_boosters opened_at=null → {s} {b[:20]} : 0 ligne modifiée")
s, b = call("/rest/v1/reward_rules?key=eq.pieces_par_serie", {"value": 999}, jwt, "PATCH", REPR)
verdict(s == 200 and j(b) == [], f"PATCH reward_rules pieces_par_serie=999 → {s} {b[:20]} : 0 ligne modifiée")
s, b = call("/rest/v1/reward_rules?key=eq.pieces_par_serie", None, jwt, "DELETE", REPR)
verdict(s == 200 and j(b) == [], f"DELETE reward_rules pieces_par_serie → {s} {b[:20]} : 0 ligne effacée")
solde_apres = j(call("/rest/v1/rpc/solde_or", {}, jwt)[1])
neg_apres = compte(f"/rest/v1/coin_ledger?user_id=eq.{uid}&delta=lt.0", jwt)
fermes_apres = compte(f"/rest/v1/user_boosters?user_id=eq.{uid}&opened_at=is.null", jwt)
taux_apres = j(call("/rest/v1/reward_rules?select=value&key=eq.pieces_par_serie", None, jwt, "GET")[1])
verdict(solde_avant == solde_apres and isinstance(solde_apres, int), f"solde_or relu : {solde_avant} → {solde_apres} (inchangé)")
verdict(neg_avant == neg_apres and neg_avant >= 0, f"lignes négatives relues : {neg_avant} → {neg_apres} (inchangé)")
verdict(fermes_avant == fermes_apres and fermes_avant >= 0, f"sachets fermés relus : {fermes_avant} → {fermes_apres} (inchangé)")
verdict(taux_avant == taux_apres and taux_apres and taux_apres[0].get("value") == 20,
        f"pieces_par_serie relue : {taux_apres} (toujours 20)")

print("\n[2] les dés sont cachés (20260915090000) — et rien d'autre ne l'est")
s, b = call("/rest/v1/reward_rules?select=key,value&key=like.rare_*", None, jwt, "GET")
verdict(s == 200 and j(b) == [], f"GET reward_rules?key=like.rare_* → {s} {b[:80]} : aucune clé rare_* pour un client")
cles = ["chemin_chapitres", "chemin_noeuds_par_chapitre", "chemin_seances_par_chapitre",
        "chemin_rang_recompense_milieu", "chemin_rang_tresor"]
s, b = call(f"/rest/v1/reward_rules?select=key&key=in.({','.join(cles)})", None, jwt, "GET")
lues = sorted(x.get("key") for x in j(b)) if s == 200 else []
verdict(lues == sorted(cles), f"les 5 chemin_* que l'app lit en direct (SacreServeur.reglesChemin) → {len(lues)} lues")
n_rest = compte("/rest/v1/reward_rules", jwt)
s, b = call("/rest/v1/rpc/regles_annonces", {}, jwt)
n_fn = len(j(b)) if s == 200 and isinstance(j(b), dict) else -1
verdict(n_rest > 0 and n_rest == n_fn, f"reward_rules visibles en REST : {n_rest} = les clés de regles_annonces() : {n_fn} (elle exclut rare_* depuis le 29-08)")
verdict(n_rest > 0 and not any(k.startswith("rare_") for k in (j(b) or {})), "aucune clé rare_* dans regles_annonces()")
s, b = call("/rest/v1/rpc/etat_coffre", {}, jwt)
verdict(s == 200 and j(b).get("prix_booster") == 100 and j(b).get("pieces_par_serie") == 20,
        f"etat_coffre() → prix_booster {j(b).get('prix_booster')}, pieces_par_serie {j(b).get('pieces_par_serie')} : le security definer lit la table (la policy ne le concerne pas)")

print("\n[3] les fonctions mortes ou disputées")
s, b = call("/rest/v1/rpc/solde_noir", {}, jwt)
verdict(s == 404 and "PGRST202" in b, f"solde_noir → {s} PGRST202 : retirée du serveur (wallet_coffre.sql:94)")
s, b = call("/rest/v1/rpc/fonction_inventee_temoin", {}, jwt)
verdict(s == 404 and "PGRST202" in b, f"témoin : fonction_inventee_temoin → {s} PGRST202 (une absente rend 404, donc solde_noir est absente)")
s, b = call("/rest/v1/rpc/solde_argent", {}, jwt)
verdict(s == 200 and isinstance(j(b), int), f"contre-témoin : solde_argent → {s} {b[:10]} (une présente rend 200)")
s, b = call("/rest/v1/rpc/claim_booster", {}, jwt)
verdict(s == 403 and "42501" in b, f"claim_booster → {s} / 42501 : fermée (révoquée), pas absente")
s, b = call("/rest/v1/rpc/solde_or", {}, jwt)
verdict(s == 200 and isinstance(j(b), int), f"solde_or → {s} {b[:10]} : appelable en direct par le compte (grantée, gains_coffre.sql:388) — sans danger, c'est le sien")

print("\n[4] les tables")
s, b = call("/rest/v1/syntheses?select=id&limit=1", None, jwt, "GET")
verdict(s == 404 and "PGRST205" in b, f"syntheses → {s} PGRST205 « Could not find the table » : la table N'EST PAS au serveur")
s, b = call("/rest/v1/workout_facts?select=workout_id&limit=1", None, jwt, "GET")
verdict(s == 200, f"témoin : workout_facts → {s} (une table qui existe rend 200, même vide : {b[:20]})")
s, b = call("/rest/v1/booster_progress?select=user_id&limit=1", None, jwt, "GET")
verdict(s == 404 and "PGRST205" in b, f"booster_progress → {s} PGRST205 : la table dormante est RETIRÉE (20260915100000, sur son mot)")
s, b = call("/rest/v1/reward_rules?select=key&key=like.welcome_*", None, jwt, "GET")
verdict(s == 200 and j(b) == [], f"reward_rules?key=like.welcome_* → {s} {b[:30]} : les trois clés dormantes sont RETIRÉES (20260915100000)")
s, b = call("/rest/v1/rpc/etat_coffre", {}, jwt)
verdict(s == 200 and "retour_disponible" in j(b) and "reste" in j(b) and isinstance(j(b).get("reste"), int),
        f"etat_coffre() rend toujours retour_disponible ({j(b).get('retour_disponible')}) et reste ({j(b).get('reste')}) : le Welcome Back et la jauge du coffre ne dépendaient pas d'eux")
n_cardio = compte("/rest/v1/cardio_phases", jwt)
print(f"    cardio_phases du compte de test : {n_cardio} ligne(s) (information, pas une preuve)")

print("\n[5] les migrations — le dépôt et le serveur disent la même liste")
jeton = f"{REPO}/.secrets/supabase-access-token"
locales = sorted(f.split("_", 1)[0] for f in os.listdir(f"{REPO}/supabase/migrations") if f.endswith(".sql"))
if os.path.exists(jeton) and subprocess.run(["which", "supabase"], capture_output=True).returncode == 0:
    env = dict(os.environ, SUPABASE_ACCESS_TOKEN=open(jeton).read().strip())
    r = subprocess.run(["supabase", "migration", "list", "--linked"], cwd=REPO, env=env,
                       capture_output=True, text=True, timeout=120)
    # ⚠️ mesuré le 15-09 : hors tty le CLI rend du JSON ; avec `-o json` il rend… une table
    # markdown. On lit les deux formes plutôt que de dépendre de l'humeur du CLI.
    m = re.search(r"\{.*\}", r.stdout, re.S)
    lst = j(m.group(0)).get("migrations", []) if m else []
    if not lst:
        for ligne in r.stdout.splitlines():
            cases = [c.strip().strip("`") for c in ligne.split("|")]
            if len(cases) >= 2 and re.fullmatch(r"\d+", cases[0] or cases[1] or ""):
                lst.append({"local": cases[0] or None, "remote": cases[1] or None})
    remotes = sorted(x.get("remote") or "" for x in lst if x.get("remote"))
    attente = [x.get("local") for x in lst if x.get("local") and not x.get("remote")]
    orphelines = [x.get("remote") for x in lst if x.get("remote") and not x.get("local")]
    print(f"    fichiers : {len(locales)} · posées au serveur : {len(remotes)} · dernière : {remotes[-1] if remotes else '—'}")
    verdict(len(lst) > 0 and locales == remotes, f"{len(locales)} fichiers = {len(remotes)} posées, la même liste")
    verdict(not attente, f"rien en attente {attente or ''}")
    verdict(not orphelines, f"rien d'orphelin au serveur {orphelines or ''}")
else:
    print("    ⚠️ sautée : pas de .secrets/supabase-access-token ou pas de CLI — la liste n'est pas comparée")

print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE"))
sys.exit(0 if ok else 1)
