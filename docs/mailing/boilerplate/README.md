# Mailing Boilerplate

A small Python 3 reference implementation for opt-in email campaigns.

## Features

- SQLite contacts, campaigns, deliveries, and suppressions;
- normalized email addresses and deduplication;
- signed unsubscribe URLs;
- hard-bounce and complaint suppression;
- dry-run by default;
- bounded batches and JSONL delivery logs;
- SMTP adapter using standard-library modules only.

This is a starting point, not a bulk-mail provider. Add provider-specific webhooks, authentication, rate limits, retries, monitoring, and legal/compliance review before production use.

## Quick start

```sh
export MAILING_DB=./state/mailing.db
export MAILING_PUBLIC_URL=https://mailing.example.com
export MAILING_UNSUBSCRIBE_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"

python3 -m boilerplate.cli init
python3 -m boilerplate.cli add-contact player@example.com "Example Player"
python3 -m boilerplate.cli create-campaign reactivation "Welcome back"
python3 -m boilerplate.cli send reactivation --dry-run --limit 25
```

For real delivery, configure `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, and `SMTP_FROM`, then remove `--dry-run`. Start with a single internal test recipient.

## Layout

- `config.py`: environment configuration;
- `db.py`: schema and safe data access;
- `unsubscribe.py`: signed URL generation and suppression;
- `sender.py`: templates, batch selection, SMTP delivery;
- `cli.py`: operational commands.

Never commit `state/`, contact exports, delivery logs, secrets, or production configuration.
