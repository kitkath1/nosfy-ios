#!/usr/bin/env python3
"""
verif_backend_sachet.py — LA PREUVE DE LA MIGRATION 20260830160000, sur le
COMPTE DE TEST (kat44426+woop-forge-test), corps lus, jamais devinés.

    python3 tools/sacre/verif_backend_sachet.py

Ce qu'elle prouve, dans l'ordre du plan (tools/sacre/PLAN-BACKEND-BOOSTER-FIXES.md §6) :
  0. etat_coffre porte `noirs_ouverts` (témoin : la clé absente vaudrait None) ;
  1. claim_booster_legendaire : jsonb, 200 ; rejouée → le MÊME id (la reprise),
     ou un refus MOTIVÉ (argent_insuffisant) — jamais un 500 ;
  2. ouvrir_booster(false) deux fois → le MÊME id tant qu'il n'est pas scellé,
     et boosters_or ne bouge PAS entre les deux (l'ouvert non scellé compte) ;
  3. forge-card avec ce booster_id → une carte, user_boosters.card_id SCELLÉ,
     rejouée → la MÊME carte ; après scellement, ouvrir_booster rend un AUTRE id ;
  4. tirer_noeud_chemin sur un nœud VALIDE encore libre → un tirage, rejoué
     identique (deja_reclame) — pièces (rang 3, chapitre pair) et sachets
     (rang 8) ; les refus : nœud hors chemin → noeud_invalide, mauvaise
     piste → piste_invalide, 200 tous les deux ;
  5. reclamer_noeud_chemin (l'ancienne porte) ne croit plus le client : sur
     un nœud déjà tiré elle rend deja_reclame et le solde d'argent n'a PAS
     pris le million demandé ;
  6. le témoin inventé → 404.
⚠️ Chaque passage consomme des nœuds libres du compte de test (il y en a 8
payants : 3, 21, 39 en pièces ; 8, 12, 17, 26, 30, 35, 44 en sachets). Quand
il n'en reste plus, la partie 4 le DIT au lieu de prouver à côté.
"""
import re, json, urllib.request, urllib.error, sys, os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
src = open(f"{REPO}/Nosfy/Services/Supabase.swift").read()
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', src).group(1)

NOEUDS_PIECES = [3, 21, 39]                    # rang 3, chapitre pair
NOEUDS_SACHETS = [8, 17, 26, 35, 44, 12, 30]   # rang 8 (trésor) + rang 3 impair (lune)


def call(path, body=None, jwt=None, method="POST"):
    h = {"apikey": KEY, "Content-Type": "application/json",
         "Authorization": f"Bearer {jwt or KEY}"}
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode() if body is not None else None,
                                 headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def j(b):
    try:
        return json.loads(b)
    except Exception:
        return {}


ok = True


def verdict(cond, msg):
    global ok
    print(("  ✓ " if cond else "  ✗ ") + msg)
    ok = ok and cond


def coffre(jwt):
    return j(call("/rest/v1/rpc/etat_coffre", {}, jwt)[1])


st, b = call("/auth/v1/token?grant_type=password",
             {"email": "kat44426+woop-forge-test@gmail.com", "password": "forge-test-2026"})
jwt = j(b).get("access_token") if st == 200 else None
print("auth :", st, "(jeton reçu)" if jwt else b[:200])
if not jwt:
    sys.exit("pas de jeton — arrêt")

print("\n[0] etat_coffre")
e0 = coffre(jwt); print("   ", json.dumps(e0))
verdict(e0.get("noirs_ouverts") is not None, "la clé noirs_ouverts existe")

