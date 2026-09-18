#!/usr/bin/env python3
"""
verif_faits.py — LES FAITS SE CALCULENT À LA CLÔTURE (15-09, étape 4a) :
`calculer_faits_seance()` et l'enveloppe `cloturer_seance` qui rend `faits`.
Compte de test, corps lus. Sème trois séances (par REST, comme l'app pousse), les
clôture, puis LES RETIRE (séances + faits). ⚠️ Chaque clôture crédite le compte de test
(séries × 20 + un sachet) : c'est voulu, la clôture doit être la vraie.

    python3 tools/serveur/verif_faits.py

Ce qu'elle prouve (site : b-fn-calculer-faits, b-fn-poser-faits, b-rg-top, b-fn-cloturer-seance) :
  1. hier 6 séries (volume 300) puis aujourd'hui 8 séries (volume 480) : cloturer_seance
     rend faits = [top_muscu] — mesure `volume_kg` (480 > 300, mieux battue que 8 > 6),
     valeur / precedent lus ; la ligne est dans workout_facts ;
  2. rejouée : les MÊMES faits, rejeu true, toujours UNE ligne (l'estampillage) ;
  3. une seconde séance aujourd'hui (4 séries) : faits = [double_jour] avec
     detail {heures: [HH:MM, HH:MM], minutes} — et PAS top_muscu (4 < 8) ;
  4. une troisième du jour : pas de second double_jour (index partiel) ;
  5. une séance JAMAIS poussée : cloturer_seance répond 200, faits [], raison seance_inconnue
     — la clôture ne casse jamais pour un fait ;
  6. calculer_faits_seance sans jeton → 401 ; cloturer_seance_brut → 403 (privée).
"""
import re, json, uuid, urllib.request, urllib.error, sys, os
from datetime import datetime, timedelta, timezone
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


def semer(debut, minutes, series, poids):
    """une séance de fonte poussée comme l'app le fait : workouts → logged_exercises → strength_sets"""
    wid = str(uuid.uuid4()); eid = str(uuid.uuid4())
    fin = debut + timedelta(minutes=minutes)
    s1, b1 = call("/rest/v1/workouts", {"id": wid, "user_id": uid, "started_at": debut.isoformat(), "ended_at": fin.isoformat(), "notes": "verif_faits"}, jwt)
    s2, b2 = call("/rest/v1/logged_exercises", {"id": eid, "workout_id": wid, "user_id": uid, "exercise_id": "hip-thrust", "position": 0}, jwt)
    lignes = [{"id": str(uuid.uuid4()), "logged_exercise_id": eid, "user_id": uid, "reps": 10, "weight": poids, "position": i} for i in range(series)]
    s3, b3 = call("/rest/v1/strength_sets", lignes, jwt)
    assert s1 == 201 and s2 == 201 and s3 == 201, (s1, b1[:80], s2, b2[:80], s3, b3[:80])
    semees.append(wid)
    return wid


def cloture(wid, series):
    s, b = call("/rest/v1/rpc/cloturer_seance", {"p_workout": wid, "p_series": series}, jwt)
    return s, j(b)


def faits_en_base(wid):
    return sql(f"select kind, mesure, valeur, precedent, detail from public.workout_facts where workout_id = '{wid}' order by kind")


