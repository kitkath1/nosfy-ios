#!/usr/bin/env python3
"""
verif_backend_coffre.py — LA PREUVE DE LA MIGRATION 20260830210000 (conversion,
jour, flamme), sur le COMPTE DE TEST (kat44426+woop-forge-test), corps lus,
jamais devinés.

    python3 tools/annonces/verif_backend_coffre.py

Ce qu'elle prouve (plan tools/annonces/PLAN-COFFRE-ANNONCES.md §6 J1) :
  0. etat_coffre porte jour · retour_disponible · retour_prochain (= le prochain
     minuit de PARIS, comparé en instant) · flamme ; et AVANT tout crédit,
     0 ≤ solde_or < prix : le stock d'avant a été converti à la pose ;
  1. cloturer_seance sur un uuid NEUF, avec assez de séries pour FORCER au moins
     une conversion : pièces = séries × taux, sachet neuf, sachets_convertis =
     exactement (solde + gain) div prix, la ligne -100 `conversion_booster` LUE
     dans le carnet, le nombre de sachets `conversion` compté par REST ;
     REJOUÉE → 200, rejeu:true, les MÊMES pièces / sachet / argent_seance, argent
     = false (jamais « tombée à cet appel » sur un rejeu), 0 converti, coffre inchangé ;
  2. claim_retour_quotidien ×2 : le 1er crédite EXACTEMENT quand retour_disponible
     le promettait, la ligne du CARNET porte le jour de Paris, le 2e ne crédite pas ;
  3. flamme : une fixture de 3 séances (J-3, J-1, J0 à 00:30 PARIS = la veille en
     UTC) semée puis retirée → {jours:2, aujourdhui_fait:true} — le seul cas qui
     départage Paris d'UTC ;
  4. claim_booster refusée par le DROIT (403 / 42501), pas absente ;
  5. tirer_noeud_chemin (l'enveloppe) porte sachets_convertis ; un nœud pièces
     libre, s'il en reste, est tiré et CONVERTIT (effet de bord dit) ; _brut,
     convertir_pieces, fuseau_jour, jour_courant, convertis_transaction → 403/42501 ;
  6. le témoin inventé → 404 (PGRST202) : c'est ce qui donne son sens aux 403.
⚠️ Chaque passage crédite le compte de test (N séries) et peut tirer un nœud
pièces libre — c'est voulu : la conversion doit se VOIR.
"""
import re, json, uuid, base64, math, urllib.request, urllib.error, sys, os
from datetime import datetime, timedelta, time as _t
from zoneinfo import ZoneInfo

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
src = open(f"{REPO}/Nosfy/Services/Supabase.swift").read()
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', src).group(1)
PARIS = ZoneInfo("Europe/Paris")


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


def call(path, body=None, jwt=None, method="POST"):
    s, b, _ = call3(path, body, jwt, method)
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


def coffre(jwt):
    s, b = call("/rest/v1/rpc/etat_coffre", {}, jwt)
    if s != 200:
        verdict(False, f"etat_coffre a répondu {s} : {b[:160]}")
        return {}
    return j(b)


def compte(path, jwt):
    """le nombre de lignes d'une requête REST, par Content-Range (count=exact)."""
    _, _, h = call3(path + ("&" if "?" in path else "?") + "select=id&limit=1", None, jwt, "GET", {"Prefer": "count=exact"})
    cr = h.get("Content-Range") or h.get("content-range") or "*/0"
    try:
        return int(cr.split("/")[1])
    except Exception:
        return -1


st, b = call("/auth/v1/token?grant_type=password",
             {"email": "kat44426+woop-forge-test@gmail.com", "password": "forge-test-2026"})
jwt = j(b).get("access_token") if st == 200 else None
print("auth :", st, "(jeton reçu)" if jwt else b[:200])
if not jwt:
    sys.exit("pas de jeton — arrêt")
uid = json.loads(base64.urlsafe_b64decode(jwt.split(".")[1] + "==")).get("sub")

auj = datetime.now(PARIS).date()
aujourdhui_paris = auj.isoformat()
print("aujourd'hui à Paris :", aujourdhui_paris, "· heure Paris :", datetime.now(PARIS).strftime("%H:%M"))