print("\n[1] claim_booster_legendaire (jsonb, reprise ou refus motivé)")
st1, b1 = call("/rest/v1/rpc/claim_booster_legendaire", {}, jwt); print("   #1 :", st1, b1[:200])
st2, b2 = call("/rest/v1/rpc/claim_booster_legendaire", {}, jwt); print("   #2 :", st2, b2[:200])
r1, r2 = j(b1), j(b2)
verdict(st1 == 200 and st2 == 200, "deux 200 (jamais un 500 sur un refus)")
if r1.get("ouvert"):
    verdict(r1.get("booster_id") == r2.get("booster_id") and r2.get("reprise") is True,
            "rejouée → le MÊME légendaire (reprise, aucune 2e pièce d'argent)")
    e1 = coffre(jwt)
    verdict(e1.get("noirs_ouverts") == 1, f"noirs_ouverts = 1 après le claim (lu : {e1.get('noirs_ouverts')})")
else:
    verdict(r1.get("raison") == "argent_insuffisant",
            f"refus motivé : {r1.get('raison')} (argent {r1.get('solde_argent')}, prix {r1.get('prix')})")

print("\n[2] ouvrir_booster(false) — la reprise d'un sachet ouvert non scellé")
ea = coffre(jwt)
sa, ba = call("/rest/v1/rpc/ouvrir_booster", {"p_legendaire": False}, jwt); print("   #1 :", sa, ba[:200])
eb = coffre(jwt)
sb, bb = call("/rest/v1/rpc/ouvrir_booster", {"p_legendaire": False}, jwt); print("   #2 :", sb, bb[:200])
ra, rb = j(ba), j(bb)
verdict(ra.get("ouvert") is True, "un sachet ouvert")
verdict(ra.get("booster_id") == rb.get("booster_id") and rb.get("reprise") is True,
        "rejouée → le MÊME id (reprise) — plus jamais un sachet de plus par relance")
verdict(eb.get("boosters_or") == ea.get("boosters_or"),
        f"boosters_or ne bouge pas tant que le sachet n'est pas scellé ({ea.get('boosters_or')} → {eb.get('boosters_or')})")
orange = ra.get("booster_id")

print("\n[3] forge-card avec booster_id → scellement")
if orange:
    sf, bf = call("/functions/v1/forge-card", {"booster_id": orange}, jwt)
    print("   forge #1 :", sf, bf[:220])
    c1 = j(bf).get("card", {})
    sg, bg = call("/functions/v1/forge-card", {"booster_id": orange}, jwt)
    c2 = j(bg).get("card", {})
    print("   forge #2 :", sg, bg[:220])
    verdict(sf == 200 and c1.get("id"), "une carte forgée")
    verdict(c1.get("id") == c2.get("id"), "rejouée → la MÊME carte (idempotence au sachet)")
    ss, bs = call(f"/rest/v1/user_boosters?id=eq.{orange}&select=id,card_id,opened_at,origine", None, jwt, "GET")
    print("   user_boosters :", ss, bs[:220])
    rows = j(bs)
    row = rows[0] if isinstance(rows, list) and rows else {}
    verdict(row.get("card_id") == c1.get("id"), "le sachet porte SA carte (card_id scellé)")
    ec = coffre(jwt)
    verdict(ec.get("boosters_or") == ea.get("boosters_or") - 1,
            f"scellé → boosters_or descend d'un ({ea.get('boosters_or')} → {ec.get('boosters_or')})")
    sc, bc = call("/rest/v1/rpc/ouvrir_booster", {"p_legendaire": False}, jwt)
    verdict(j(bc).get("booster_id") != orange,
            "après scellement, ouvrir_booster ne rend plus cet id : " + bc[:120])
    # ce sachet-là reste ouvert non scellé : on le scelle aussi pour ne pas
    # laisser le compte de test avec un orphelin de six heures.
    nid = j(bc).get("booster_id")
    if nid:
        sN, bN = call("/functions/v1/forge-card", {"booster_id": nid}, jwt)
        print("   forge du 2e sachet (nettoyage) :", sN, bN[:100])
else:
    verdict(False, "aucun sachet orange sur le compte de test — la partie 3 n'a pas pu être jouée")

