#!/usr/bin/env python3
"""Exécute le vrai calcul Swift de Route, sans moteur visuel ni compte distant."""
from pathlib import Path
import argparse
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, help='Source alternative, pour vérifier la régression avant correctif')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
source = args.source or repo / 'Nosfy/Views/DuolinguoPage.swift'
code = source.read_text()
# Géométrie, ordre des galets et calcul de production extraits ensemble.
# Aucun calcul de progression réécrit dans le banc.
start = code.index('    struct EtapeSpec:')
end = code.index('    /// LES FRONTIÈRES', start)
extrait = 'import Foundation\nenum EcranSpec {\n' + code[start:end] + '\n}\n'
# La lecture réelle des états et dates, sans les vues SwiftUI.
a = code.index('    struct Lecture {')
b = code.index("        /// LA DATE D'UN GALET", a)
extrait += 'enum EtapeEtat: Equatable { case actif, accompli, rate, prochain, verrouille, reclame; case piece(dispo: Bool), lune(dispo: Bool) }\nextension EcranSpec {\n' + code[a:b] + '\n}\n}\n'
tests = r'''
var controles = 0
func verifier(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL : " + message) }
    controles += 1
    print("PASS : " + message)
}
let cal = Calendar.current
let maintenant = cal.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 12))!
for decalage in [0, 1, 40] {
    let jour = cal.date(byAdding: .day, value: decalage, to: maintenant)!
    let vide = EcranSpec.etapeEtFaits(seancesFinies: [], aujourdhui: jour)
    verifier(vide.etape == 0, "compte vide J+\(decalage) : premier galet")
    verifier(vide.faits.isEmpty && vide.dates.isEmpty, "compte vide J+\(decalage) : aucun accompli ni date fictive")
    let actif = EcranSpec.etapes[vide.etape]
    verifier(actif.ecran == 0 && actif.n == 0 && !actif.special,
             "compte vide J+\(decalage) : séance en haut du chapitre 1")
    verifier(EcranSpec.etapes.allSatisfy { $0.ecran > 0 || $0.y >= actif.y },
             "compte vide J+\(decalage) : aucun galet avant/au-dessus")
    verifier(EcranSpec.etapes.filter(\.special).allSatisfy { $0.id > vide.etape && !vide.faits.contains($0.id) },
             "compte vide J+\(decalage) : toutes les récompenses restent à venir")
}
let datesAnciennes = [-5, -2].map { cal.date(byAdding: .day, value: $0, to: maintenant)! }
let existant = EcranSpec.etapeEtFaits(seancesFinies: datesAnciennes, aujourdhui: maintenant)
verifier(existant.etape > 0 && existant.faits.count == 2, "historique non vide conservé, pas de remise à zéro")
let autreCompte = EcranSpec.etapeEtFaits(seancesFinies: [], aujourdhui: maintenant)
verifier(autreCompte.etape == 0 && autreCompte.faits.isEmpty && autreCompte.dates.isEmpty,
         "un calcul après celui d’un historique ne reprend pas ses galets")
for nombre in 0...36 {
    // Deux séances le même jour restent deux réalisations.
    let dates = Array(repeating: maintenant.addingTimeInterval(-60), count: nombre)
    let resultat = EcranSpec.etapeEtFaits(seancesFinies: dates, aujourdhui: maintenant)
    let lecture = EcranSpec.Lecture(etape: resultat.etape, faits: resultat.faits,
        datesFaites: resultat.dates, maintenant: maintenant)
    verifier(resultat.faits.count == min(nombre,35), "\(nombre) séances : bon nombre de galets")
    verifier(EcranSpec.seances.filter { lecture.etat($0) == .actif }.count == (nombre < 35 ? 1 : 0),
             "\(nombre) séances : actif uniquement avant la fin")
    verifier(EcranSpec.seances.filter { lecture.etat($0) == .accompli }.count == min(nombre,35),
             "\(nombre) séances : réalisés visibles même au dernier galet")
    verifier(EcranSpec.seances.filter { resultat.faits.contains($0.id) }.allSatisfy {
        lecture.dateReelle($0) == dates.first
    }, "\(nombre) séances : dates réelles conservées")
    for special in EcranSpec.etapes.filter(\.special) {
        let seuil = EcranSpec.seances.filter { $0.id < special.id }.count
        let attendu: EtapeEtat = special.piece ? .piece(dispo: nombre >= seuil) : .lune(dispo: nombre >= seuil)
        verifier(lecture.etat(special) == attendu, "\(nombre) séances : récompense\(special.id) au bon seuil")
    }
}
let future = EcranSpec.etapeEtFaits(seancesFinies: [maintenant.addingTimeInterval(3600)], aujourdhui: maintenant)
verifier(future.faits.isEmpty && future.etape == 0, "une date future ne fait pas avancer")
let pause = EcranSpec.etapeEtFaits(seancesFinies: datesAnciennes, aujourdhui: maintenant.addingTimeInterval(86400*60))
verifier(pause.faits == existant.faits && pause.etape == existant.etape, "une pause de60jours ne fait pas avancer")
print("\(controles) contrôles PASS — \(CommandLine.arguments.contains("-cheminReel") ? "dates réelles" : "lancement normal")")
'''
with tempfile.TemporaryDirectory(prefix='nosfy-route-vide-') as tmp:
    dossier = Path(tmp)
    swift = dossier / 'main.swift'
    swift.write_text(extrait + tests)
    executable = dossier / 'route-vide'
    subprocess.run(['swiftc', '-module-cache-path', str(dossier / 'cache'), str(swift), '-o', str(executable)], check=True)
    for arguments in [[], ['-cheminReel']]:
        subprocess.run([str(executable), *arguments], check=True)
