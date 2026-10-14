# Campaign Mailing — Public Reference

This directory documents a minimal, privacy-conscious email campaign system built with:

- SQLite as the operational store;
- CSV/state files kept outside Git;
- HMAC-signed unsubscribe links;
- a protected administration panel;
- integration with a local MTA or transactional email provider.

## Workflow

1. Consolidate and deduplicate contacts.
2. Remove internal addresses, invalid records, hard bounces, complaints, and opt-outs.
3. Create a campaign with plain-text and HTML templates.
4. Run a dry run and send in small batches.
5. Record each attempt, bounce, complaint, and unsubscribe.
6. Never reuse suppressed addresses.

## Security

Keep secrets only in environment variables:

```text
OC_MAILING_UNSUBSCRIBE_SECRET=<strong-secret>
OC_MAILING_ADMIN_EMAIL=admin@example.com
OC_MAILING_PUBLIC_URL=https://mailing.example.com
```

Never commit databases, contact lists, operational CSV files, logs, tokens, or credentials.

## Unsubscribe

The link includes a signature derived from:

```text
sha256(campaign + "|" + email + "|" + secret)
```

The endpoint validates the signature before recording the opt-out. In production, administrative tokens should also have an expiration time and the signing secret should be rotated periodically.

## Operations

The administration panel should support:

- campaign browsing and creation;
- contact search and review;
- adding or updating contacts;
- recording an opt-out;
- removing a contact from future sends.

Sending should require explicit confirmation, a per-batch limit, and a final suppression-list review.

## Public-source boundary

The public example is intentionally simplified. Do not publish:

- real email addresses or contact exports;
- production SQLite databases;
- send logs or tracking data;
- OCI identifiers or credentials;
- administrative URLs or signing secrets.

The private project contains the provider-specific integration, reporting, checkpoints, and deployment configuration.
