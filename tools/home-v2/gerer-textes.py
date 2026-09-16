#!/usr/bin/env python3
"""Générer un brouillon FR/EN ou publier deux lots relus. Aucun secret imprimé.

python3 tools/home-v2/gerer-textes.py generer fr /tmp/home-fr.json
python3 tools/home-v2/gerer-textes.py publier /tmp/home-fr.json /tmp/home-en.json revision
"""
from pathlib import Path
import json
import sys
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[2]
URL = "https://ytnnyjkramgiqyxdrkcu.supabase.co/functions/v1/home-textes"


def appel(body):
    secret = (ROOT / ".secrets/supabase-service-role").read_text().strip()
    request = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST", headers={
        "Authorization": "Bearer " + secret, "apikey": secret, "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(request, timeout=110) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = json.loads(error.read().decode())
        raise SystemExit(f"HTTP {error.code}: {detail.get('raison', detail.get('message', 'refus'))}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "generer" and sys.argv[2] in ("fr", "en"):
        result = appel({"action": "generer", "langue": sys.argv[2]})
        Path(sys.argv[3]).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(f"Brouillon {sys.argv[2]} enregistré ; modèle {result.get('modele')}, non publié.")
    elif len(sys.argv) == 5 and sys.argv[1] == "publier":
        lots = [json.loads(Path(p).read_text())["lot"] for p in sys.argv[2:4]]
        print(json.dumps(appel({"action": "publier", "lots": lots, "revision": sys.argv[4]}), ensure_ascii=False))
    else:
        raise SystemExit(__doc__)
