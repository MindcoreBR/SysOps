"""Environment configuration for the mailing boilerplate."""
import os

DB_PATH = os.environ.get("MAILING_DB", "state/mailing.db")
PUBLIC_URL = os.environ.get("MAILING_PUBLIC_URL", "http://localhost:8080")
UNSUBSCRIBE_SECRET = os.environ.get("MAILING_UNSUBSCRIBE_SECRET", "")
SMTP_HOST = os.environ.get("SMTP_HOST", "")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
SMTP_FROM = os.environ.get("SMTP_FROM", "")
