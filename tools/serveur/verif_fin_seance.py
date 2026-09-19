#!/usr/bin/env python3
"""Vrais modèles SwiftData, règlement et StorySession, deux processus isolés."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[2]
s=(r/'Nosfy/Views/StoryFlow.swift').read_text()
story='import Foundation\n'+s[s.index('struct StorySet:'):s.index('/// Ce qu’il faut'.replace('’',"'"))]
c=(r/'Nosfy/Services/Compte.swift').read_text();a=c.index('    @MainActor\n    static func proposerWelcomeBack()');b=c.index('    // MARK:',a)
welcome='import Foundation\nenum Compte {\n'+c[a:b]+'}\n'
with tempfile.TemporaryDirectory(prefix='nosfy-fin-') as d:
 p=Path(d);(p/'story.swift').write_text(story);(p/'welcome.swift').write_text(welcome)
 files=[r/'Nosfy/Models.swift',r/'Nosfy/Services/ReglementSeance.swift',p/'story.swift',p/'welcome.swift',r/'tools/serveur/tests/fin_seance_regression.swift']
 subprocess.run(['swiftc','-parse-as-library','-module-name','NosfyFinTest','-target','arm64-apple-macos14.0','-module-cache-path',str(p/'cache'),*map(str,files),'-o',str(p/'test')],check=True)
 for mode in ['semer','relire','recu']:
  subprocess.run([str(p/'test'),mode,str(p/'seances.store')],check=True)

 # Migration depuis le schéma précédent, dans le même module SwiftData.
 old=(r/'Nosfy/Models.swift').read_text().replace('    var recompenseARegler: Bool = false\n','').replace('    var bilanRecompense: Data?\n','')
 (p/'old.swift').write_text(old)
 (p/'seed.swift').write_text("""import Foundation
import SwiftData
@main struct Seed {
 @MainActor static func main()throws {
  let c=try ModelContainer(for:Workout.self,LoggedExercise.self,StrengthSet.self,CardioPhase.self,configurations:ModelConfiguration(url:URL(fileURLWithPath:CommandLine.arguments[1])))
  let w=Workout(endedAt:Date());c.mainContext.insert(w)
  let e=LoggedExercise(exerciseID:"hip-thrust",order:0);c.mainContext.insert(e);e.workout=w
  let s=StrengthSet(reps:10,weight:5,order:0,isDone:true);c.mainContext.insert(s);s.loggedExercise=e
  try c.mainContext.save()
 }
}
""")
 subprocess.run(['swiftc','-parse-as-library','-module-name','NosfyFinTest','-target','arm64-apple-macos14.0',str(p/'old.swift'),str(p/'seed.swift'),'-o',str(p/'old')],check=True)
 subprocess.run([str(p/'old'),str(p/'ancienne.store')],check=True)
 subprocess.run([str(p/'test'),'migrer',str(p/'ancienne.store')],check=True)
