#!/usr/bin/env python3
"""Exécute la relecture Swift réelle avec réseau différé et stockage de test."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[2]
s=(r/'Nosfy/Services/SupabaseSync.swift').read_text()
a=s.index('extension SupabaseSync {');b=s.index('// MARK: - Extraction',a)
with tempfile.TemporaryDirectory(prefix='nosfy-pull-') as t:
 p=Path(t);(p/'pull.swift').write_text('import Foundation\nactor SupabaseSync {}\n'+s[a:b])
 subprocess.run(['swiftc','-parse-as-library','-module-cache-path',str(p/'cache'),str(p/'pull.swift'),str(r/'tools/serveur/tests/pull_regression.swift'),'-o',str(p/'pull')],check=True)
 subprocess.run([str(p/'pull')],check=True)