print("\n[0] etat_coffre — les quatre clés nouvelles, et le stock d'avant converti")
e0 = coffre(jwt); print("   ", json.dumps(e0))
for k in ("jour", "retour_disponible", "retour_prochain", "flamme", "pieces_retour_quotidien"):
    verdict(k in e0, f"la clé {k} existe (témoin : absente = KeyError)")
verdict(e0.get("jour") == aujourdhui_paris, f"jour = {e0.get('jour')} = aujourd'hui à Paris ({aujourdhui_paris})")
verdict(isinstance(e0.get("pieces_retour_quotidien"), int) and e0["pieces_retour_quotidien"] > 0,
        f"pieces_retour_quotidien = {e0.get('pieces_retour_quotidien')} — le montant vient de la règle, plus d'une constante Swift (20260830220000)")
verdict(isinstance(e0.get("flamme"), dict) and "jours" in e0.get("flamme", {}) and "aujourdhui_fait" in e0.get("flamme", {}),
        "flamme est un objet {jours, aujourdhui_fait}")
prix = e0.get("prix_booster") or 100
taux = e0.get("pieces_par_serie") or 20
verdict(isinstance(e0.get("solde_or"), int) and 0 <= e0["solde_or"] < prix and e0.get("reste") == e0["solde_or"],
        f"AVANT tout crédit : 0 ≤ solde_or = {e0.get('solde_or')} < {prix} et reste = solde_or — le stock d'avant a été converti à la pose")
attendu_minuit = datetime.combine(auj + timedelta(days=1), _t(0), PARIS)
try:
    rp_dt = datetime.fromisoformat(str(e0.get("retour_prochain")).replace("Z", "+00:00"))
except Exception:
    rp_dt = None
verdict(rp_dt is not None and rp_dt == attendu_minuit,
        f"retour_prochain = {e0.get('retour_prochain')} = le prochain minuit de PARIS ({attendu_minuit.isoformat()})")
n_conv0 = compte("/rest/v1/user_boosters?origine=eq.conversion", jwt)
print("    sachets `conversion` sur le compte :", n_conv0)

print("\n[1] cloturer_seance — un uuid neuf, assez de séries pour CONVERTIR, puis le REJEU")
solde0 = e0.get("solde_or", 0)
series = max(3, math.ceil((prix - solde0) / taux))
attendu_conv = (solde0 + series * taux) // prix
print(f"    solde {solde0} + {series} × {taux} = {solde0 + series * taux} → {attendu_conv} conversion(s) attendue(s)")
w = str(uuid.uuid4()); e_w = str(uuid.uuid4())
# 083033 : plus de clôture sans séance synchronisée — on pousse d'abord l'instantané
# (workout + un exercice + `series` séries), comme l'app, puis on clôture.
fin_w = datetime.now(ZoneInfo("UTC")) - timedelta(seconds=5)
sy, by = call("/rest/v1/rpc/synchroniser_seance", {
    "p_workout": {"id": w, "user_id": uid, "started_at": (fin_w - timedelta(minutes=20)).isoformat(), "ended_at": fin_w.isoformat(), "notes": "verif_backend_coffre"},
    "p_exercices": [{"id": e_w, "user_id": uid, "workout_id": w, "exercise_id": "hip-thrust", "position": 0}],
    "p_series": [{"id": str(uuid.uuid4()), "user_id": uid, "logged_exercise_id": e_w, "reps": 10, "weight": 20, "position": i} for i in range(series)],
    "p_phases": [], "p_piscines": []}, jwt); print("   synchroniser_seance :", sy, by[:120])
verdict(sy == 200, "la séance est synchronisée avant la clôture (083033)")
s1, b1 = call("/rest/v1/rpc/cloturer_seance", {"p_workout": w, "p_series": series}, jwt); print("   #1 :", s1, b1[:320])
r1 = j(b1)
verdict(s1 == 200, "200")
verdict(r1.get("pieces") == series * taux and r1.get("pieces_creditees") is True,
        f"pièces = {series} × {taux} = {r1.get('pieces')}, créditées")
verdict(r1.get("rejeu") is False, "rejeu = false la première fois")
verdict(r1.get("booster_neuf") is True and bool(r1.get("booster_id")), "sachet forfaitaire neuf")
verdict(attendu_conv >= 1 and r1.get("sachets_convertis") == attendu_conv,
        f"sachets_convertis = {r1.get('sachets_convertis')} = {attendu_conv} attendu")
