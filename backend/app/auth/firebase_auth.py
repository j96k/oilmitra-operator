import os

import firebase_admin
from firebase_admin import auth, credentials
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

security = HTTPBearer(auto_error=False)
_initialized = False


def _init_firebase():
    global _initialized
    if _initialized or firebase_admin._apps:
        _initialized = True
        return True

    # Try env var pointing to service account JSON file
    path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
    candidates = [
        path,
        "backend/firebase-service-account.json",
        "firebase-service-account.json",
        "/etc/secrets/firebase-service-account.json",
    ]
    for p in candidates:
        if p and os.path.isfile(p):
            cred = credentials.Certificate(p)
            firebase_admin.initialize_app(cred)
            _initialized = True
            return True

    # Try env var containing the JSON itself
    json_str = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if json_str:
        import json

        cred = credentials.Certificate(json.loads(json_str))
        firebase_admin.initialize_app(cred)
        _initialized = True
        return True

    return False


async def verify_firebase_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    """Verify a Firebase ID token and return the decoded payload."""
    if not _init_firebase():
        raise HTTPException(
            status_code=503,
            detail="Firebase phone login is not configured on this server.",
        )
    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing Firebase token")
    try:
        decoded = auth.verify_id_token(credentials.credentials)
        return decoded
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid Firebase token")
