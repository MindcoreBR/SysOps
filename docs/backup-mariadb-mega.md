# MariaDB/MySQL backups to MEGA with MEGAcmd

`backup-mariadb-mega.sh` creates one compressed dump per eligible database,
checks each gzip stream, writes a database manifest and SHA-256 checksums, and
uploads the snapshot with MEGAcmd. It supports a local database or a source
database reached over SSH. Dumps stream through SSH to the backup host; MySQL
credentials stay on the source database host.

The script excludes system schemas, every schema whose name starts with
`mysql`, schemas whose names end in `test`, and tables whose names start with
`cache`. Cache tables are omitted entirely. Dumps use `--single-transaction`,
so review consistency requirements for nontransactional tables.

## Requirements

- Bash 4 or later and Python 3.
- MariaDB/MySQL client and dump utility on the database source host.
- MEGAcmd authenticated as the account that runs the script.
- `gzip`, `sha256sum`, `flock`, `timeout`, and `stat` on the backup host.
- `ssh` when `SSH_TARGET` is configured.
- Optional: `msmtp` configured for the backup account when `ALERT_TO` is set.

Install MEGAcmd using the supported package for the target OS and architecture.
Run `mega-login` once as the same Unix account that will run the scheduled
backup, then confirm `mega-ls /` works for that account. Do not run MEGAcmd as
root if cron will run the backup as another user.

Create a protected MySQL option file on the database source host, outside this
repository:

```ini
[client]
host=127.0.0.1
user=backup_user
password=provide-this-outside-the-repository
```

Set its owner to the backup account and permissions to `0600`. The user needs
read access to the eligible schemas, tables, routines, events, and triggers.

## Install and configure

Copy the script to a stable path and make it executable:

```sh
sudo install -o root -g root -m 0755 scripts/backup-mariadb-mega.sh \
  /usr/local/sbin/backup-mariadb-mega
```

The local database mode uses these variables:

```text
MEGA_REMOTE_ROOT=/Backups/mysql
MYSQL_DEFAULTS_FILE=/home/backup/.my.cnf
BACKUP_ROOT=/var/backups/mysql
LOG_FILE=/home/backup/backup-logs/mysql-mega-backup.log
ALERT_TO=ops@example.invalid
```

For a database on another host, configure SSH public-key access for the backup
account and an SSH alias in its `~/.ssh/config`. The remote account needs its
own protected MySQL option file. Set these variables instead of
`MYSQL_DEFAULTS_FILE`:

```text
MEGA_REMOTE_ROOT=/Backups/remote-db
SSH_TARGET=db-backup-host
REMOTE_MYSQL_DEFAULTS_FILE=/home/db-backup/.my.cnf
BACKUP_ROOT=/var/backups/mysql
LOG_FILE=/home/backup/backup-logs/remote-db-mega-backup.log
```

Verify noninteractive SSH and the MEGA session as the backup account before
adding cron:

```sh
ssh -o BatchMode=yes db-backup-host true
mega-ls /Backups
```

For either mode, run once interactively with the selected environment, then
check the local snapshot, the corresponding directory on MEGA, and the log.
The script names snapshots `YYYYMMDD-HHmm` in UTC. It retains one MEGA snapshot
per day for seven days, four weekly snapshots, and six monthly snapshots. Local
retention keeps three snapshots per day for four days, four weekly snapshots,
and six monthly snapshots. Only timestamped directories in the configured
backup root are considered by retention.

## Schedule with cron

Add the configuration variables to the backup account's crontab, followed by
the schedule. These example times are UTC:

```cron
CRON_TZ=UTC
MEGA_REMOTE_ROOT=/Backups/mysql
MYSQL_DEFAULTS_FILE=/home/backup/.my.cnf
BACKUP_ROOT=/var/backups/mysql
LOG_FILE=/home/backup/backup-logs/mysql-mega-backup.log
ALERT_TO=ops@example.invalid
0 2,10,18 * * * /usr/local/sbin/backup-mariadb-mega >/dev/null 2>&1
```

For SSH mode, replace `MYSQL_DEFAULTS_FILE` with `SSH_TARGET` and
`REMOTE_MYSQL_DEFAULTS_FILE`. Do not put passwords, private keys, or MEGA
session files in the repository. Configure `msmtp` and its sender identity
outside the repository if email alerts are needed.

## Recovery and operational limits

The script checks gzip integrity and SHA-256 checksums before upload, then
confirms each local file appears in the MEGA snapshot directory. These checks
do not prove that a database can be restored. Use
[`backup-and-restore.md`](backup-and-restore.md) for an isolated restore
rehearsal and recovery guidance.

Run the script as a dedicated unprivileged account. Restrict access to its
local backup root, logs, MySQL option file, SSH private key, and MEGAcmd session
state. The script intentionally deletes older timestamped backup directories
according to its retention policy; choose a dedicated MEGA directory and local
backup root that contain no unrelated files.
