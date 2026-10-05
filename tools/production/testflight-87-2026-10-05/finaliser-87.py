"""Build 87 : attend le traitement Apple, rattache les consignes de test, relit l'accès interne.

Aucune invitation, aucune revue externe, aucune notification envoyée. Le groupe
interne « Test Kath » a `hasAccessToAllBuilds` : le 87 y arrive tout seul.
Preuves écrites ici même : traitement-87.json, consignes-87.json, acces-87.json.
"""
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstore_connect import APP_ID, request  # noqa: E402

ROOT = Path(__file__).resolve().parent
VERSION_BUILD = '87'
GROUPE_INTERNE = '4883de10-e441-47b9-bdb3-a0df493cef37'  # « Test Kath »
FICHE_81 = json.loads((ROOT.parent / 'testflight-api-2026-09-19/fiche-testflight.json').read_text())

PREAMBULE = {
    'fr-FR': ("Build 87 — LA SÉANCE À LA APPLE, ET NOSFY SANS RÉSEAU.\n\n"
              "1) SANS RÉSEAU (le plus important) : en sous-sol, en mode avion ou avec un réseau faible, "
              "Nosfy doit s'ouvrir sur l'accueil et laisser faire toute une séance — jamais l'écran noir "
              "d'erreur. Puis le réseau revenu : la séance part toute seule.\n\n"
              "2) TA SÉANCE : la page vide (le +, « Compose ta séance », « Ta dernière séance · Refaire »), "
              "l'ajout par zone, les exercices en lignes fines avec leurs flammes. Toucher une ligne ouvre ses "
              "séries ; glisser une série ou un exercice vers la gauche le supprime ; « Ajouter une série ». "
              "Les exercices se font dans l'ordre que tu veux.\n\n"
              "3) LE CADRAN : le Stop plus gros, « Passer l'animation » sous lui, l'onglet Séries (ajouter, "
              "glisser pour supprimer), et le cadran qu'on tire vers le bas comme Spotify pour revenir à la séance.\n\n"
              "4) LE HIIT AU ▶ : GO scintille, rien ne tourne avant ton ▶. Stop : « SET 1 TERMINÉ », le chrono "
              "à 0:00, la vitesse à 0 ; ▶ reprend. Le temps total en haut. Maintenir le bouton termine.\n\n"
              "5) GAINAGE ET EXERCICES AU SOL : le chrono seul, sans reps ni kilos.\n\n"
              "À dire surtout : as-tu vu l'écran noir d'erreur une seule fois ? Le tirage du cadran saute-t-il ? "
              "Le téléphone chauffe-t-il ?\n\n"),
    'en-GB': ("Build 87 — THE APPLE-STYLE SESSION, AND NOSFY WITHOUT A NETWORK.\n\n"
              "1) NO NETWORK (most important): underground, in airplane mode or on a weak signal, Nosfy must "
              "open on the home screen and let you do a whole session — never the black error screen. Then, "
              "once the network is back, the session syncs on its own.\n\n"
              "2) YOUR SESSION: the empty page (the +, « Build your session », « Your last session · Redo »), "
              "adding by body zone, exercises as thin rows with their flames. Tap a row to see its sets; swipe "
              "a set or an exercise left to delete it; « Add a set ». Exercises can be done in any order.\n\n"
              "3) THE DIAL: a bigger Stop, « Skip animation » under it, the Sets tab (add, swipe to delete), "
              "and the dial you pull down like Spotify to go back to the session.\n\n"
              "4) HIIT ON ▶: GO shimmers, nothing runs before your ▶. Stop: « SET 1 DONE », the clock at 0:00, "
              "speed at 0; ▶ resumes. Total time at the top. Hold the button to finish.\n\n"
              "5) PLANKS AND FLOOR EXERCISES: the timer only, no reps or weight.\n\n"
              "Tell me above all: did you see the black error screen even once? Does pulling the dial stutter? "
              "Does the phone heat up?\n\n"),
}


def log(nom, obj):
    (ROOT / nom).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')


def maintenant():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


debut = time.time()
build = None
while time.time() - debut < 90 * 60:
    st, r = request(f'/v1/builds?filter[app]={APP_ID}&filter[version]={VERSION_BUILD}'
                    '&fields[builds]=version,processingState,uploadedDate,expired,usesNonExemptEncryption')
    rows = (r or {}).get('data', []) if st == 200 else []
    build = next((b for b in rows if b['attributes']['version'] == VERSION_BUILD), None)
    etat = build['attributes']['processingState'] if build else 'ABSENT'
    print(f"{datetime.now():%H:%M:%S} build {VERSION_BUILD} : {etat}", flush=True)
    if build and etat == 'VALID':
        break
    if build and etat in ('FAILED', 'INVALID'):
        log('traitement-87.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
        raise SystemExit(f'✗ traitement Apple : {etat}')
    time.sleep(60)
else:
    raise SystemExit('✗ 90 min sans build VALID')
log('traitement-87.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
build_id = build['id']

st, r = request(f'/v1/builds/{build_id}/betaBuildLocalizations')
existantes = {x['attributes']['locale']: x['id'] for x in (r or {}).get('data', [])}
journal = []
for locale, attrs in FICHE_81['betaBuildLocalizations'].items():
    texte = {'whatsNew': (PREAMBULE.get(locale, '') + attrs['whatsNew'])[:4000]}
    if locale in existantes:
        st, r = request('/v1/betaBuildLocalizations/' + existantes[locale], {'data': {
            'type': 'betaBuildLocalizations', 'id': existantes[locale], 'attributes': texte}}, 'PATCH')
    else:
        st, r = request('/v1/betaBuildLocalizations', {'data': {
            'type': 'betaBuildLocalizations', 'attributes': {'locale': locale, **texte},
            'relationships': {'build': {'data': {'type': 'builds', 'id': build_id}}}}}, 'POST')
    journal.append({'locale': locale, 'http': st, 'reponse': r})
    print(f"consignes {locale} : HTTP {st}", flush=True)
st, r = request(f'/v1/builds/{build_id}/betaBuildLocalizations')
relues = {x['attributes']['locale']: x['attributes']['whatsNew'] for x in (r or {}).get('data', [])}
log('consignes-87.json', {'mesure_utc': maintenant(), 'ecriture': journal, 'relecture': relues})
for locale in FICHE_81['betaBuildLocalizations']:
    assert relues.get(locale, '').startswith(PREAMBULE[locale][:40]), f'consigne {locale} non relue'

st, g = request(f'/v1/betaGroups/{GROUPE_INTERNE}/builds?fields[builds]=version&limit=50')
versions = [b['attributes']['version'] for b in (g or {}).get('data', [])]
st2, d = request(f'/v1/builds/{build_id}/buildBetaDetail')
detail = (d or {}).get('data', {}).get('attributes', {})
st3, t = request(f'/v1/betaGroups/{GROUPE_INTERNE}/betaTesters?fields[betaTesters]=state,firstName')
testeurs = [(x['attributes'].get('firstName'), x['attributes'].get('state')) for x in (t or {}).get('data', [])]
log('acces-87.json', {'mesure_utc': maintenant(), 'groupe': 'Test Kath', 'http': [st, st2, st3],
                      'builds_du_groupe': versions, 'etat_build': detail, 'testeurs': testeurs})
print(f"groupe Test Kath : builds {versions} · {detail} · testeurs {testeurs}", flush=True)
print('✅ 87 VALID, consignes rattachées, accès interne relu — RIEN d\'autre envoyé', flush=True)