try:
    maintenant = datetime.now(PARIS).replace(second=0, microsecond=0)
    print("\n[1] hier 6 séries × 10 × 5 kg (volume 300), aujourd'hui 8 × 10 × 6 kg (volume 480)")
    w_hier = semer(maintenant - timedelta(days=1, hours=2), 40, 6, 5.0)
    w_auj = semer(maintenant - timedelta(hours=3), 45, 8, 6.0)
    s, r = cloture(w_hier, 6)
    verdict(s == 200 and r.get("faits") == [] , f"clôture d'hier → {s}, faits {r.get('faits')} (une seule séance dans la fenêtre : rien à battre)")
    s, r = cloture(w_auj, 8)
    f = r.get("faits") or []
    verdict(s == 200 and len(f) == 1 and f[0]["kind"] == "top_muscu" and f[0]["mesure"] == "volume_kg",
            f"clôture d'aujourd'hui → {s}, faits {[(x['kind'], x.get('mesure')) for x in f]}")
    verdict(f and float(f[0]["valeur"]) == 480 and float(f[0]["precedent"]) == 300, f"valeur {f and f[0]['valeur']} · précédent {f and f[0]['precedent']} (480 > 300)")
    verdict(r.get("pieces") == 160 and "booster_id" in r, f"la clôture elle-même n'a pas bougé : pieces {r.get('pieces')}, booster {str(r.get('booster_id'))[:8]}")
    base = faits_en_base(w_auj)
    verdict(len(base) == 1 and base[0]["kind"] == "top_muscu", f"workout_facts : {len(base)} ligne(s) pour la séance ({base and base[0]['kind']})")

    print("\n[2] rejouée")
    s, r2 = cloture(w_auj, 8)
    verdict(s == 200 and r2.get("rejeu") is True and r2.get("faits") == f, f"rejeu → {s}, rejeu {r2.get('rejeu')}, les mêmes faits")
    verdict(len(faits_en_base(w_auj)) == 1, "toujours UNE ligne : l'estampillage tient")

    print("\n[3] une seconde séance aujourd'hui (4 séries)")
    w_auj2 = semer(maintenant - timedelta(minutes=50), 30, 4, 6.0)
    s, r3 = cloture(w_auj2, 4)
    f3 = r3.get("faits") or []
    kinds = [x["kind"] for x in f3]
    verdict(s == 200 and kinds == ["double_jour"], f"faits {kinds} (pas de top : 4 séries < 8)")
    d = f3[0].get("detail", {}) if f3 else {}
    verdict(len(d.get("heures", [])) == 2 and isinstance(d.get("minutes"), int) and d["minutes"] == 75,
            f"detail {d} — deux heures, {d.get('minutes')} minutes en tout (45 + 30)")

    print("\n[4] une troisième du jour")
    w_auj3 = semer(maintenant - timedelta(minutes=10), 5, 1, 6.0)
    s, r4 = cloture(w_auj3, 1)
    verdict(s == 200 and (r4.get("faits") or []) == [], f"faits {r4.get('faits')} : pas de second « deuxième » (index partiel)")

    print("\n[5] une séance jamais poussée")
    s, r5 = cloture(str(uuid.uuid4()), 3)
    verdict(s == 200 and r5.get("faits") == [] and r5.get("faits_raison") == "seance_inconnue",
            f"cloturer_seance → {s}, faits [], raison {r5.get('faits_raison')} — la clôture paie quand même ({r5.get('pieces')} pièces)")

    print("\n[6] les portes")
    s, b = call("/rest/v1/rpc/calculer_faits_seance", {"p_workout": w_auj}, None)
    verdict(s == 401, f"calculer_faits_seance sans jeton → {s}")
    s, b = call("/rest/v1/rpc/cloturer_seance_brut", {"p_workout": w_auj, "p_series": 8}, jwt)
    verdict(s == 403 and "42501" in b, f"cloturer_seance_brut (privée) → {s} / 42501")
    s, b = call("/rest/v1/rpc/calculer_faits_seance", {"p_workout": w_auj}, jwt)
    verdict(s == 200 and j(b).get("rejeu") is True, f"calculer_faits_seance seule, rejouée → {s} rejeu {j(b).get('rejeu')}")
finally:
    print("\n[nettoyage] les séances semées et leurs faits")
    for wid in semees:
        sql(f"delete from public.workout_facts where workout_id = '{wid}'")
        sql(f"delete from public.workouts where id = '{wid}'")
    reste = sql(f"select count(*) as n from public.workouts where user_id = '{uid}' and notes = 'verif_faits'")[0]["n"]
    print(f"   séances verif_faits restantes : {reste} · (les pièces et sachets de clôture restent, comme pour toute preuve)")

print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE"))
sys.exit(0 if ok else 1)
