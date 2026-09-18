#!/usr/bin/env python3
"""
verif_cardio.py — L'ÉCONOMIE DU CARDIO (15-09) : le barème du serveur rend-il les montants du
tableau ? Compte de test, corps lus. Sème des séances (par REST, comme l'app pousse), les
clôture, compare à PLAN-ECONOMIE-CARDIO.md §2, puis LES RETIRE. ⚠️ Chaque clôture crédite le
compte de test (c'est voulu : la clôture doit être la vraie).

    python3 tools/serveur/verif_cardio.py

Ce qu'elle prouve (site : b-fn-pieces-cardio-seance, b-rg-cardio-*, b-tb-piscine-longueurs,
b-fn-cloturer-seance, b-tb-coin-ledger) :
  1. les sept séances HIIT du §2.1 → pieces_cardio = le montant du tableau (130, 255, 270, 120,
     240, 260 ; une séance sans effort au seuil est payée comme un tapis modéré : 45) ; escalier 67 / 85 / 100 ; tapis 60 ; piscine 20×N plafonné à 300 ;
  2. une séance MIXTE (muscu + HIIT) : pieces = séries×20 (cloturer_seance_brut) ET pieces_cardio ;
  3. une séance vide → 0, pas de sachet ;
  4. le rejeu : cloturer_seance ×2, pieces_cardio 0 au second, le solde ne bouge pas d'un cardio ;
  5. le sachet SANS série : une séance 100 % cardio donne un booster (origine seance) ;
  6. pieces_cardio_seance sans jeton → 401 ; puis nettoyage.
"""
import re, json, uuid, urllib.request, urllib.error, sys, os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
REF = "ytnnyjkramgiqyxdrkcu"
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', open(f"{REPO}/Nosfy/Services/Supabase.swift").read()).group(1)
GESTION = open(f"{REPO}/.secrets/supabase-access-token").read().strip()
PARIS = ZoneInfo("Europe/Paris")


def call(path, body=None, jwt=None, method="POST", extra=None):
    h = {"apikey": KEY, "Content-Type": "application/json", "Authorization": f"Bearer {jwt or KEY}"}
    if extra:
        h.update(extra)
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
semees = []
maintenant = datetime.now(PARIS).replace(second=0, microsecond=0)


def seance(exos, series_muscu=0, il_y_a_h=2):
    """exos: liste de (exercise_id, phases[(kind, seconds, speed)] , longueurs|None)"""
    wid = str(uuid.uuid4())
    debut = maintenant - timedelta(hours=il_y_a_h)
    assert call("/rest/v1/workouts", {"id": wid, "user_id": uid, "started_at": debut.isoformat(),
                                      "ended_at": (debut + timedelta(minutes=40)).isoformat(), "notes": "verif_cardio"}, jwt)[0] == 201
    pos = 0
    if series_muscu > 0:
        eid = str(uuid.uuid4())
        call("/rest/v1/logged_exercises", {"id": eid, "workout_id": wid, "user_id": uid, "exercise_id": "hip-thrust", "position": pos}, jwt); pos += 1
        call("/rest/v1/strength_sets", [{"id": str(uuid.uuid4()), "logged_exercise_id": eid, "user_id": uid, "reps": 10, "weight": 40, "position": i} for i in range(series_muscu)], jwt)
    for ex, phases, longueurs in exos:
        eid = str(uuid.uuid4())
        call("/rest/v1/logged_exercises", {"id": eid, "workout_id": wid, "user_id": uid, "exercise_id": ex, "position": pos}, jwt); pos += 1
        if phases:
            call("/rest/v1/cardio_phases", [{"id": str(uuid.uuid4()), "logged_exercise_id": eid, "user_id": uid,
                                             "kind": k, "seconds": sec, "speed": v, "incline": 0, "cycle_index": 0, "position": i}
                                            for i, (k, sec, v) in enumerate(phases)], jwt)
        if longueurs is not None:
            call("/rest/v1/piscine_longueurs", {"logged_exercise_id": eid, "user_id": uid, "longueurs": longueurs, "metres_par_longueur": 25}, jwt)
    semees.append(wid)
    return wid


def hiit(reps, effort_s, effort_kmh, recup_s, recup_kmh=9):
    ph = []
    for _ in range(reps):
        ph.append(("Sprint", effort_s, effort_kmh))
        ph.append(("Repos", recup_s, recup_kmh))
    return ph


def cloture(wid, series=0):
    s, b = call("/rest/v1/rpc/cloturer_seance", {"p_workout": wid, "p_series": series}, jwt)
    return s, j(b)


