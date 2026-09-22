#!/usr/bin/env python3
"""Exécute le vrai calcul Swift de Route, sans moteur visuel ni compte distant.

21-09 : le banc extrait aussi `PlafondJour` (depuis le 20-09, `etapeEtFaits`
l'appelle : sans lui le banc ne compilait plus) et il vérifie la règle du
21-09 — UN GALET = UN JOUR, deux séances la même journée valant un seul galet
qui porte le sticker ×2.
"""
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

# LE PLAFOND DU JOUR — le vrai, celui de l'app (`etapeEtFaits` en dépend).
# On coupe avant les mots et l'extension View : le banc n'a pas SwiftUI.
plafond = (repo / 'Nosfy/Services/PlafondJour.swift').read_text()
pa = plafond.index('enum PlafondJour {')
pb = plafond.index('    // MARK: Les mots', pa)
extrait = 'import Foundation\n' + plafond[pa:pb] + '}\n'

# Géométrie, ordre des galets et calcul de production extraits ensemble.
# Aucun calcul de progression réécrit dans le banc.
start = code.index('    struct EtapeSpec:')
end = code.index('    /// LES FRONTIÈRES', start)
extrait += 'enum EcranSpec {\n' + code[start:end] + '\n}\n'
# La lecture réelle des états, des dates et du ×2, sans les vues SwiftUI.
a = code.index('    struct Lecture {')
b = code.index("        /// LA DATE D'UN GALET", a)
m0 = code.index('        func multiple(_ e: EtapeSpec) -> Int? {', a)
m1 = code.index('\n        }\n', m0) + len('\n        }\n')
extrait += ('enum EtapeEtat: Equatable { case actif, accompli, rate, prochain, verrouille, reclame; '
            'case piece(dispo: Bool), lune(dispo: Bool) }\nextension EcranSpec {\n'
            + code[a:b] + code[m0:m1] + '\n}\n}\n')

