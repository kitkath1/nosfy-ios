"""Client App Store Connect local ; clé privée et jetons restent hors des preuves."""
from pathlib import Path
import base64
import json
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

APP_ID = '6813439459'
CONFIG = Path.home() / '.appstoreconnect/nosfy-api.json'


def token():
    config = json.loads(CONFIG.read_text())
    key = serialization.load_pem_private_key(
        Path(config['privateKeyPath']).read_bytes(), password=None)
    now = int(time.time())
    header = {'alg': 'ES256', 'kid': config['keyId'], 'typ': 'JWT'}
    payload = {'iss': config['issuerId'], 'iat': now - 10,
               'exp': now + 600, 'aud': 'appstoreconnect-v1'}

    def b64(value):
        return base64.urlsafe_b64encode(value).rstrip(b'=')

    data = b'.'.join(b64(json.dumps(v, separators=(',', ':')).encode())
                     for v in [header, payload])
    r, s = utils.decode_dss_signature(key.sign(data, ec.ECDSA(hashes.SHA256())))
    return (data + b'.' + b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))).decode()


def request(path, body=None, method='GET'):
    if not path.startswith(('/v1/', '/v2/')):
        raise ValueError('Un chemin App Store Connect /v1/ ou /v2/ est requis')
    req = urllib.request.Request('https://api.appstoreconnect.apple.com' + path,
        data=None if body is None else json.dumps(body).encode(), method=method,
        headers={'Authorization': 'Bearer ' + token(), 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            data = response.read()
            return response.status, json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())
