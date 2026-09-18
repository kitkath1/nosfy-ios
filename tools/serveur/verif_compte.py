#!/usr/bin/env python3
"""Parcours Compte réel sur deux comptes jetables, sans toucher la Forge.

Crée des identités e-mail confirmées via l'API admin (aucun e-mail envoyé),
teste les RPC avec leurs sessions ordinaires, puis efface seulement ces comptes.
Ce banc ne valide pas la feuille Apple ni le rendu sur iPhone.
"""
from pathlib import Path
import json
import re
import secrets
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

REPO = Path(__file__).resolve().parents[2]
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"',
                (REPO / "Nosfy/Services/Supabase.swift").read_text()).group(1)
ADMIN = (REPO / ".secrets/supabase-service-role").read_text().strip()
FLOW = "--flow" in sys.argv
INTEGRITE = "--integrite" in sys.argv


def appel(path, body=None, jwt=None, method="POST", admin=False):
    key = ADMIN if admin else KEY
    headers = {"apikey": key, "Content-Type": "application/json",
               "Authorization": "Bearer " + (jwt or key), "Prefer": "return=representation"}
    req = urllib.request.Request(URL + path, method=method, headers=headers,
                                 data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.loads(response.read() or "null")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or "null")


def rpc(nom, jwt, body=None):
    status, obj = appel("/rest/v1/rpc/" + nom, body or {}, jwt)
    if status != 200:
        raise RuntimeError(f"RPC {nom}: HTTP {status}")
    return obj


def check(condition, label):
    global succes, echecs
    print(("PASS " if condition else "FAIL ") + label, flush=True)
    if condition:
        succes += 1
    else:
        echecs += 1


