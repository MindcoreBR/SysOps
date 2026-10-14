"""Signed unsubscribe links and suppression handling."""
import hashlib
import hmac
from urllib.parse import urlencode
from . import config
from . import db

def token(email, campaign):
    if not config.UNSUBSCRIBE_SECRET:
        raise RuntimeError("MAILING_UNSUBSCRIBE_SECRET is not configured")
    payload = (campaign + "|" + db.normalize_email(email)).encode("utf-8")
    return hmac.new(config.UNSUBSCRIBE_SECRET.encode("utf-8"), payload, hashlib.sha256).hexdigest()

def url(email, campaign):
    query = urlencode({"email": db.normalize_email(email), "campaign": campaign, "token": token(email, campaign)})
    return config.PUBLIC_URL.rstrip("/") + "/unsubscribe?" + query

def accept(email, campaign, supplied_token):
    expected = token(email, campaign)
    if not hmac.compare_digest(expected, supplied_token):
        raise ValueError("invalid unsubscribe token")
    db.suppress(email, "unsubscribe", "https")
