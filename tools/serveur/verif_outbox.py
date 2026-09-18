#!/usr/bin/env python3
"""Le vrai actor OutboxGains face aux pannes et appels concurrents, sans réseau réel."""
from pathlib import Path
import tempfile,subprocess
r=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='nosfy-outbox-') as t:
 p=Path(t);exe=p/'outbox'
 subprocess.run(['swiftc','-parse-as-library','-module-cache-path',str(p/'cache'),str(r/'Nosfy/Services/OutboxGains.swift'),str(r/'tools/serveur/tests/outbox_regression.swift'),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