try:
    print("\n[1] le HIIT — les sept lignes du tableau §2.1")
    cas = [
        ("×12 : 30 s à 15, 1 min à 9",        hiit(12, 30, 15.0, 60), 130),
        ("10 × 1 min à 17, 1 min de récup",   hiit(10, 60, 17.0, 60), 255),
        ("8 × 1:30 à 17, 45 s de récup",      hiit(8, 90, 17.0, 45), 270),
        ("6 sprints de 20 s à 19, 40 s récup",hiit(6, 20, 19.0, 40), 120),
        ("20 min à 15 d'un trait",            [("Sprint", 1200, 15.0)], 240),
        ("30 min à 15 d'un trait",            [("Sprint", 1800, 15.0)], 260),
        ("5 min à 12 (jamais au-dessus de 15)", [("Accélération", 300, 12.0)], 45),  # payé comme un tapis : 30 + 5×12/4
    ]
    for nom, phases, attendu in cas:
        wid = seance([("hiit-tapis", phases, None)])
        s, r = cloture(wid)
        pc = r.get("pieces_cardio")
        note = "" if attendu != 45 else " (repli tapis : 30 + 5×12/4)"
        verdict(s == 200 and pc == attendu, f"HIIT {nom} → {pc} (attendu {attendu}){note}")

    print("\n[2] l'escalier (§2.2) et le tapis (§2.3)")
    for nom, ex, phases, attendu in [
        ("10 min niveau 7",  "escalier", [("Accélération", 600, 7)], 67),
        ("20 min niveau 7",  "escalier", [("Accélération", 1200, 7)], 85),
        ("20 min niveau 10", "escalier", [("Accélération", 1200, 10)], 100),
        ("20 min à 6 km/h",  "tapis-lent", [("Accélération", 1200, 6.0)], 60),
    ]:
        wid = seance([(ex, phases, None)])
        s, r = cloture(wid)
        verdict(s == 200 and r.get("pieces_cardio") == attendu, f"{ex} {nom} → {r.get('pieces_cardio')} (attendu {attendu})")

    print("\n[3] la piscine (§2.4) — 20 la longueur, plafond 300")
    for longueurs, attendu in [(10, 200), (40, 300)]:
        wid = seance([("piscine", None, longueurs)])
        s, r = cloture(wid)
        verdict(s == 200 and r.get("pieces_cardio") == attendu, f"piscine {longueurs} longueurs → {r.get('pieces_cardio')} (attendu {attendu})")

    print("\n[4] une séance MIXTE — muscu + HIIT")
    wid = seance([("hiit-tapis", hiit(10, 60, 17.0, 60), None)], series_muscu=4)
    s, r = cloture(wid, series=4)
    verdict(s == 200 and r.get("pieces") == 80, f"les 4 séries payées par _brut : pieces {r.get('pieces')} (attendu 80)")
    verdict(r.get("pieces_cardio") == 255, f"le HIIT payé en plus : pieces_cardio {r.get('pieces_cardio')} (attendu 255)")
    verdict(r.get("pieces_total") == 80 + 255 + (r.get("bonus_progres") or 0), f"pieces_total {r.get('pieces_total')} = 80 + 255 + bonus {r.get('bonus_progres')}")

    print("\n[5] une séance vide, et le sachet sans série")
    wid = seance([("hiit-tapis", [("Accélération", 60, 8.0)], None)])   # aucun effort, court : 0
    s, r = cloture(wid)
    verdict(s == 200 and r.get("pieces_cardio") == 0, f"séance sans effort → pieces_cardio {r.get('pieces_cardio')} (attendu 0)")
    verdict(r.get("booster_id") is None or r.get("booster_neuf") in (False, None), f"pas de sachet neuf sur une séance à 0 (booster_neuf {r.get('booster_neuf')})")
    wid = seance([("hiit-tapis", hiit(8, 90, 17.0, 45), None)])         # 270, sans série
    s, r = cloture(wid, series=0)
    verdict(s == 200 and r.get("sachet_cardio") is True and r.get("booster_id"), f"séance 100 % cardio (270), aucune série → sachet accordé (sachet_cardio {r.get('sachet_cardio')})")

    print("\n[6] le rejeu")
    s, r2 = cloture(wid, series=0)
    verdict(s == 200 and r2.get("cardio_rejeu") is True and r2.get("pieces_cardio") == 270, f"rejeu → cardio_rejeu {r2.get('cardio_rejeu')}, pieces_cardio {r2.get('pieces_cardio')} (le stocké)")
    n_lignes = sql(f"select count(*) as n from public.coin_ledger where user_id = '{uid}' and raison = 'cardio_seance' and workout_id = '{wid}'")[0]["n"]
    verdict(n_lignes == 1, f"une seule ligne cardio_seance pour la séance après le rejeu ({n_lignes})")

    print("\n[7] la porte")
    s, b = call("/rest/v1/rpc/pieces_cardio_seance", {"p_workout": semees[0]}, None)
    verdict(s == 401, f"pieces_cardio_seance sans jeton → {s}")
finally:
    print("\n[nettoyage] les séances semées, leurs faits, leurs longueurs, leurs lignes de journal")
    for wid in semees:
        # ⚠️ La clôture crédite le compte de test (cardio_seance + bonus_progres) : on efface
        # AUSSI ces lignes, sinon chaque passage gonfle le solde du compte de test à vie
        # (payé 15-09 : 45 lignes orphelines retrouvées et balayées à la main).
        sql(f"delete from public.coin_ledger where user_id = '{uid}' and raison in ('cardio_seance','bonus_progres') and workout_id = '{wid}'")
        sql(f"delete from public.piscine_longueurs where logged_exercise_id in (select id from public.logged_exercises where workout_id = '{wid}')")
        sql(f"delete from public.workout_facts where workout_id = '{wid}'")
        sql(f"delete from public.workouts where id = '{wid}'")
    reste = sql(f"select count(*) as n from public.workouts where user_id = '{uid}' and notes = 'verif_cardio'")[0]["n"]
    orphelines = sql(f"select count(*) as n from public.coin_ledger l where l.user_id = '{uid}' and l.raison in ('cardio_seance','bonus_progres') and not exists (select 1 from public.workouts w where w.id = l.workout_id)")[0]["n"]
    print(f"   séances verif_cardio restantes : {reste} · lignes cardio orphelines : {orphelines}")

print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE"))
sys.exit(0 if ok else 1)
