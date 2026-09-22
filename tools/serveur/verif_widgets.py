#!/usr/bin/env python3
"""
verif_widgets.py — LES WIDGETS DE BOUT EN BOUT (15-09, chantier Widgets) : le SERVEUR et le
TÉLÉPHONE comptent-ils PAREIL ? Compte de test (23 séances), corps lus, rien d'écrit.

    python3 tools/serveur/verif_widgets.py            # serveur + téléphone (simulateur libre)
    python3 tools/serveur/verif_widgets.py --serveur  # le serveur seul

Ce qu'elle prouve (site : b-wd-semainestats, b-ux-chambre-donnees, b-ux-chambre-serveur,
b-wd-hiitpeak-groupage, b-rg-seuil-effort) :
  1. les quatre widget_* répondent pour `semaine` et `mois`, sans null (la loi du vide) — hors
     les nullables assumés : defi (aucun mois passé), depuis_record / meilleur_exercice (aucun
     record), reste (fenêtre mois), ratio et delta_pct (division par zéro) ;
  2. l'app DÉSINSTALLÉE puis lancée sur le compte de test (le pull ramène les séances), au banc
     `-widgetsBanc`, imprime les chiffres du téléphone (journal [widgets]) — et pour chaque
     fenêtre : faites, series (22-09), volume, pic, efforts, temps_pics, records_battus sont
     ÉGAUX à ceux du serveur. Le seuil d'effort imprimé est celui du serveur (seuil_effort_kmh).
  ⚠️ L'app se lance sur le simulateur LIBRE (iPhone 17 Pro D8A31930…), jamais sur ceux qui
  sont bootés (Kathryn ou une autre session peuvent y être) ; il est éteint à la fin.
"""
import re, json, os, sys, time, subprocess, urllib.request, urllib.error

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co"
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', open(f"{REPO}/Nosfy/Services/Supabase.swift").read()).group(1)
UD = "D8A31930-1D84-42BF-A129-051BB6B9195B"
APP = "/private/tmp/woop-dd-serveur/Build/Products/Debug-iphonesimulator/Nosfy.app"
CHAMPS = ("faites", "precedent", "series", "series_precedent", "volume", "volume_precedent", "pic", "efforts", "temps_pics", "records_battus")


def call(path, body=None, jwt=None):
    h = {"apikey": KEY, "Content-Type": "application/json", "Authorization": f"Bearer {jwt or KEY}"}
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=h, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


ok, N_OK, N_KO = True, 0, 0


def verdict(cond, msg):
    global ok, N_OK, N_KO
    print(("  ✓ " if cond else "  ✗ ") + msg)
    ok = ok and cond
    if cond: N_OK += 1
    else: N_KO += 1


s, b = call("/auth/v1/token?grant_type=password", {"email": "kat44426+woop-forge-test@gmail.com", "password": "forge-test-2026"})
jwt = b.get("access_token")
print("compte de test :", b.get("user", {}).get("id"))

print("\n[1] le serveur : les quatre widget_* par fenêtre")
serveur = {}
for fen in ("semaine", "mois"):
    r = {}
    for f in ("widget_regularite", "widget_volume", "widget_hiit", "widget_peak"):
        st, j = call(f"/rest/v1/rpc/{f}", {"p_fenetre": fen}, jwt)
        verdict(st == 200 and isinstance(j, dict) and "erreur" not in j, f"{f}({fen}) → {st}")
        r[f] = j if isinstance(j, dict) else {}
    serveur[fen] = {
        "faites": r["widget_regularite"].get("faites", 0),
        "precedent": r["widget_regularite"].get("precedent", 0),
        # 22-09 : les séries faites de la fenêtre (20260922103419) — comptées à la fin de séance
        "series": r["widget_regularite"].get("series", 0),
        "series_precedent": r["widget_regularite"].get("series_precedent", 0),
        "volume": int(round(r["widget_volume"].get("volume", 0) or 0)),
        "volume_precedent": int(round(r["widget_volume"].get("precedent", 0) or 0)),
        "pic": float(r["widget_hiit"].get("pic", 0) or 0),
        "efforts": r["widget_hiit"].get("efforts", 0),
        "temps_pics": r["widget_hiit"].get("temps_pics", 0),
        "records_battus": r["widget_peak"].get("records_battus", 0),
        "seuil": float(r["widget_hiit"].get("seuil", 0) or 0),
    }
    nuls = [k for f2 in r.values() for k, v in f2.items() if v is None and k not in ("defi", "depuis_record", "reste", "ratio", "delta_pct", "meilleur_exercice")]
    verdict(not nuls, f"{fen} : aucun null hors les nullables assumés {nuls or ''}")
    print(f"    {fen} : " + " · ".join(f"{k} {serveur[fen][k]}" for k in CHAMPS))

