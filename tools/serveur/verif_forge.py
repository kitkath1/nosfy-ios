#!/usr/bin/env python3
"""
verif_forge.py — LA SERRURE DE LA FORGE (15-09) : pas de sachet, pas de carte.
Corps lus, jamais devinés. Un compte JETABLE est créé pour la preuve (par e-mail,
confirmé en SQL par l'API de gestion), puis EFFACÉ par `supprimer-compte`.

    python3 tools/serveur/verif_forge.py

Ce qu'elle prouve (site : m-garde-d-idempotence-serveur → b-fo-serrure) :
  1. un compte ordinaire, POST /functions/v1/forge-card {}            → 400 sachet requis
     idem avec `famille` / `force_new` (les manettes d'atelier)         → 400 (elles sont effacées AVANT)
     avec un booster_id inventé                                         → 404 booster inconnu
     sans jeton                                                          → 401 non connecté
  2. le compte de TEST (be69f505 = FORGE_DEV_USER, l'atelier) : {}     → 200 (il peint le pool, sans sachet — voulu)
     un de SES sachets FERMÉ (opened_at null, card_id null)             → 409 sachet non ouvert
     le chemin normal : ouvrir_booster → forge avec l'id                → 200, carte scellée ; rejoué → la MÊME carte
  ⚠️ Le chemin normal CONSOMME un sachet du compte de test et peut peindre une carte
  neuve (OpenAI) : c'est le prix d'une preuve qui ne suppose rien.
"""
import re, json, base64, secrets, urllib.request, urllib.error, sys, os, time

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
REF = "ytnnyjkramgiqyxdrkcu"
src = open(f"{REPO}/Woop/Services/Supabase.swift").read()
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', src).group(1)
GESTION = open(f"{REPO}/.secrets/supabase-access-token").read().strip()


def call3(path, body=None, jwt=None, method="POST", extra=None, timeout=300):
    h = {"apikey": KEY, "Content-Type": "application/json", "Authorization": f"Bearer {jwt or KEY}"}
    if extra:
        h.update(extra)
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode() if body is not None else None,
                                 headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode(), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(), dict(e.headers)


def call(path, body=None, jwt=None, method="POST", extra=None, timeout=300):
    s, b, _ = call3(path, body, jwt, method, extra, timeout)
    return s, b


def sql(q):
    req = urllib.request.Request(f"https://api.supabase.com/v1/projects/{REF}/database/query",
                                 data=json.dumps({"query": q}).encode(),
                                 headers={"Authorization": f"Bearer {GESTION}", "Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


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


def session(email, mdp):
    s, b = call("/auth/v1/token?grant_type=password", {"email": email, "password": mdp})
    return (j(b).get("access_token"), j(b).get("user", {}).get("id")) if s == 200 else (None, None)


FORGE = "/functions/v1/forge-card"
ZERO = "00000000-0000-0000-0000-000000000000"

print("[0] sans jeton")
s, b = call(FORGE, {}, None)
verdict(s == 401, f"forge-card sans jeton → {s} {b[:60]}")

print("\n[1] un compte ORDINAIRE, jetable")
email = f"kat44426+woop-jetable-{secrets.token_hex(3)}@gmail.com"
mdp = "jetable-" + secrets.token_hex(6)
s, b = call("/auth/v1/signup", {"email": email, "password": mdp})
uid = j(b).get("id") or j(b).get("user", {}).get("id")
verdict(s == 200 and bool(uid), f"signup {email} → {s} · id {str(uid)[:8]}")
sql(f"update auth.users set email_confirmed_at = now() where id = '{uid}'")
jwt, uid2 = session(email, mdp)
verdict(bool(jwt) and uid2 == uid, "session ouverte après confirmation en SQL")
s, b = call(FORGE, {}, jwt)
verdict(s == 400 and j(b).get("error") == "sachet requis", f"forge-card {{}} → {s} {b[:60]} : PAS DE SACHET, PAS DE CARTE")
s, b = call(FORGE, {"famille": "Une Lune", "force_new": True}, jwt)
verdict(s == 400 and j(b).get("error") == "sachet requis", f"forge-card {{famille, force_new}} → {s} {b[:60]} : les manettes ne rouvrent pas la porte")
s, b = call(FORGE, {"booster_id": ZERO}, jwt)
verdict(s == 404 and "inconnu" in j(b).get("error", ""), f"forge-card {{booster_id inventé}} → {s} {b[:60]}")
n_cartes = sql(f"select count(*) as n from public.user_cards where user_id = '{uid}'")[0]["n"]
verdict(n_cartes == 0, f"user_cards du jetable : {n_cartes} (aucune carte n'est née)")
s, b = call("/functions/v1/supprimer-compte", None, jwt, "POST", timeout=60)
verdict(s == 200 and j(b).get("ok") is True, f"supprimer-compte → {s} {b[:70]} (le jetable est effacé)")
reste = sql(f"select count(*) as n from auth.users where id = '{uid}'")[0]["n"]
verdict(reste == 0, f"auth.users du jetable après : {reste}")

print("\n[2] le compte de TEST — l'atelier (FORGE_DEV_USER) et le chemin normal")
jwt, uid = session("kat44426+woop-forge-test@gmail.com", "forge-test-2026")
verdict(bool(jwt), f"session du compte de test {str(uid)[:8]}")
fermes = sql(f"select id from public.user_boosters where user_id = '{uid}' and opened_at is null and card_id is null and origine <> 'legendaire' limit 1")
if fermes:
    s, b = call(FORGE, {"booster_id": fermes[0]["id"]}, jwt)
    verdict(s == 409 and j(b).get("error") == "sachet non ouvert", f"un sachet FERMÉ présenté à la forge → {s} {b[:60]}")
else:
    print("   ⚠️ aucun sachet fermé sur le compte de test : le 409 n'est pas mesuré ce tour")
s, b = call("/rest/v1/rpc/ouvrir_booster", {"p_legendaire": False}, jwt)
bid = j(b).get("booster_id")
verdict(s == 200 and bool(bid), f"ouvrir_booster → {s} booster_id {str(bid)[:8]} (reprise {j(b).get('reprise')})")
t0 = time.time()
s, b = call(FORGE, {"booster_id": bid}, jwt)
c1 = j(b).get("card", {})
verdict(s == 200 and bool(c1.get("id")), f"forge avec le sachet ouvert → {s} carte {str(c1.get('id'))[:8]} « {c1.get('famille')} » {c1.get('rarete')} en {time.time() - t0:.0f} s")
s, b = call(FORGE, {"booster_id": bid}, jwt)
c2 = j(b).get("card", {})
verdict(s == 200 and c2.get("id") == c1.get("id"), f"rejouée → {s} la MÊME carte ({str(c2.get('id'))[:8]}) — idempotente")
scelle = sql(f"select card_id from public.user_boosters where id = '{bid}'")[0]["card_id"]
verdict(scelle == c1.get("id"), f"user_boosters.card_id = la carte ({str(scelle)[:8]}) : scellé")
s, b = call(FORGE, {}, jwt)
verdict(s == 200 and bool(j(b).get("card")), f"l'atelier sans sachet → {s} : FORGE_DEV_USER = le compte de test, il peint le pool sans dépenser (voulu, nommé au déploiement)")

print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE"))
sys.exit(0 if ok else 1)
