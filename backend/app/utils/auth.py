from typing import Optional
from firebase_admin import auth as fb_auth


def get_uid(authorization: Optional[str]) -> Optional[str]:
    """Extract Firebase uid from a Bearer token header. Returns None if missing or invalid."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    try:
        token = authorization.split(" ", 1)[1]
        decoded = fb_auth.verify_id_token(token)
        return decoded.get("uid")
    except Exception:
        return None
