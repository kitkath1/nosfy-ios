"""Nomme les cas et leur verdict depuis le xcresult (xcresulttool), repli
sur le log. Sortie 0 ssi 10 cas lus, 10 OK. (Conception d'origine,
validée telle quelle au banc adverse.)"""
import json
import re
import subprocess
import sys

xcres, log = sys.argv[1], sys.argv[2]
cas = {}


def marche(noeuds):
    for n in noeuds:
        nom = n.get("name") or ""
        m = re.match(r"(test\d\d\w*|testFilm\w*)", nom)
        if m and n.get("nodeType") in ("Test Case", None):
            res = str(n.get("result") or "").lower()
            if "pass" in res or "fail" in res:
                cas[m.group(1)] = "OK" if "pass" in res else "ECHEC"
        marche(n.get("children") or [])


try:
    brut = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests",
         "--path", xcres],
        capture_output=True, text=True, check=True).stdout
    marche(json.loads(brut).get("testNodes") or [])
except Exception:
    pass
if not cas:
    try:
        texte = open(log, errors="replace").read()
        for m in re.finditer(
                r"[Tt]est [Cc]ase '[^']*?(test\d\d\w*|testFilm\w*)[^']*' "
                r"(passed|failed)", texte):
            cas[m.group(1)] = "OK" if m.group(2) == "passed" else "ECHEC"
    except OSError:
        pass
if not cas:
    print("AUCUN cas lu")
    sys.exit(2)
oks = 0
for nom in sorted(cas):
    print(f"  {nom}  {cas[nom]}")
    oks += cas[nom] == "OK"
print(f"BILAN CAS : {oks}/{len(cas)}")
sys.exit(0 if oks == len(cas) == 10 else 1)
