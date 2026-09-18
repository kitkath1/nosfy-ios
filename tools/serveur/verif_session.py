#!/usr/bin/env python3
"""Exécute le vrai SupabaseSession avec réseau et Keychain en mémoire."""
from pathlib import Path
import subprocess
import tempfile
import sys
import os
import re

repo = Path(__file__).resolve().parents[2]
source = (repo / "Nosfy/Services/Supabase.swift").read_text()
actor = "import Foundation\n" + source[source.index("actor SupabaseSession {"):]
live = "--live" in sys.argv
env = dict(os.environ)
if live:
    env["WOOP_TEST_KEY"] = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', source).group(1)
    env["WOOP_TEST_PASSWORD"] = "forge-test-2026"
with tempfile.TemporaryDirectory(prefix="woop-session-") as dossier:
    dossier = Path(dossier)
    extrait = dossier / "SupabaseSession.swift"
    extrait.write_text(actor)
    executable = dossier / "session-regression"
    autres = []
    if live:
        # Compile les vrais clients et le vrai décodeur d'annonces, pour vérifier
        # le contrat front/backend avec les réponses de la base vivante.
        regles = (repo / "Nosfy/Views/RestartSheet.swift").read_text()
        debut = regles.index("struct ReglesAnnonces: Equatable {")
        fin = regles.index("\n/// LE DÉCIDEUR À BUDGET", debut)
        extrait_regles = dossier / "ReglesAnnonces.swift"
        extrait_regles.write_text("import Foundation\n" + regles[debut:fin])
        autres = [str(repo / "Nosfy/Services/SacreServeur.swift"), str(extrait_regles)]
    subprocess.run(["swiftc", "-parse-as-library", "-module-cache-path", str(dossier / "cache"),
                    str(extrait), str(repo / "tools/serveur/tests" / ("session_live.swift" if live else "session_regression.swift")),
                    *autres,
                    "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True, env=env)