crees = []
succes = echecs = 0
try:
    comptes = []
    for _ in range(2):
        email = f"woop-compte-{uuid.uuid4()}@example.invalid"
        password = secrets.token_urlsafe(30)
        status, user = appel("/auth/v1/admin/users", {
            "email": email, "password": password, "email_confirm": True,
            "app_metadata": {"woop_qa": "compte-2026-09-17"},
        }, admin=True)
        if status not in (200, 201) or not user.get("id"):
            raise RuntimeError(f"Création du compte QA: HTTP {status}")
        uid = user["id"]
        crees.append(uid)
        status, session = appel("/auth/v1/token?grant_type=password", {"email": email, "password": password})
        if status != 200:
            raise RuntimeError(f"Connexion QA: HTTP {status}")
        comptes.append((uid, email, password, session))
    uid, email, password, session = comptes[0]
    jwt = session["access_token"]
    autre = comptes[1][3]["access_token"]
    p = rpc("profil", jwt)
    check(p["existe"] is False and p["onboarding_termine"] is False and p["seances"] == 0,
          "nouveau compte : profil incomplet, zéro séance")
    check(rpc("home", jwt)["premiere_fois"] is False, "avant Nosfy : première arrivée non déclenchée")
    for nom in ("profil", "definir_profil", "marquer_visite_home"):
        status, _ = appel("/rest/v1/rpc/" + nom, {})
        check(status in (401, 403), f"{nom} interdit sans session")
    refus = rpc("definir_profil", jwt, {"p_prenom": "   ", "p_langue": "fr"})
    check(refus.get("ok") is False and refus.get("raison") == "prenom_requis",
          "prénom vide refusé")
    check(rpc("profil", jwt)["existe"] is False, "prénom refusé : aucune inscription partielle")
    refus = rpc("definir_profil", jwt, {"p_prenom": "QA", "p_objectif_hebdo": 99})
    check(refus.get("ok") is False and refus.get("raison") == "hors_bornes",
          "objectif invalide refusé par definir_profil")
    check(rpc("profil", jwt)["existe"] is False, "objectif refusé : aucune inscription partielle")
    p = rpc("definir_profil", jwt, {"p_langue": "fr", "p_prenom": "  Camille QA  ",
                                   "p_but": "force", "p_objectif_hebdo": 4})
    check(p.get("ok") is True and p["onboarding_termine"] is True and p["prenom"] == "Camille QA"
          and p["langue"] == "fr" and p["objectif_hebdo"] == 4, "Nosfy : profil et objectif confirmés")
    date = p["onboarding_termine_at"]
    p2 = rpc("definir_profil", jwt, {"p_but": "forme"})
    check(p2["onboarding_termine_at"] == date and p2["prenom"] == p["prenom"]
          and p2["langue"] == "fr" and p2["objectif_hebdo"] == 4,
          "rejeu idempotent : date, prénom, langue et objectif conservés")
    home = rpc("home", jwt)
    check(home["premiere_fois"] is True and home["seances_total"] == 0
          and home["langue"] == "fr" and home["prenom"] == "Camille QA" and home["objectif"] == 4,
          "home neuve dans la langue et au prénom du profil")
    coffre = rpc("etat_coffre", jwt)
    check(coffre["retour_disponible"] is False and coffre["solde_or"] == 0,
          "compte neuf : zéro pièce, aucun Welcome Back")
    if FLOW:
        check(rpc("ma_collection", jwt) == [], "compte neuf : collection vide")
        check(coffre["solde_argent"] == 0 and coffre["boosters_or"] == 0,
              "compte neuf : aucun argent ni sachet")
        regles = rpc("regles_annonces", jwt)
        check(isinstance(regles, dict) and bool(regles),
              "nouveau compte : règles des annonces accessibles")
    refus = rpc("claim_retour_quotidien", jwt)
    check(refus.get("credite") is False and refus.get("raison") == "premiere_seance_requise",
          "Welcome Back refusé avant la première séance")
    visite = rpc("marquer_visite_home", jwt)
    visite2 = rpc("marquer_visite_home", jwt)
    check(visite["visite_home"] is True and visite["visite_home_le"] == visite2["visite_home_le"],
          "visite mémorisée une seule fois")
    workout = str(uuid.uuid4())
    fin = datetime.now(timezone.utc)
    status, rows = appel("/rest/v1/workouts", {"id": workout, "user_id": uid,
                        "started_at": (fin - timedelta(minutes=10)).isoformat(),
                        "ended_at": fin.isoformat(), "notes": "QA compte temporaire"}, jwt)
    check(status == 201 and len(rows) == 1, "séance QA écrite avec la session du nouveau compte")
    check(rpc("home", jwt)["premiere_fois"] is False and rpc("profil", jwt)["seances"] == 1,
          "première séance : le compte quitte l’état nouveau")
    if FLOW:
        exercice = str(uuid.uuid4())
        status, _ = appel("/rest/v1/logged_exercises", {
            "id": exercice, "workout_id": workout, "user_id": uid,
            "exercise_id": "hip-thrust", "position": 0}, jwt)
        check(status == 201, "première séance : exercice écrit")
        serie = str(uuid.uuid4())
        status, _ = appel("/rest/v1/strength_sets", {
            "id": serie, "logged_exercise_id": exercice, "user_id": uid,
            "reps": 10, "weight": 5, "position": 0}, jwt)
        check(status == 201, "première séance : série écrite")
        rpc("synchroniser_seance", jwt, {
            "p_workout": {"id": workout, "started_at": (fin-timedelta(minutes=10)).isoformat(), "ended_at": fin.isoformat()},
            "p_exercices": [{"id": exercice, "workout_id": workout, "exercise_id": "hip-thrust", "position": 0}],
            "p_series": [{"id": serie, "logged_exercise_id": exercice, "reps": 10, "weight": 5, "position": 0}],
            "p_phases": [], "p_piscines": []})
        cloture = rpc("cloturer_seance", jwt, {"p_workout": workout, "p_series": 1})
        check(cloture.get("pieces_creditees") is True and cloture.get("pieces", 0) > 0,
              "première clôture : pièces créditées")
        check(bool(cloture.get("booster_id")) and cloture.get("booster_neuf") is True,
              "première clôture : sachet personnel attribué")
        check(cloture.get("faits") == [],
              "première séance seule : aucun record ni double inventé pour les stories")
        gagne = rpc("etat_coffre", jwt)
        check(gagne["solde_or"] > 0 and gagne["boosters_or"] > 0,
              "coffre du nouveau compte : gains retrouvés")
        rejoue = rpc("cloturer_seance", jwt, {"p_workout": workout, "p_series": 1})
        apres = rpc("etat_coffre", jwt)
        check(rejoue.get("rejeu") is True and apres["solde_or"] == gagne["solde_or"]
              and apres["boosters_or"] == gagne["boosters_or"],
              "rejeu de clôture : aucun gain doublé")
        autre_coffre = rpc("etat_coffre", autre)
        check(autre_coffre["solde_or"] == 0 and autre_coffre["boosters_or"] == 0,
              "isolation : le second compte ne reçoit aucun gain du premier")
    status, autres = appel(f"/rest/v1/profils?user_id=eq.{uid}&select=user_id", jwt=autre, method="GET")
    check(status == 200 and autres == [], "isolation : le second compte ne lit pas le premier")
    status, autres = appel(f"/rest/v1/profils?user_id=eq.{uid}", {"prenom": "Intrus"}, autre, "PATCH")
    check(status == 200 and autres == [] and rpc("profil", jwt)["prenom"] == "Camille QA",
          "isolation : le second compte ne modifie pas le premier")
    status, _ = appel("/auth/v1/logout?scope=global", {}, jwt)
    check(status in (200, 204), "déconnexion serveur")
    status, _ = appel("/auth/v1/token?grant_type=refresh_token", {"refresh_token": session["refresh_token"]})
    check(status in (400, 401, 403), "refresh révoqué après déconnexion")
    status, session = appel("/auth/v1/token?grant_type=password", {"email": email, "password": password})
    check(status == 200, "reconnexion du compte existant")
    jwt = session["access_token"]
    p = rpc("profil", jwt)
    check(p["onboarding_termine"] and p["visite_home"] and p["prenom"] == "Camille QA",
          "reconnexion : profil et visite retrouvés, Nosfy déjà terminé")
    status, rows = appel(f"/rest/v1/workouts?user_id=eq.{uid}&select=id", jwt=jwt, method="GET")
    check(status == 200 and [r["id"] for r in rows] == [workout], "reconnexion : séance retrouvée")
    if FLOW:
        retrouve = rpc("etat_coffre", jwt)
        check(retrouve["solde_or"] == gagne["solde_or"]
              and retrouve["boosters_or"] == gagne["boosters_or"],
              "reconnexion : pièces et sachets retrouvés")
    if INTEGRITE:
        # Une clôture ne doit pas payer une séance absente. Un seul essai,
        # sur le compte jetable de ce banc, effacé juste après.
        avant = rpc("etat_coffre", jwt)
        status, cloture = appel("/rest/v1/rpc/cloturer_seance", {
            "p_workout": str(uuid.uuid4()), "p_series": 1}, jwt)
        apres = rpc("etat_coffre", jwt)
        check(apres["solde_or"] == avant["solde_or"]
              and apres["boosters_or"] == avant["boosters_or"],
              "intégrité : une séance inexistante ne crédite ni pièce ni sachet")
        print("Mesure intégrité : " + json.dumps({
            "http": status, "pieces_annoncees": cloture.get("pieces") if isinstance(cloture, dict) else None,
            "raison_faits": cloture.get("faits_raison") if isinstance(cloture, dict) else None,
            "solde_avant": avant["solde_or"], "solde_apres": apres["solde_or"],
            "sachets_avant": avant["boosters_or"], "sachets_apres": apres["boosters_or"],
        }, ensure_ascii=False), flush=True)
    status, suppression = appel("/functions/v1/supprimer-compte", {}, jwt)
    check(status == 200 and suppression.get("ok") is True and suppression.get("user_id") == uid,
          "suppression par la fonction utilisée dans l’app")
    status, _ = appel(f"/auth/v1/admin/users/{uid}", admin=True, method="GET")
    check(status == 404, "compte absent après suppression")
    tables = ["profils", "user_prefs", "exercices_choisis", "workouts", "apple_jetons"]
    if FLOW:
        tables += ["logged_exercises", "strength_sets", "coin_ledger", "user_boosters", "user_cards", "workout_facts"]
    for table in tables:
        status, rows = appel(f"/rest/v1/{table}?user_id=eq.{uid}&select=user_id", admin=True, method="GET")
        check(status == 200 and rows == [], f"cascade : {table} vide après suppression")
    status, _ = appel("/auth/v1/token?grant_type=refresh_token", {"refresh_token": session["refresh_token"]})
    check(status in (400, 401, 403), "compte supprimé : impossible de renouveler la session")
finally:
    for uid in crees:
        status, _ = appel(f"/auth/v1/admin/users/{uid}", admin=True, method="DELETE")
        if status not in (200, 204, 404):
            raise RuntimeError(f"Nettoyage QA à reprendre pour {uid}: HTTP {status}")
    print(f"Comptes QA nettoyés : {len(crees)}. Aucun compte existant ni carte modifié.", flush=True)
print(f"Compte : {succes} PASS, {echecs} FAIL", flush=True)
raise SystemExit(1 if echecs else 0)
