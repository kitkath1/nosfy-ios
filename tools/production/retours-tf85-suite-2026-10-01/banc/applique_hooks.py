#!/usr/bin/env python3
"""Pose la sonde des verrous DANS LA COPIE, par ancre exacte. Idempotent."""
import sys

base = sys.argv[1]
chemin = base + "/Nosfy/NosfyApp.swift"
src = open(chemin, encoding="utf-8").read()
temoin = "SondeVerrousVue()"
if temoin in src:
    print("déjà posé"); sys.exit(0)
vieux = """                .preferredColorScheme(.dark)
                .tint(.woopViolet)
"""
n = src.count(vieux)
if n != 1:
    print(f"ANCRE x{n}"); sys.exit(2)
neuf = vieux + """                .overlay(alignment: .topLeading) { SondeVerrousVue() }
"""
open(chemin, "w", encoding="utf-8").write(src.replace(vieux, neuf))
print("EDIT OK")
