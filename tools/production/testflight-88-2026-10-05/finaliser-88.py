"""Build 88 : attend le traitement Apple, rattache les consignes de test, relit l'accès interne.

Aucune invitation, aucune revue externe, aucune notification envoyée. Le groupe
interne « Test Kath » a `hasAccessToAllBuilds` : le 88 y arrive tout seul.
Preuves écrites ici même : traitement-88.json, consignes-88.json, acces-88.json.
"""
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstore_connect import APP_ID, request  # noqa: E402

ROOT = Path(__file__).resolve().parent
VERSION_BUILD = '88'
GROUPE_INTERNE = '4883de10-e441-47b9-bdb3-a0df493cef37'  # « Test Kath »
FICHE_81 = json.loads((ROOT.parent / 'testflight-api-2026-09-19/fiche-testflight.json').read_text())

PREAMBULE = {
    'fr-FR': ("Build 88 — LE CARDIO REFAIT, ET PROFIL / RÉGLAGES QU'ON TIRE.\n\n"
              "1) LE CARDIO (HIIT, tapis lent, escalier) : rien ne part seul. GO scintille ; choisis ta vitesse "
              "avec − et + (un cran par toucher, maintenir pour défiler), puis touche GO. Pendant l'effort, un "
              "seul bouton : Stop (ou Pause). Après un set : Terminer ou Reprendre ; la vitesse réglée en "
              "pause part avec le set suivant. Toucher l'écran en courant n'arrête plus rien.\n\n"
              "2) LA FIN DU HIIT : « Tout est fait. » — le temps total, chaque set (temps · km/h), le max, le "
              "graphe — puis glisse « Retour à la séance ».\n\n"
              "3) PROFIL ET RÉGLAGES : plus de menu en bas ; tire la page vers le bas pour revenir à l'accueil.\n\n"
              "4) LA SÉANCE : la playlist d'un exercice et la feuille d'ajout se ferment en les tirant vers le bas.\n\n"
              "À dire surtout : la vitesse choisie s'enregistre-t-elle bien ? Les boutons répondent-ils en "
              "courant ? Le tirage vers le bas est-il fluide ?\n\n"),
    'en-GB': ("Build 88 — CARDIO REBUILT, AND PULL-TO-CLOSE PROFILE / SETTINGS.\n\n"
              "1) CARDIO (HIIT, slow run, stairs): nothing starts on its own. GO shimmers; set your speed with − "
              "and + (one step per tap, hold to scroll), then tap GO. During the effort, one button: Stop (or "
              "Pause). After a set: Finish or Resume; the speed set during the pause goes with the next set. "
              "Touching the screen while running no longer stops anything.\n\n"
              "2) END OF HIIT: « All done. » — total time, each set (time · km/h), the max, the chart — then "
              "slide « Back to the session ».\n\n"
              "3) PROFILE AND SETTINGS: no menu at the bottom; pull the page down to go home.\n\n"
              "4) THE SESSION: an exercise's set list and the add sheet close when pulled down.\n\n"
              "Tell me above all: is the chosen speed recorded? Do the buttons respond while running? Is the "
              "pull-down smooth?\n\n"),
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
        log('traitement-88.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
        raise SystemExit(f'✗ traitement Apple : {etat}')
    time.sleep(60)
else:
    raise SystemExit('✗ 90 min sans build VALID')
log('traitement-88.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
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
log('consignes-88.json', {'mesure_utc': maintenant(), 'ecriture': journal, 'relecture': relues})
for locale in FICHE_81['betaBuildLocalizations']:
    assert relues.get(locale, '').startswith(PREAMBULE[locale][:40]), f'consigne {locale} non relue'

st, g = request(f'/v1/betaGroups/{GROUPE_INTERNE}/builds?fields[builds]=version&limit=50')
versions = [b['attributes']['version'] for b in (g or {}).get('data', [])]
st2, d = request(f'/v1/builds/{build_id}/buildBetaDetail')
detail = (d or {}).get('data', {}).get('attributes', {})
st3, t = request(f'/v1/betaGroups/{GROUPE_INTERNE}/betaTesters?fields[betaTesters]=state,firstName')
testeurs = [(x['attributes'].get('firstName'), x['attributes'].get('state')) for x in (t or {}).get('data', [])]
log('acces-88.json', {'mesure_utc': maintenant(), 'groupe': 'Test Kath', 'http': [st, st2, st3],
                      'builds_du_groupe': versions, 'etat_build': detail, 'testeurs': testeurs})
print(f"groupe Test Kath : builds {versions} · {detail} · testeurs {testeurs}", flush=True)
print('✅ 88 VALID, consignes rattachées, accès interne relu — RIEN d\'autre envoyé', flush=True)
