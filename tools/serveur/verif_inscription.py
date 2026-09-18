#!/usr/bin/env python3
"""Compile le vrai client profil et la reprise d'inscription, sans réseau réel."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="woop-inscription-") as tmp:
    executable = Path(tmp) / "inscription"
    subprocess.run(["swiftc", "-parse-as-library", "-module-cache-path", tmp + "/cache",
                    str(repo / "Woop/Services/InscriptionCompte.swift"),
                    str(repo / "Woop/Services/ProfilServeur.swift"),
                    str(repo / "tools/serveur/tests/inscription_regression.swift"),
                    "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
