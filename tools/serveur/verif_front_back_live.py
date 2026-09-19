#!/usr/bin/env python3
"""Vrais clients Swift → Supabase → SwiftData → StorySession, sans téléphone.

Une identité QA créée puis supprimée. Keychain remplacé par une mémoire privée,
préférences isolées, état des vues remplacé par un récepteur de résultats.
Transport, session, synchronisation, outbox, règlement et décodeurs réels.
"""
from pathlib import Path
import json, re, secrets, subprocess, tempfile, urllib.request, uuid

R = Path(__file__).resolve().parents[2]
URL = 'https://ytnnyjkramgiqyxdrkcu.supabase.co'
source = (R/'Nosfy/Services/Supabase.swift').read_text()
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', source)[1]


def appel(path, body=None, admin=False, method='POST'):
    key = (R/'.secrets/supabase-service-role').read_text().strip() if admin else KEY
    req = urllib.request.Request(URL+path,
        data=None if body is None else json.dumps(body).encode(), method=method,
        headers={'apikey': key, 'Authorization': 'Bearer '+key,
                 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read() or 'null')


with tempfile.TemporaryDirectory(prefix='nosfy-front-back-') as tmp:
    d = Path(tmp)
    session = ('import Foundation\n'+source[source.index('enum WoopConfig {'):source.index('// MARK: - Le coffre')]
               +source[source.index('actor SupabaseSession {'):])
    story = (R/'Nosfy/Views/StoryFlow.swift').read_text()
    story = 'import Foundation\n'+story[story.index('struct StorySet:'):story.index("/// Ce qu'il faut")]
    extra = {'Session.swift': session, 'Story.swift': story}
    files = ['Models.swift', 'Services/SupabaseSync.swift', 'Services/ReglementSeance.swift',
             'Services/OutboxGains.swift', 'Services/SacreServeur.swift', 'Services/CartesServeur.swift']
    for f in files:
        extra[Path(f).name] = (R/'Nosfy'/f).read_text()
    compiled = []
    for name, text in extra.items():
        p = d/name
        # Aucun état de l'app ni de son compte n'est touché par le banc macOS.
        p.write_text(text.replace('UserDefaults.standard', 'BancPreferences.valeur'))
        compiled.append(str(p))
    exe = d/'front-back'
    subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', str(d/'cache'),
                    *compiled, str(R/'tools/serveur/tests/front_back_live.swift'),
                    '-o', str(exe)], check=True)
    uid = None
    try:
        email = f'nosfy-swift-{uuid.uuid4()}@example.invalid'
        password = secrets.token_urlsafe(32)
        user = appel('/auth/v1/admin/users', {'email': email, 'password': password,
                     'email_confirm': True, 'app_metadata': {'nosfy_qa': 'swift-front-back-20260919'}}, admin=True)
        uid = user['id']
        session = appel('/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        # Jetons transmis par stdin, jamais dans la commande ni dans les journaux.
        subprocess.run([str(exe)], input=json.dumps(session), text=True, check=True, timeout=240)
    finally:
        if uid:
            appel('/auth/v1/admin/users/'+uid, admin=True, method='DELETE')
            print('PASS identité QA Swift supprimée ; aucun compte personnel modifié', flush=True)