print("\n[4] tirer_noeud_chemin — bornes, piste, tirage, rejeu")
sx, bx = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": 9001, "p_pieces": True}, jwt); print("   9001 :", sx, bx[:160])
verdict(sx == 200 and j(bx).get("raison") == "noeud_invalide", "nœud hors chemin → 200 noeud_invalide")
sy, by = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": 3, "p_pieces": False}, jwt); print("   3/sachets :", sy, by[:160])
verdict(sy == 200 and j(by).get("raison") == "piste_invalide", "mauvaise piste → 200 piste_invalide")
sz, bz = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": 0, "p_pieces": True}, jwt)
verdict(sz == 200 and j(bz).get("raison") == "piste_invalide", "nœud ordinaire (rang 0) → piste_invalide")


def premier_libre(noeuds, pieces):
    for n in noeuds:
        s, b = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": n, "p_pieces": pieces}, jwt)
        r = j(b)
        if s == 200 and r.get("deja_reclame") is False and r.get("type"):
            return n, r
        print(f"   nœud {n} déjà pris ou refusé : {s} {b[:100]}")
    return None, None


n1, p1 = premier_libre(NOEUDS_PIECES, True)
if n1 is not None:
    print(f"   pièces nœud {n1} #1 :", json.dumps(p1)[:220])
    sp2, bp2 = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": n1, "p_pieces": True}, jwt); p2 = j(bp2)
    print(f"   pièces nœud {n1} #2 :", sp2, bp2[:220])
    verdict(p1.get("type") == "coins" and p1.get("montant", 0) >= 1, "un tirage pièces")
    verdict(p2.get("deja_reclame") is True and p2.get("montant") == p1.get("montant") and p2.get("monnaie") == p1.get("monnaie"),
            "rejoué → deja_reclame, même montant, même monnaie")
else:
    verdict(False, "plus aucun nœud pièces libre sur le compte de test — le tirage pièces n'a PAS été prouvé ce tour")

n2, q1 = premier_libre(NOEUDS_SACHETS, False)
if n2 is not None:
    print(f"   sachets nœud {n2} #1 :", json.dumps(q1)[:220])
    sq2, bq2 = call("/rest/v1/rpc/tirer_noeud_chemin", {"p_noeud": n2, "p_pieces": False}, jwt); q2 = j(bq2)
    print(f"   sachets nœud {n2} #2 :", sq2, bq2[:220])
    verdict(q1.get("type") == "boosters" and len(q1.get("robes", [])) == 2
            and set(q1.get("robes", [])) <= {"lune", "noire"}, "deux robes valides")
    verdict(q2.get("deja_reclame") is True and q2.get("robes") == q1.get("robes") and q2.get("rarete") == q1.get("rarete"),
            "rejoué → deja_reclame, mêmes robes, même rareté (et le même ORDRE)")
else:
    verdict(False, "plus aucun nœud sachets libre sur le compte de test — le tirage sachets n'a PAS été prouvé ce tour")

print("\n[5] reclamer_noeud_chemin — l'ancienne porte ne croit plus le client")
argent_avant = coffre(jwt).get("solde_argent")
noeud5 = n1 if n1 is not None else 3
s5, b5 = call("/rest/v1/rpc/reclamer_noeud_chemin",
              {"p_noeud": noeud5, "p_pieces": 1000000, "p_monnaie": "silver", "p_boosters": []}, jwt)
print("   ", s5, b5[:200])
argent_apres = coffre(jwt).get("solde_argent")
verdict(s5 == 200 and j(b5).get("deja_reclame") is True, "nœud déjà tiré → deja_reclame (elle a délégué)")
verdict(argent_apres == argent_avant, f"le million d'argent demandé n'est PAS crédité ({argent_avant} → {argent_apres})")

print("\n[6] témoin")
st, _ = call("/rest/v1/rpc/fonction_inventee_temoin", {}, jwt)
verdict(st == 404, f"fonction inventée → {st}")

print("\n" + ("TOUT EST PROUVÉ" if ok else "⚠️ AU MOINS UNE PREUVE MANQUE — lire ci-dessus"))
sys.exit(0 if ok else 1)
