"""Build 90 : attend le traitement Apple, rattache les consignes de test, relit l'accès interne.

Aucune invitation, aucune revue externe, aucune notification envoyée. Le groupe
interne « Test Kath » a `hasAccessToAllBuilds` : le 90 y arrive tout seul.
Preuves écrites ici même : traitement-90.json, consignes-90.json, acces-90.json.
"""
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstore_connect import APP_ID, request  # noqa: E402

ROOT = Path(__file__).resolve().parent
VERSION_BUILD = '90'
GROUPE_INTERNE = '4883de10-e441-47b9-bdb3-a0df493cef37'  # « Test Kath »
FICHE_81 = json.loads((ROOT.parent / 'testflight-api-2026-09-19/fiche-testflight.json').read_text())

PREAMBULE = {
    'fr-FR': ("Build 90 — LE HIIT PAYÉ, PLUS D'ÉCRAN NOIR, LA COULEUR DES FLAMMES.\n\n"
              "1) LE HIIT RAPPORTE DÈS 10 KM/H : un effort de 20 s à 10 km/h ou plus suffit. Regarde tes pièces à la "
              "fin de la séance.\n\n"
              "2) TIRER LE CADRAN VERS LE BAS : pendant le repos, tire le cadran, regarde ta séance, puis reviens. "
              "Le cadran doit être là, jamais un écran noir.\n\n"
              "3) LA PAGE DE SÉANCE : une série par exercice au départ, et un bouton Stop en haut à droite pour "
              "terminer quand tu veux.\n\n"
              "4) LE CADRAN : touche-le pendant l'arrivée pour passer l'animation ; le petit bouton réglages en haut à "
              "droite change la couleur des flammes (rouge, orange, jaune, vert, noir).\n\n"
              "À dire surtout : as-tu eu tes pièces pour le HIIT ? Un écran noir, quelque part ?\n\n"),
    'en-GB': ("Build 90 — HIIT PAID, NO MORE BLACK SCREEN, FLAME COLOURS.\n\n"
              "1) HIIT PAYS FROM 10 KM/H: one 20 s effort at 10 km/h or more is enough. Check your coins at the end "
              "of the session.\n\n"
              "2) PULL THE DIAL DOWN: during the rest, pull the dial down, look at your session, then go back. The "
              "dial must be there, never a black screen.\n\n"
              "3) THE SESSION PAGE: one set per exercise to start, and a Stop button at the top right to finish "
              "whenever you want.\n\n"
              "4) THE DIAL: tap it during the arrival to skip the animation; the small settings button at the top "
              "right changes the flame colour (red, orange, yellow, green, black).\n\n"
              "Tell me above all: did you get your coins for the HIIT? Any black screen?\n\n"),
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
        log('traitement-90.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
        raise SystemExit(f'✗ traitement Apple : {etat}')
    time.sleep(60)
else:
    raise SystemExit('✗ 90 min sans build VALID')
log('traitement-90.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
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
log('consignes-90.json', {'mesure_utc': maintenant(), 'ecriture': journal, 'relecture': relues})
for locale in FICHE_81['betaBuildLocalizations']:
    assert relues.get(locale, '').startswith(PREAMBULE[locale][:40]), f'consigne {locale} non relue'

st, g = request(f'/v1/betaGroups/{GROUPE_INTERNE}/builds?fields[builds]=version&limit=50')
versions = [b['attributes']['version'] for b in (g or {}).get('data', [])]
st2, d = request(f'/v1/builds/{build_id}/buildBetaDetail')
detail = (d or {}).get('data', {}).get('attributes', {})
st3, t = request(f'/v1/betaGroups/{GROUPE_INTERNE}/betaTesters?fields[betaTesters]=state,firstName')
testeurs = [(x['attributes'].get('firstName'), x['attributes'].get('state')) for x in (t or {}).get('data', [])]
log('acces-90.json', {'mesure_utc': maintenant(), 'groupe': 'Test Kath', 'http': [st, st2, st3],
                      'builds_du_groupe': versions, 'etat_build': detail, 'testeurs': testeurs})
print(f"groupe Test Kath : builds {versions} · {detail} · testeurs {testeurs}", flush=True)
print('✅ 90 VALID, consignes rattachées, accès interne relu — RIEN d\'autre envoyé', flush=True)
