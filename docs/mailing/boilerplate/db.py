"""SQLite schema and conservative campaign queries."""
import os
import re
import sqlite3
from . import config

EMAIL_RE = re.compile(r"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")

def connect():
    directory = os.path.dirname(config.DB_PATH)
    if directory:
        os.makedirs(directory, exist_ok=True)
    connection = sqlite3.connect(config.DB_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection

def init():
    with connect() as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS contacts (
            email TEXT PRIMARY KEY,
            name TEXT NOT NULL DEFAULT '',
            enabled INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS campaigns (
            name TEXT PRIMARY KEY,
            subject TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS suppressions (
            email TEXT PRIMARY KEY,
            reason TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'local',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS deliveries (
            campaign TEXT NOT NULL,
            email TEXT NOT NULL,
            status TEXT NOT NULL,
            detail TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (campaign, email)
        );
        """)

def normalize_email(email):
    return email.strip().lower()

def add_contact(email, name=""):
    email = normalize_email(email)
    if not EMAIL_RE.match(email):
        raise ValueError("invalid email syntax")
    with connect() as db:
        db.execute("INSERT OR IGNORE INTO contacts(email, name) VALUES (?, ?)", (email, name.strip()))

def suppress(email, reason, source="local"):
    email = normalize_email(email)
    with connect() as db:
        db.execute("INSERT OR REPLACE INTO suppressions(email, reason, source) VALUES (?, ?, ?)", (email, reason, source))
        db.execute("UPDATE contacts SET enabled = 0 WHERE email = ?", (email,))

def campaign_recipients(campaign, limit):
    with connect() as db:
        return db.execute("""
            SELECT c.email, c.name FROM contacts c
            WHERE c.enabled = 1
              AND NOT EXISTS (SELECT 1 FROM suppressions s WHERE s.email = c.email)
              AND NOT EXISTS (
                  SELECT 1 FROM deliveries d
                  WHERE d.campaign = ? AND d.email = c.email AND d.status = 'sent'
              )
            ORDER BY c.created_at, c.email
            LIMIT ?
        """, (campaign, limit)).fetchall()

def record_delivery(campaign, email, status, detail=""):
    with connect() as db:
        db.execute(
            "INSERT OR REPLACE INTO deliveries(campaign, email, status, detail) VALUES (?, ?, ?, ?)",
            (campaign, normalize_email(email), status, detail[:500]),
        )