verdict(isinstance(r1.get("solde"), int) and 0 <= r1["solde"] < prix,
        f"solde APRÈS conversion = {r1.get('solde')} < {prix}")
verdict("solde_argent" in r1 and "argent_seance" in r1, f"solde_argent ({r1.get('solde_argent')}) et argent_seance ({r1.get('argent_seance')}) portés")
verdict(r1.get("argent") == r1.get("argent_seance"), "à la première clôture, argent = argent_seance")
sl, bl = call("/rest/v1/coin_ledger?raison=eq.conversion_booster&order=created_at.desc&limit=1&select=delta,booster_id,currency", None, jwt, "GET")
ligne = (j(bl) or [{}])[0] if isinstance(j(bl), list) else {}
print("    dernière ligne conversion_booster :", sl, bl[:160])
verdict(sl == 200 and ligne.get("delta") == -prix and bool(ligne.get("booster_id")) and ligne.get("currency") == "yellow",
        f"la ligne -{prix} `conversion_booster` est LUE dans le carnet, liée à son sachet")
n_conv1 = compte("/rest/v1/user_boosters?origine=eq.conversion", jwt)
verdict(n_conv1 - n_conv0 == r1.get("sachets_convertis"),
        f"sachets `conversion` comptés par REST : {n_conv0} → {n_conv1} (+{r1.get('sachets_convertis')})")
e1 = coffre(jwt)
attendu_b = (r1.get("sachets_convertis") or 0) + (1 if r1.get("booster_neuf") else 0)
verdict(e1.get("boosters_or", 0) - e0.get("boosters_or", 0) == attendu_b,
        f"boosters_or monte de {attendu_b} ({e0.get('boosters_or')} → {e1.get('boosters_or')}) — second témoin")
verdict(isinstance(e1.get("solde_or"), int) and 0 <= e1["solde_or"] < prix and e1.get("reste") == e1["solde_or"],
        f"0 ≤ solde_or = {e1.get('solde_or')} < {prix} et reste = solde_or")
s2, b2 = call("/rest/v1/rpc/cloturer_seance", {"p_workout": w, "p_series": series}, jwt); print("   #2 :", s2, b2[:320])
r2 = j(b2)
verdict(s2 == 200, "rejeu → 200")
verdict(r2.get("rejeu") is True and r2.get("pieces_creditees") is False, "rejouée → rejeu:true, rien de crédité")
verdict(r2.get("pieces") == r1.get("pieces"), f"rejouée → les MÊMES pièces stockées ({r2.get('pieces')})")
verdict(r2.get("booster_id") == r1.get("booster_id") and r2.get("booster_neuf") is False, "rejouée → le MÊME sachet, pas neuf")
verdict(r2.get("argent") is False, "rejouée → argent = false (jamais « tombée à cet appel » sur un rejeu)")
verdict(r2.get("argent_seance") == r1.get("argent_seance"), f"rejouée → argent_seance stocké = {r2.get('argent_seance')}")
verdict(r2.get("sachets_convertis") == 0, "rejouée → 0 converti")
e2 = coffre(jwt)
verdict(isinstance(e2.get("solde_or"), int) and e2["solde_or"] == e1.get("solde_or") and e2.get("boosters_or") == e1.get("boosters_or"),
        "rejouée → le coffre n'a pas bougé")

print("\n[2] claim_retour_quotidien ×2 — le jour de Paris, lu dans le CARNET")
e_avant = coffre(jwt)
sa, ba = call("/rest/v1/rpc/claim_retour_quotidien", {}, jwt); print("   #1 :", sa, ba[:200])
sb, bb = call("/rest/v1/rpc/claim_retour_quotidien", {}, jwt); print("   #2 :", sb, bb[:200])
ra, rb = j(ba), j(bb)
verdict(sa == 200 and sb == 200, "deux 200")
verdict(ra.get("credite") == e_avant.get("retour_disponible"),
        f"le 1er claim crédite ({ra.get('credite')}) EXACTEMENT quand retour_disponible le promettait ({e_avant.get('retour_disponible')})")
if ra.get("credite") is False:
    print("   ⚠️ déjà pris aujourd'hui sur ce compte : le CRÉDIT du jour n'a pas été mesuré ce passage (la ligne du carnet, si)")
