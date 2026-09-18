#!/usr/bin/env python3
"""État production en lecture seule : agrégats du profil Apple au prénom connu.

Aucun jeton, e-mail, contenu de séance ou identifiant complet n'est imprimé.
Aucune donnée n'est modifiée ; aucune opération n'est faite sur l'iPhone.
"""
from pathlib import Path
import json
import urllib.request
from datetime import datetime, timezone

REPO = Path(__file__).resolve().parents[2]
REF = "ytnnyjkramgiqyxdrkcu"
TOKEN = (REPO / ".secrets/supabase-access-token").read_text().strip()

def lire(path, query=None):
    req = urllib.request.Request("https://api.supabase.com/v1/projects/" + REF + path,
        headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json"},
        data=None if query is None else json.dumps({"query": query}).encode(),
        method="GET" if query is None else "POST")
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read())

project = lire("")
auth = lire("/config/auth")
secrets = {s["name"] for s in lire("/secrets")}
query = """
select left(u.id::text, 8) as compte,
  exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='apple') as apple,
  (select count(*) from public.workouts w where w.user_id=u.id) as seances_total,
  (select count(*) from public.workouts w where w.user_id=u.id and w.ended_at is not null) as seances_finies,
  (select count(*) from public.workouts w where w.user_id=u.id and w.ended_at is null) as seances_ouvertes,
  (select count(*) from public.workouts w where w.user_id=u.id and w.ended_at is not null
    and extract(epoch from w.ended_at-w.started_at)<60) as finies_moins_une_minute,
  (select count(*) from public.strength_sets s where s.user_id=u.id) as series,
  (select count(*) from public.cardio_phases c where c.user_id=u.id) as phases_cardio,
  (select count(*) from public.user_cards c where c.user_id=u.id) as cartes,
  (select count(*) from public.user_boosters b where b.user_id=u.id and b.card_id is null) as sachets_non_scelles,
  (select coalesce(sum(l.delta),0) from public.coin_ledger l where l.user_id=u.id and l.currency='yellow') as solde_or,
  (select coalesce(sum(l.delta),0) from public.coin_ledger l where l.user_id=u.id and l.currency='black') as solde_argent
from auth.users u where exists (select 1 from public.profils p where p.user_id=u.id and lower(p.prenom) in ('kathryn', 'kiki style'))
"""
account = lire("/database/query", query)
identifie = len(account) == 1 and account[0]["apple"]
print(json.dumps({
    "lu_le_utc": datetime.now(timezone.utc).isoformat(),
    "projet": {k: project.get(k) for k in ("status", "region")},
    "auth": {k: auth.get(k) for k in ("external_apple_enabled", "external_apple_client_id", "disable_signup",
        "external_email_enabled", "external_anonymous_users_enabled", "jwt_exp", "security_refresh_token_rotation_enabled")},
    "secrets_apple_presents": {k: k in secrets for k in ("APPLE_KEY_ID", "APPLE_TEAM_ID", "APPLE_PRIVATE_KEY")},
    "compte_existant": account[0] if identifie else {"identification": "à confirmer", "candidats": len(account)},
    "identification": "Profil au prénom Kathryn/Kiki Style et identité Apple ; correspondance avec la session iPhone non vérifiée.",
    "limite": "Lecture du serveur uniquement ; le nombre local sur iPhone n'est pas mesuré. Aucun nettoyage."
}, ensure_ascii=False, indent=2))
