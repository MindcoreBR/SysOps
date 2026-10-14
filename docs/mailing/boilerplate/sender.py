"""Plain-text/HTML rendering and conservative SMTP delivery."""
import html
import json
import smtplib
from email.message import EmailMessage
from . import config
from . import db
from .unsubscribe import url

def render(campaign, subject, email, name):
    display_name = name or email.split("@", 1)[0]
    safe_name = html.escape(display_name)
    link = html.escape(url(email, campaign), quote=True)
    text = "Hello {0},\\n\\nWe have an update for you.\\n\\nUnsubscribe: {1}\\n".format(display_name, link)
    markup = "<p>Hello {0},</p><p>We have an update for you.</p><p><a href="{1}">Unsubscribe</a></p>".format(safe_name, link)
    return text, markup

def send_one(campaign, subject, email, name, dry_run=False):
    text, markup = render(campaign, subject, email, name)
    if dry_run:
        db.record_delivery(campaign, email, "dry-run")
        return "dry-run"
    if not all((config.SMTP_HOST, config.SMTP_FROM)):
        raise RuntimeError("SMTP_HOST and SMTP_FROM are required")
    message = EmailMessage()
    message["From"] = config.SMTP_FROM
    message["To"] = email
    message["Subject"] = subject
    message.set_content(text)
    message.add_alternative(markup, subtype="html")
    with smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT, timeout=30) as smtp:
        smtp.starttls()
        if config.SMTP_USER:
            smtp.login(config.SMTP_USER, config.SMTP_PASSWORD)
        smtp.send_message(message)
    db.record_delivery(campaign, email, "sent")
    return "sent"

def send_batch(campaign, subject, limit=25, dry_run=True):
    results = []
    for contact in db.campaign_recipients(campaign, limit):
        try:
            status = send_one(campaign, subject, contact["email"], contact["name"], dry_run)
            results.append({"email": contact["email"], "status": status})
        except Exception as exc:
            db.record_delivery(campaign, contact["email"], "failed", str(exc))
            results.append({"email": contact["email"], "status": "failed", "detail": str(exc)})
    return results

def write_report(results, path="state/last-batch.json"):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as stream:
        json.dump(results, stream, indent=2)