if "--serveur" in sys.argv:
    print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE")); sys.exit(0 if ok else 1)

print("\n[2] le téléphone : app désinstallée, le pull, puis -widgetsBanc")
sim = lambda *a: subprocess.run(["xcrun", "simctl", *a], capture_output=True, text=True)
sim("boot", UD); subprocess.run(["xcrun", "simctl", "bootstatus", UD, "-b"], capture_output=True)
sim("uninstall", UD, "fr.kathryn.woop"); r = sim("install", UD, APP)
verdict(r.returncode == 0, "app réinstallée (base vide) sur le simulateur libre")
log = "/tmp/woop-verif-widgets.log"
with open(log, "w") as out:
    proc = subprocess.Popen(["xcrun", "simctl", "launch", "--console-pty", "--terminate-running-process", UD, "fr.kathryn.woop",
                             "-skipAuth", "-sessionBanc", "-widgetsBanc"], stdout=out, stderr=subprocess.STDOUT)
tel = {}
t0 = time.time()
while time.time() - t0 < 120:
    time.sleep(2)
    lignes = [l for l in open(log, errors="ignore").read().splitlines() if l.startswith("[widgets]")]
    # la DERNIÈRE impression de chaque fenêtre (la passe se rejoue quand le pull insère)
    for l in lignes:
        m = re.match(r"\[widgets\] (\w+) → (.*)", l)
        if m:
            tel[m.group(1)] = dict((k, float(v) if "." in v else int(v)) for k, v in re.findall(r"(\w+) ([\d.]+)", m.group(2)))
    pull = [l for l in open(log, errors="ignore").read().splitlines() if "[pull]" in l]
    if tel.get("mois", {}).get("faites", 0) > 0 and len(pull) >= 1 and time.time() - t0 > 25:
        break
sim("terminate", UD, "fr.kathryn.woop"); sim("shutdown", UD)
print("    pull :", [l.split("[pull]")[-1].strip()[:70] for l in pull][:2])
for fen in ("semaine", "mois"):
    t = tel.get(fen)
    verdict(bool(t), f"{fen} : le téléphone a imprimé ses chiffres")
    if not t: continue
    print(f"    {fen} : " + " · ".join(f"{k} {t.get(k)}" for k in CHAMPS))
    for k in CHAMPS:
        sv, tv = serveur[fen][k], t.get(k)
        egal = abs(float(sv) - float(tv)) < 0.51 if k in ("volume", "volume_precedent") else float(sv) == float(tv)
        verdict(egal, f"{fen} · {k} : serveur {sv} = téléphone {tv}")
    verdict(t.get("seuil") == serveur[fen]["seuil"], f"{fen} · seuil : serveur {serveur[fen]['seuil']} = téléphone {t.get('seuil')}")

print(f"\n{N_OK} ✓ · {N_KO} ✗ — " + ("TOUT EST VERT" if ok else "✗ AU MOINS UNE PREUVE MANQUE"))
sys.exit(0 if ok else 1)
