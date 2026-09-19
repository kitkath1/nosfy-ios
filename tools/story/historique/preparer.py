from pathlib import Path
import shutil, subprocess, tempfile, json

root = Path(__file__).resolve().parents[3]
dst = Path(tempfile.mkdtemp(prefix='nosfy-historique-ui-'))
for name in ['Nosfy', 'NosfyShared', 'NosfyWidgets', 'Nosfy.xcodeproj']:
    shutil.copytree(root/name, dst/name)
subprocess.run(['python3', str(root/'tools/nav/fouettage/applique_patch.py'), str(dst/'Nosfy.xcodeproj/project.pbxproj')], check=True)
(dst/'NosfyUITests').mkdir()
shutil.copy(root/'tools/nav/fouettage/NosfyUITests.xcscheme', dst/'Nosfy.xcodeproj/xcshareddata/xcschemes')
shutil.copy(root/'tools/story/historique/HistoriqueUITests.swift', dst/'NosfyUITests')
shutil.copy(root/'tools/story/historique/HistoriqueQABanc.swift', dst/'Nosfy/Views')
p = dst/'Nosfy/NosfyApp.swift'; s = p.read_text()
s = s.replace('DemoData.seedIfEmpty(in: container)', 'HistoriqueQABanc.semer(in: container)', 1)
s = s.replace('if CommandLine.arguments.contains("-cartesQA")', 'if CommandLine.arguments.contains("-histoQA") { HistoriqueQABanc() }\n                else if CommandLine.arguments.contains("-cartesQA")', 1)
p.write_text(s)
p = dst/'Nosfy/Views/HistoriqueStories.swift'; s = p.read_text()
s = s.replace('                .presentationBackground(.clear)', '''                .overlay(alignment: .top) {
                    let recit = StorySession(workout: launch.workout)
                    Text("pieces=\\(recit.recompense?.pieces ?? -1);attente=\\(recit.recompenseEnAttente)")
                        .font(.system(size: 1)).opacity(0.01).accessibilityIdentifier("qa.historique")
                }
                .presentationBackground(.clear)''', 1)
p.write_text(s)
proof = root/'tools/production/stories-historique-2026-09-19'
(proof/'banc-chemin.txt').write_text(str(dst)+'\n')
print(dst)