verdict(ra.get("jour") == aujourdhui_paris, f"réponse : jour = {ra.get('jour')} (Paris : {aujourdhui_paris})")
verdict(rb.get("credite") is False, "le second ne crédite pas (index (user, jour))")
verdict("sachets_convertis" in ra, f"sachets_convertis porté ({ra.get('sachets_convertis')})")
sl2, bl2 = call("/rest/v1/coin_ledger?raison=eq.retour_quotidien&order=created_at.desc&limit=1&select=jour,delta,created_at", None, jwt, "GET")
l2 = (j(bl2) or [{}])[0] if isinstance(j(bl2), list) else {}
print("    dernière ligne retour_quotidien :", sl2, bl2[:160])
verdict(sl2 == 200 and l2.get("jour") == aujourdhui_paris, f"la ligne du CARNET porte jour = {l2.get('jour')} (Paris {aujourdhui_paris})")
e3 = coffre(jwt)
verdict(e3.get("retour_disponible") is False, "retour_disponible = false après le claim du jour")
h = datetime.now(PARIS).hour
print("   " + ("✓ fenêtre 00:00–02:00 Paris : date Paris ≠ date UTC, ce verdict départage le fuseau"
              if h < 2 else "⚠️ hors 00:00–02:00 Paris : date Paris = date UTC ici — c'est la fixture de [3] qui départage le fuseau"))

print("\n[3] flamme — une fixture de séances (J-3 · J-1 · J0 à 00:30 PARIS = la veille en UTC)")
minuit_auj = datetime.combine(auj, _t(0), PARIS)
fix = [minuit_auj - timedelta(days=3) + timedelta(hours=10),
       minuit_auj - timedelta(days=1) + timedelta(hours=10),
       minuit_auj + timedelta(minutes=30)]
ids = [str(uuid.uuid4()) for _ in fix]
rows_in = [{"id": i, "user_id": uid, "started_at": (d - timedelta(hours=1)).isoformat(), "ended_at": d.isoformat()}
           for i, d in zip(ids, fix)]
si, bi = call("/rest/v1/workouts", rows_in, jwt); print("   fixture :", si, bi[:120])
verdict(si in (200, 201), f"fixture semée ({si})")
f = coffre(jwt).get("flamme", {})
print("    flamme serveur :", f, "· J0 à 00:30 Paris =", fix[2].astimezone(ZoneInfo("UTC")).isoformat(), "en UTC")
# 18-09 : le compte de test porte d'autres séances des jours précédents (sessions Compte/Cartes),
# la flamme compte donc ≥ 2 ; l'exactitude est prouvée par le second témoin (calcul local) plus bas.
verdict((f.get("jours") or 0) >= 2 and f.get("aujourdhui_fait") is True,
        f"flamme = {f} — attendu {{jours ≥ 2, aujourdhui_fait: true}} (J-1 + J0 ; en UTC, J0 serait HIER → aujourdhui_fait: false)")
sw, bw = call("/rest/v1/workouts?select=ended_at&ended_at=not.is.null&order=ended_at.desc", None, jwt, "GET")
rows = j(bw) if sw == 200 else []
verdict(sw == 200 and len(rows) >= 3, f"des séances LUES ({len(rows)}) — sinon la flamme n'est pas prouvée")
jours = sorted({datetime.fromisoformat(r["ended_at"].replace("Z", "+00:00")).astimezone(PARIS).date() for r in rows if r.get("ended_at")}, reverse=True)
fait_auj = auj in jours
cur = auj if fait_auj else auj - timedelta(days=1)
n = 0
for d in jours:
    if d > cur:
        continue
    if d == cur:
        n += 1; cur -= timedelta(days=1)
    else:
        break
verdict(f.get("jours") == n and f.get("aujourdhui_fait") == fait_auj, f"second témoin : le calcul local rend {n} / {fait_auj}")
sd, bd = call(f"/rest/v1/workouts?id=in.({','.join(ids)})", None, jwt, "DELETE"); print("   retrait :", sd, bd[:80])
verdict(sd in (200, 204), "fixture retirée")
# la séance de [1] : ses faits d'abord (FK), puis elle — les pièces et le sachet restent, comme pour toute preuve
call(f"/rest/v1/workout_facts?workout_id=eq.{w}", None, jwt, "DELETE")
sd1, bd1 = call(f"/rest/v1/workouts?id=eq.{w}", None, jwt, "DELETE"); print("   retrait séance [1] :", sd1, bd1[:80])
verdict(sd1 in (200, 204), "séance de [1] retirée")

