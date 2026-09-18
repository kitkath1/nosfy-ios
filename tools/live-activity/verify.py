#!/usr/bin/env python3
"""Tests Swift des vrais modèles ; aucun simulateur, compte ou serveur utilisé."""
from pathlib import Path
import subprocess, tempfile, sys
root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='nosfy-live-tests-') as folder:
    out = Path(folder)
    focus = root/'NosfyShared/WorkoutLiveFocus.swift'
    attrs = (root/'NosfyShared/WorkoutActivity.swift').read_text().replace('import ActivityKit', 'protocol ActivityAttributes {}')
    (out/'Attributes.swift').write_text(attrs)
    # Le player réel, jusqu'à la vue. Seuls les collaborateurs sans rapport avec
    # son état sont remplacés (catalogue, seuil métier et enum du graphe).
    cardio = (root/'Nosfy/Views/TapisScene.swift').read_text().split('struct TapisScene: View {')[0]
    (out/'Cardio.swift').write_text(cardio + '''
struct Exercise { let id: String }
enum PhaseKind { case acceleration, sprint, recuperation, repos }
enum EchellePaliers { case escalier, tapisLent, tapis }
enum SemaineStats { static let seuilEffort = 15.0 }
''')
    command = ['xcrun', 'swiftc', '-module-cache-path', str(out/'cache'), str(focus), str(out/'Attributes.swift'), str(out/'Cardio.swift'), str(root/'tools/live-activity/Checks.swift'), '-o', str(out/'checks')]
    subprocess.run(command, check=True)
    subprocess.run([str(out/'checks')], check=True)
    # Le vrai pilote ; seuls ActivityKit et Workout sont doublés pour provoquer
    # de façon déterministe une update suspendue pendant le Stop.
    controller = (root/'Nosfy/Services/WorkoutActivityController.swift').read_text().replace('import ActivityKit', '')
    (out/'Controller.swift').write_text(controller)
    attributes = (root/'NosfyShared/WorkoutActivity.swift').read_text().replace('import ActivityKit', '')
    (out/'ControllerAttributes.swift').write_text(attributes)
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(out/'cache'),
                    str(focus), str(out/'ControllerAttributes.swift'), str(out/'Controller.swift'),
                    str(root/'tools/live-activity/ControllerChecks.swift'), '-o', str(out/'controller-checks')], check=True)
    subprocess.run([str(out/'controller-checks')], check=True)
