#!/usr/bin/env python3
"""Exécute l'envoi et l'extraction Swift de production avec transport intercepté."""
from pathlib import Path
import tempfile,subprocess
r=Path(__file__).resolve().parents[2]
s=(r/'Nosfy/Services/SupabaseSync.swift').read_text()
core=s[:s.index('// MARK: - Lecture : le pull')].replace('import SwiftData','')
core+=s[s.index('extension Workout {'):]
with tempfile.TemporaryDirectory(prefix='nosfy-sync-') as t:
 p=Path(t);(p/'sync.swift').write_text(core)
 subprocess.run(['swiftc','-parse-as-library','-module-cache-path',str(p/'cache'),str(p/'sync.swift'),str(r/'tools/serveur/tests/sync_regression.swift'),'-o',str(p/'sync')],check=True)
 subprocess.run([str(p/'sync')],check=True)
