# Mindcore SysOps

Reusable scripts and practical guidance for operating websites, Drupal
projects, and the infrastructure around them. The goal is a small, reviewable
toolbox: clear prerequisites, safe defaults, and instructions that explain how
to verify recovery.

This repository is public. Examples are generalized from real operational
patterns and must not contain production hostnames, credentials, private keys,
customer data, or unredacted backups. Review and test every script in a
disposable environment before scheduling it or using it against production.

## First tools

- [`scripts/backup-mariadb.sh`](scripts/backup-mariadb.sh): compressed,
  checksummed database dump with local retention.
- [`scripts/verify-backup.sh`](scripts/verify-backup.sh): verifies the dump's
  checksum and compressed stream.
- [`docs/backup-and-restore.md`](docs/backup-and-restore.md): setup, integrity
  checks, and isolated restore rehearsal.
- [`scripts/backup-mariadb-mega.sh`](scripts/backup-mariadb-mega.sh): backs up
  eligible MariaDB/MySQL databases locally or over SSH and uploads snapshots
  through MEGAcmd.
- [`docs/backup-mariadb-mega.md`](docs/backup-mariadb-mega.md): MEGA setup,
  retention, cron configuration, and operational limits.
- [`examples/github-actions/drupal-ci.yml.example`](examples/github-actions/drupal-ci.yml.example):
  an adaptable CI workflow kept outside the active workflow directory.
- [`docs/ci-cd.md`](docs/ci-cd.md): CI and deployment safeguards.
- [`skills/drupal-backend/SKILL.md`](skills/drupal-backend/SKILL.md) and
  [`skills/drupal-testing/SKILL.md`](skills/drupal-testing/SKILL.md): reusable
  agent guidance for Drupal implementation and test work.

## Repository structure

```text
docs/       operational runbooks and design notes
examples/   reviewed templates that are not active by default
scripts/    small reusable utilities
skills/     portable AI-agent instructions
```

## Status

Treat each script as an example until its documented prerequisites, failure
behavior, and recovery steps have been tested for the target environment. A
successful backup command alone does not prove a recoverable backup; rehearse a
restore in isolation.

## Contributing

Keep tools provider-neutral where practical. For provider-specific examples,
document the required CLI and identity model, parameterize account and resource
names, avoid embedding credentials, and include a safe test procedure.
