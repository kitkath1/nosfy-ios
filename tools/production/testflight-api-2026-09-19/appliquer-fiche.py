"""Applique les textes relus ; ne soumet aucune version et n'invite personne."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstore_connect import APP_ID, request

ROOT = Path(__file__).resolve().parent
PLAN = json.loads((ROOT / 'fiche-testflight.json').read_text())
INFO = 'e3bf6eb6-8d9e-46b7-a653-3f810a66e870'
VERSION = '604aaea9-5e11-4dff-ac24-76b3b455eb53'
JOURNAL = []
CONFIG = json.loads((Path.home() / '.appstoreconnect/nosfy-api.json').read_text())


def call(path, body=None, method='GET'):
    status, result = request(path, body, method)
    row = {'method': method, 'path': path, 'status': status}
    if status >= 400:
        row['errors'] = result.get('errors')
    JOURNAL.append(row)
    (ROOT / 'ecriture-fiches.json').write_text(
        json.dumps(JOURNAL, ensure_ascii=False, indent=2) + '\n')
    print(method, path, status, flush=True)
    if status >= 400:
        raise RuntimeError(json.dumps(result, ensure_ascii=False))
    return (result or {}).get('data')


def locales(path, kind, relation, parent_id, parent_type, values):
    existing = {r['attributes']['locale']: r['id'] for r in call(path)}
    for locale, attrs in values.items():
        if locale in existing:
            call('/v1/' + kind + '/' + existing[locale], {'data': {
                'type': kind, 'id': existing[locale], 'attributes': attrs}}, 'PATCH')
        else:
            call('/v1/' + kind, {'data': {'type': kind,
                'attributes': {'locale': locale, **attrs},
                'relationships': {relation: {'data': {
                    'type': parent_type, 'id': parent_id}}}}}, 'POST')


users = call('/v1/users?limit=50&fields[users]=firstName,lastName,username,roles')
owner = next(r['attributes'] for r in users
             if 'ACCOUNT_HOLDER' in r['attributes']['roles'])
if CONFIG.get('privacyPolicyUrl'):
    for attrs in PLAN['appInfoLocalizations'].values():
        attrs['privacyPolicyUrl'] = CONFIG['privacyPolicyUrl']
if CONFIG.get('supportUrl'):
    for attrs in PLAN['appStoreVersionLocalizations'].values():
        attrs['supportUrl'] = CONFIG['supportUrl']
beta = {loc: {**attrs, 'feedbackEmail': owner['username']}
        for loc, attrs in PLAN['betaAppLocalizations'].items()}
locales(f'/v1/apps/{APP_ID}/betaAppLocalizations', 'betaAppLocalizations',
        'app', APP_ID, 'apps', beta)
locales(f'/v1/appInfos/{INFO}/appInfoLocalizations', 'appInfoLocalizations',
        'appInfo', INFO, 'appInfos', PLAN['appInfoLocalizations'])
locales(f'/v1/appStoreVersions/{VERSION}/appStoreVersionLocalizations',
        'appStoreVersionLocalizations', 'appStoreVersion', VERSION,
        'appStoreVersions', PLAN['appStoreVersionLocalizations'])
call('/v1/appInfos/' + INFO, {'data': {'type': 'appInfos', 'id': INFO,
     'relationships': {'primaryCategory': {'data': {
         'type': 'appCategories', 'id': PLAN['primaryCategory']}}}}}, 'PATCH')
call('/v1/appStoreVersions/' + VERSION, {'data': {
    'type': 'appStoreVersions', 'id': VERSION, 'attributes': {
        'copyright': f"2026 {owner['firstName']} {owner['lastName']}"}}}, 'PATCH')
contact = {'contactFirstName': owner['firstName'],
           'contactLastName': owner['lastName'], 'contactEmail': owner['username'],
           'demoAccountRequired': False, 'notes': PLAN['reviewNotes']}
if not CONFIG.get('contactPhone'):
    print('Textes appliqués ; téléphone requis pour enregistrer les contacts de revue.', flush=True)
    sys.exit(0)
contact['contactPhone'] = CONFIG['contactPhone']
review = call(f'/v1/apps/{APP_ID}/betaAppReviewDetail')
call('/v1/betaAppReviewDetails/' + review['id'], {'data': {
    'type': 'betaAppReviewDetails', 'id': review['id'],
    'attributes': contact}}, 'PATCH')
review_store = call(f'/v1/appStoreVersions/{VERSION}/appStoreReviewDetail')
if review_store:
    call('/v1/appStoreReviewDetails/' + review_store['id'], {'data': {
        'type': 'appStoreReviewDetails', 'id': review_store['id'],
        'attributes': contact}}, 'PATCH')
else:
    call('/v1/appStoreReviewDetails', {'data': {
        'type': 'appStoreReviewDetails', 'attributes': contact,
        'relationships': {'appStoreVersion': {'data': {
            'type': 'appStoreVersions', 'id': VERSION}}}}}, 'POST')
print('Textes envoyés. Téléphone et URL non inventés ; aucune soumission.', flush=True)
