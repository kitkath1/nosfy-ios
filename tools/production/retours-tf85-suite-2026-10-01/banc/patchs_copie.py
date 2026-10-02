#!/usr/bin/env python3
"""Réparations de compilation de l'arbre PARTAGÉ, dans la copie seulement
(chantiers en cours d'autres sessions). Tolérant : n'écrit que si le motif est là."""
import sys
base = sys.argv[1]
f = base + "/Nosfy/Views/SeanceV7.swift"
s = open(f, encoding="utf-8").read()
v = """        let jour = f.string(from: w.startedAt ?? .now)
        guard let d = w.startedAt, let e = w.endedAt else { return jour }"""
n = """        let jour = f.string(from: w.startedAt)
        let d = w.startedAt
        guard let e = w.endedAt else { return jour }"""
if v in s:
    open(f, "w", encoding="utf-8").write(s.replace(v, n)); print("SeanceV7 réparé (copie)")
# 01-10 : CommandesV15 en cours d'écriture (autre session) — l'ordre des arguments.
f = base + "/Nosfy/Views/ExerciseDetailView.swift"
s = open(f, encoding="utf-8").read()
nom = "            ensuiteNom: suivant?.exo.nomLocalise,\n"
charge = "            ensuiteCharge: suivant.map { chargeV15($0.exo, $0.prevu) },\n"
ancre = "            ensuite: ensuite,\n"
if nom in s and charge in s and ancre in s and s.index(nom) > s.index(ancre) + 200:
    s = s.replace(nom, "").replace(charge, "")
    s = s.replace(ancre, ancre + nom + charge, 1)
    open(f, "w", encoding="utf-8").write(s); print("ExerciseDetailView réordonné (copie)")