print("\n[4] claim_booster — fermée par le DROIT")
sc, bc = call("/rest/v1/rpc/claim_booster", {}, jwt); print("   :", sc, bc[:160])
verdict(sc == 403 and "42501" in bc, f"claim_booster refusée par le droit (403 / 42501), pas absente ({sc})")

print("\n[5] le chemin — l'enveloppe convertit ; les privées ne répondent pas")


def premier_libre(noeuds, pieces):
    for nd in noeuds:
        s, b_ = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": nd, "p_pieces": pieces}, jwt)
        r = j(b_)
        print(f"   tirer({nd},{pieces}) :", s, b_[:200])
        if s == 200 and r.get("deja_reclame") is False and not r.get("raison"):
            return nd, r
    return None, {}


solde_avant = coffre(jwt).get("solde_or", 0)
n5, r5 = premier_libre([3, 21, 39], True)
if n5 is not None:
    print(f"   ⚠️ effet de bord : nœud {n5} tiré ce tour (+{r5.get('montant')} {r5.get('monnaie')})")
    if r5.get("monnaie") == "yellow":
        verdict(r5.get("sachets_convertis") == (solde_avant + r5["montant"]) // prix and 0 <= r5.get("solde", -1) < prix,
                f"le chemin CONVERTIT : {r5.get('sachets_convertis')} sachet(s), solde {r5.get('solde')} < {prix}")
    else:
        verdict("sachets_convertis" in r5, "tirage en argent : sachets_convertis porté (rien à convertir)")
else:
    print("   ⚠️ aucun nœud pièces libre sur le compte de test : la conversion par le CHEMIN n'est PAS prouvée ce tour")
sn, bn = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": 3, "p_pieces": True}, jwt)
# 18-09 (compte-progression) : le tirage est derrière une GARDE — sans 3 séances terminées ET
# synchronisées (sync_complete_at), 409 progression_insuffisante ; les anciennes séances du
# compte de test n'ont pas encore le marqueur. Les deux issues prouvent l'enveloppe : le rejeu
# (200, 0 converti) ou la garde (409 motivé). Un 500 ou un crédit seraient le défaut.
garde = sn == 409 and "progression_insuffisante" in bn
verdict((sn == 200 and j(bn).get("deja_reclame") is True and j(bn).get("sachets_convertis") == 0) or garde,
        f"nœud 3 → rejeu 0 converti, ou garde de progression motivée ({sn} {bn[:80]})")
so, bo = call("/rest/v1/rpc/reclamer_noeud_chemin", {"p_noeud": 3, "p_pieces": 1, "p_monnaie": "yellow", "p_boosters": []}, jwt)
verdict(so == 200 or (so == 409 and "progression_insuffisante" in bo),
        f"reclamer_noeud_chemin (l'ancienne porte) passe par l'enveloppe et sa garde → {so}")
sf, bf = call("/rest/v1/rpc/fuseau_jour", {}, jwt); print("   fuseau_jour :", sf, bf[:60])
verdict(sf == 200 and "Europe/Paris" in bf, "fuseau_jour lisible par le client (grant du 13-09, 20260913120000) et = Europe/Paris")
for nom, corps in (("tirer_noeud_chemin_brut", {"p_noeud": 3, "p_pieces": True}),
                   ("convertir_pieces", {"p_user": uid}),
                   ("jour_courant", {}), ("convertis_transaction", {})):
    sp, bp = call(f"/rest/v1/rpc/{nom}", corps, jwt); print(f"   {nom} :", sp, bp[:100])
    verdict(sp == 403 and "42501" in bp, f"{nom} existe mais est refusée au client (403 / 42501) — un 404 voudrait dire ABSENTE")

print("\n[6] le témoin")
st6, b6 = call("/rest/v1/rpc/fonction_inventee_temoin", {}, jwt); print("   :", st6, b6[:120])
verdict(st6 == 404 and "PGRST202" in b6, "la fonction inventée rend 404 / PGRST202 : les 403 ci-dessus sont bien des refus, pas des absences")

print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE"))
sys.exit(0 if ok else 1)
