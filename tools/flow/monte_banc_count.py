#!/usr/bin/env python3
"""Ajoute le banc à une COPIE de l'app, jamais au projet partagé."""
from pathlib import Path
import shutil
import subprocess
import sys

repo = Path(__file__).resolve().parents[2]
copie = Path(sys.argv[1]).resolve()
if copie == repo:
    raise SystemExit("Une copie isolée est obligatoire")
nav = repo / "tools/nav/fouettage"
subprocess.run([sys.executable, str(nav / "applique_patch.py"),
                str(copie / "Nosfy.xcodeproj/project.pbxproj")], check=True)
scheme = copie / "Nosfy.xcodeproj/xcshareddata/xcschemes"
scheme.mkdir(parents=True, exist_ok=True)
shutil.copy2(nav / "NosfyUITests.xcscheme", scheme)
tests = copie / "NosfyUITests"
tests.mkdir(exist_ok=True)
shutil.copy2(repo / "tools/flow/CountdownUITests.swift", tests)
app = copie / "Nosfy/NosfyApp.swift"
s = app.read_text()
ancre = """            if let film = filmDepart {
"""
assert s.count(ancre) == 1
s = s.replace(ancre, """            if CommandLine.arguments.contains("-countProbe") {
                Text("actives=\\(activeWorkouts.count);id=\\(active?.remoteID.uuidString ?? "-");film=\\(filmDepart == nil ? 0 : 1);page=\\(selection.rawValue)")
                    .font(.system(size: 1)).opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("count-state")
                    .position(x: 2, y: 100)
            }
""" + ancre)
app.write_text(s)
print("Banc count monté dans", copie)
