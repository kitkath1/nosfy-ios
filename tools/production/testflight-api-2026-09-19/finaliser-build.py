"""Rattache les consignes au build traité. Aucune invitation ni revue lancée."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstore_connect import APP_ID, request

ROOT = Path(__file__).resolve().parent
PLAN = json.loads((ROOT / 'fiche-testflight.json').read_text())
VERSION = '604aaea9-5e11-4dff-ac24-76b3b455eb53'
PROOF = []


def call(path, body=None, method='GET'):
    status, result = request(path, body, method)
    PROOF.append({'path': path, 'method': method, 'status': status, 'body': result})
    (ROOT / 'finalisation-build.json').write_text(
        json.dumps(PROOF, ensure_ascii=False, indent=2) + '\n')
    print(method, path, status, flush=True)
    if status >= 400:
        raise RuntimeError(json.dumps(result, ensure_ascii=False))
    return (result or {}).get('data')


builds = call(f'/v1/builds?filter[app]={APP_ID}&filter[version]=81&include=preReleaseVersion')
build = next((b for b in builds if b['attributes']['version'] == '81'), None)
if not build or build['attributes']['processingState'] != 'VALID':
    print('Build 81 pas encore VALID ; consignes conservées localement.', flush=True)
    sys.exit(2)
build_id = build['id']
existing = {r['attributes']['locale']: r['id'] for r in
            call(f'/v1/builds/{build_id}/betaBuildLocalizations')}
for locale, attrs in PLAN['betaBuildLocalizations'].items():
    if locale in existing:
        call('/v1/betaBuildLocalizations/' + existing[locale], {'data': {
            'type': 'betaBuildLocalizations', 'id': existing[locale],
            'attributes': attrs}}, 'PATCH')
    else:
        call('/v1/betaBuildLocalizations', {'data': {
            'type': 'betaBuildLocalizations', 'attributes': {'locale': locale, **attrs},
            'relationships': {'build': {'data': {
                'type': 'builds', 'id': build_id}}}}}, 'POST')
rows = call(f'/v1/builds/{build_id}/betaBuildLocalizations')
for locale, attrs in PLAN['betaBuildLocalizations'].items():
    actual = next(r['attributes'] for r in rows if r['attributes']['locale'] == locale)
    assert actual['whatsNew'] == attrs['whatsNew'], locale
linked = call(f'/v1/appStoreVersions/{VERSION}/relationships/build')
if not linked:
    call(f'/v1/appStoreVersions/{VERSION}/relationships/build', {
        'data': {'type': 'builds', 'id': build_id}}, 'PATCH')
elif linked['id'] != build_id:
    raise RuntimeError('Une autre version est déjà sélectionnée : ne pas écraser.')
icons = call(f'/v1/builds/{build_id}/icons')
(ROOT / 'icones-apple.json').write_text(json.dumps(icons, indent=2) + '\n')
detail = call(f'/v1/builds/{build_id}/buildBetaDetail')
print('Build VALID ; consignes FR/en-GB relues ; icônes Apple :', len(icons), flush=True)
print(json.dumps(detail['attributes'], ensure_ascii=False), flush=True)