tests = r'''
var controles = 0
func verifier(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL : " + message) }
    controles += 1
    print("PASS : " + message)
}
let cal = Calendar.current
// APRÈS la date de la règle (`PlafondJour.depuis` = 20-09) : c'est le régime
// en vigueur qu'on vérifie, pas l'héritage d'avant.
let maintenant = cal.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
func jourAvant(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: maintenant)! }
func etape(_ id: Int) -> EcranSpec.EtapeSpec { EcranSpec.etapes.first { $0.id == id }! }

for decalage in [0, 1, 40] {
    let jour = cal.date(byAdding: .day, value: decalage, to: maintenant)!
    let vide = EcranSpec.etapeEtFaits(seancesFinies: [], aujourdhui: jour)
    verifier(vide.etape == 0, "compte vide J+\(decalage) : premier galet")
    verifier(vide.faits.isEmpty && vide.dates.isEmpty, "compte vide J+\(decalage) : aucun accompli ni date fictive")
    verifier(vide.seances.isEmpty, "compte vide J+\(decalage) : aucun ×2")
    let actif = EcranSpec.etapes[vide.etape]
    verifier(actif.ecran == 0 && actif.n == 0 && !actif.special,
             "compte vide J+\(decalage) : séance en haut du chapitre 1")
    verifier(EcranSpec.etapes.allSatisfy { $0.ecran > 0 || $0.y >= actif.y },
             "compte vide J+\(decalage) : aucun galet avant/au-dessus")
    verifier(EcranSpec.etapes.filter(\.special).allSatisfy { $0.id > vide.etape && !vide.faits.contains($0.id) },
             "compte vide J+\(decalage) : toutes les récompenses restent à venir")
}

let datesAnciennes = [jourAvant(5), jourAvant(2)]
let existant = EcranSpec.etapeEtFaits(seancesFinies: datesAnciennes, aujourdhui: maintenant)
verifier(existant.etape > 0 && existant.faits.count == 2, "historique non vide conservé, pas de remise à zéro")
let autreCompte = EcranSpec.etapeEtFaits(seancesFinies: [], aujourdhui: maintenant)
verifier(autreCompte.etape == 0 && autreCompte.faits.isEmpty && autreCompte.dates.isEmpty,
         "un calcul après celui d’un historique ne reprend pas ses galets")

// ═══ UN JOUR = UN GALET (21-09) : N jours de suite, une séance par jour.
for nombre in 0...36 {
    let dates = (0..<nombre).map { jourAvant($0 + 1) }
    let resultat = EcranSpec.etapeEtFaits(seancesFinies: dates, aujourdhui: maintenant)
    let lecture = EcranSpec.Lecture(etape: resultat.etape, faits: resultat.faits,
        datesFaites: resultat.dates, seancesParGalet: resultat.seances, maintenant: maintenant)
    verifier(resultat.faits.count == min(nombre,35), "\(nombre) jours : bon nombre de galets")
    verifier(EcranSpec.seances.filter { lecture.etat($0) == .actif }.count == (nombre < 35 ? 1 : 0),
             "\(nombre) jours : actif uniquement avant la fin")
    verifier(EcranSpec.seances.filter { lecture.etat($0) == .accompli }.count == min(nombre,35),
             "\(nombre) jours : réalisés visibles même au dernier galet")
    verifier(EcranSpec.seances.filter { resultat.faits.contains($0.id) }.allSatisfy {
        lecture.dateReelle($0).map(dates.contains) == true
    }, "\(nombre) jours : chaque galet porte SA date de fin")
    verifier(EcranSpec.seances.allSatisfy { lecture.multiple($0) == nil },
             "\(nombre) jours à une séance : aucun sticker ×2")
    for special in EcranSpec.etapes.filter(\.special) {
        let seuil = EcranSpec.seances.filter { $0.id < special.id }.count
        let attendu: EtapeEtat = special.piece ? .piece(dispo: nombre >= seuil) : .lune(dispo: nombre >= seuil)
        verifier(lecture.etat(special) == attendu, "\(nombre) jours : récompense\(special.id) au bon seuil")
        verifier(lecture.peutReclamer(special) == (nombre >= seuil),
                 "\(nombre) jours : bouton et geste récompense\(special.id) autorisés au seuil")
        let prise = EcranSpec.Lecture(etape: resultat.etape, faits: resultat.faits,
            datesFaites: resultat.dates, seancesParGalet: resultat.seances,
            reclamees: [special.id], maintenant: maintenant)
        verifier(!prise.peutReclamer(special) && prise.etat(special) == .reclame,
                 "\(nombre) jours : récompense\(special.id) prise non réclamable")
    }
}

// ═══ LE ×2 : deux séances dans LA MÊME journée
let deuxAujourdhui = [maintenant.addingTimeInterval(-7200), maintenant.addingTimeInterval(-600)]
let double = EcranSpec.etapeEtFaits(seancesFinies: deuxAujourdhui, aujourdhui: maintenant)
let g0 = EcranSpec.id(pourJour: 0)
verifier(double.faits.count == 1, "deux séances le même jour : UN seul galet")
verifier(double.etape == EcranSpec.id(pourJour: 1), "deux séances le même jour : l’étape n’avance que d’un")
verifier(double.seances[g0] == 2, "deux séances le même jour : le galet du jour en compte 2")
verifier(double.dates[g0] == deuxAujourdhui[0], "le galet porte la PREMIÈRE fin de la journée")
let lectureDouble = EcranSpec.Lecture(etape: double.etape, faits: double.faits,
    datesFaites: double.dates, seancesParGalet: double.seances, maintenant: maintenant)
verifier(lectureDouble.multiple(etape(g0)) == 2, "le sticker ×2 est sur le galet du jour")
verifier(EcranSpec.seances.filter { lectureDouble.multiple($0) != nil }.count == 1,
         "un seul galet porte le ×2")
verifier(lectureDouble.dateReelle(etape(double.etape)) == nil,
         "la journée déjà faite : l’actif ne répète PAS sa date (le doublon du 19 est mort)")
verifier(lectureDouble.etat(etape(g0)) == .accompli && lectureDouble.etat(etape(double.etape)) == .actif,
         "deux séances le même jour : un accompli, un actif")

// Une troisième séance la même journée ne pose ni galet ni ×3 (le plafond).
let trois = deuxAujourdhui + [maintenant.addingTimeInterval(-60)]
let triple = EcranSpec.etapeEtFaits(seancesFinies: trois, aujourdhui: maintenant)
verifier(triple.faits == double.faits && triple.seances == double.seances && triple.etape == double.etape,
         "une troisième séance le même jour ne change rien")

// Un jour à deux séances + des jours simples : chacun son compte.
let melange = [jourAvant(3), jourAvant(1), jourAvant(1).addingTimeInterval(3600)]
let mixte = EcranSpec.etapeEtFaits(seancesFinies: melange, aujourdhui: maintenant)
verifier(mixte.faits.count == 2, "trois séances sur deux jours : deux galets")
verifier(mixte.seances[EcranSpec.id(pourJour: 0)] == 1 && mixte.seances[EcranSpec.id(pourJour: 1)] == 2,
         "trois séances sur deux jours : le ×2 sur le bon jour")

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
