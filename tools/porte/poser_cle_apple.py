#!/usr/bin/env python3
"""Installe la clé Apple autorisée sans secret dans les logs/arguments.

Sonde apple-jeton sur un compte QA jetable nettoyé, avec un code factice.
Aucun compte existant, aucune Forge et aucun téléphone manipulés.
"""
from pathlib import Path
from datetime import datetime, timezone
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[2]
REF = "ytnnyjkramgiqyxdrkcu"
URL = "https://" + REF + ".supabase.co"
CLIENT = "fr.kathryn.woop"  # identité existante ; nom affiché : Nosfy


def request(url, key, body=None, method="POST", api_key=None):
    headers = {"Authorization": "Bearer " + key, "Content-Type": "application/json"}
    if api_key:
        headers["apikey"] = api_key
    req = urllib.request.Request(url, method=method, headers=headers,
        data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            return response.status, json.loads(response.read() or "null")
    except urllib.error.HTTPError as error:
        try:
            return error.code, json.loads(error.read() or "null")
        except (ValueError, UnicodeError):
            return error.code, {}


def require(ok, label):
    print(("PASS " if ok else "FAIL ") + label, flush=True)
    if not ok:
        raise RuntimeError(label)


def main():
    if len(sys.argv) != 4:
        raise RuntimeError("Usage : poser-cle-apple.sh <fichier.p8> <KEY_ID> <TEAM_ID>")
    path = Path(sys.argv[1]).expanduser().resolve()
    kid, team = sys.argv[2:]
    require(bool(re.fullmatch(r"[A-Z0-9]{10}", kid)) and
            bool(re.fullmatch(r"[A-Z0-9]{10}", team)), "format Key ID / Team ID")
    pem = path.read_text().strip()
    require(pem.startswith("-----BEGIN PRIVATE KEY-----") and
            pem.endswith("-----END PRIVATE KEY-----"), "fichier PKCS8 présent")
    check = subprocess.run(["node", "-e",
        "const {createPrivateKey}=require('node:crypto');"
        "const {readFileSync}=require('node:fs');"
        "const k=createPrivateKey(readFileSync(process.argv[1]));"
        "process.exit(k.asymmetricKeyType==='ec' && "
        "k.asymmetricKeyDetails.namedCurve==='prime256v1'?0:1)", str(path)], capture_output=True)
    require(check.returncode == 0, "clé EC P-256 lisible")
    token = (ROOT / ".secrets/supabase-access-token").read_text().strip()
    admin = (ROOT / ".secrets/supabase-service-role").read_text().strip()
    public = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"',
        (ROOT / "Nosfy/Services/Supabase.swift").read_text()).group(1)
    values = {"APPLE_KEY_ID": kid, "APPLE_TEAM_ID": team,
              "APPLE_CLIENT_ID": CLIENT, "APPLE_PRIVATE_KEY": pem}
    env = os.environ.copy()
    env["SUPABASE_ACCESS_TOKEN"] = token
    # Fichier temporaire 0600, jamais dans le dépôt ; supprimé même en échec.
    fd, env_path = tempfile.mkstemp(prefix="nosfy-apple-", suffix=".env")
    try:
        with os.fdopen(fd, "w") as file:
            file.write("\n".join(k + "=" + json.dumps(v) for k, v in values.items()) + "\n")
        pushed = subprocess.run(["supabase", "secrets", "set", "--project-ref", REF,
            "--env-file", env_path], cwd=ROOT, env=env, capture_output=True, timeout=90)
        require(pushed.returncode == 0, "quatre secrets Apple configurés")
    finally:
        Path(env_path).unlink(missing_ok=True)
    status, listed = request("https://api.supabase.com/v1/projects/" + REF + "/secrets",
                             token, method="GET")
    names = {item["name"] for item in listed} if status == 200 and isinstance(listed, list) else set()
    require(all(name in names for name in values), "présence des quatre secrets relue")
    uid = None
    try:
        email = "nosfy-apple-qa-" + str(uuid.uuid4()) + "@example.invalid"
        password = secrets.token_urlsafe(30)
        status, user = request(URL + "/auth/v1/admin/users", admin,
            {"email": email, "password": password, "email_confirm": True,
             "app_metadata": {"nosfy_qa": "apple-key-probe"}}, api_key=admin)
        if isinstance(user, dict):
            uid = user.get("id")
        require(status in (200, 201) and bool(uid), "compte QA temporaire créé")
        status, session = request(URL + "/auth/v1/token?grant_type=password", public,
            {"email": email, "password": password}, api_key=public)
        require(status == 200 and bool(session.get("access_token")), "session QA ordinaire")
        for attempt in range(3):
            status, reply = request(URL + "/functions/v1/apple-jeton", session["access_token"],
                {"code": "nosfy-code-factice-" + str(uuid.uuid4())}, api_key=public)
            if reply.get("raison") != "cle_absente" or attempt == 2:
                break
            time.sleep(3)
        apple_error = None
        try:
            detail = json.loads(reply.get("detail", "{}"))
            if detail.get("error") in ("invalid_grant", "invalid_client", "invalid_request",
                                        "unauthorized_client", "unsupported_grant_type"):
                apple_error = detail["error"]
        except (TypeError, ValueError):
            pass
        raison = reply.get("raison")
        observation = {"lu_le_utc": datetime.now(timezone.utc).isoformat(),
            "key_id": kid, "team_id": team, "client_id": CLIENT,
            "secrets_presents": {name: name in names for name in values},
            "probe": {"http": status,
                "raison": raison if raison in ("apple_400", "cle_absente", "sans_session", "code_absent") else "autre",
                "apple_error": apple_error},
            "connexion_apple_reelle_testee": False, "revocation_reelle_testee": False}
        print(json.dumps(observation, ensure_ascii=False, indent=2), flush=True)
        require(status == 502 and raison == "apple_400", "la fonction joint Apple avec la clé chargée")
        require(apple_error == "invalid_grant", "Apple refuse le code factice (invalid_grant)")
    finally:
        if uid:
            status, _ = request(URL + "/auth/v1/admin/users/" + uid, admin,
                                method="DELETE", api_key=admin)
            require(status in (200, 204), "compte QA temporaire supprimé")
            status, _ = request(URL + "/auth/v1/admin/users/" + uid, admin,
                                method="GET", api_key=admin)
            require(status == 404, "suppression du compte QA relue")
    print("Configuration mesurée ; vraie connexion et révocation Apple encore à tester.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Ne pas imprimer d'exception contenant un corps de requête sensible.
        print("ARRÊT : " + type(error).__name__ + "; voir les contrôles ci-dessus.", file=sys.stderr)
        sys.exit(1)
