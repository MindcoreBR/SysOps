# MariaDB and MySQL backup example

`scripts/backup-mariadb.sh` creates a compressed dump for one database, checks
the gzip stream, writes a SHA-256 sidecar, and applies age-based local
retention. It does not upload, encrypt, or restore data. Treat every dump as
sensitive data and protect its destination accordingly.

## Requirements

- Bash 4 or later.
- `mysqldump`, `gzip`, `sha256sum`, `find`, `mktemp`, `date`, and `cut`.
- A MySQL option file outside the repository, readable only by the service
  account that runs the backup.

Example option file at `~/.my.cnf`:

```ini
[client]
host=127.0.0.1
user=backup_user
password=replace-this-outside-the-repository
```

Set restrictive permissions and do not commit this file:

```sh
chmod 600 "$HOME/.my.cnf"
```

## Run

```sh
DB_NAME=appdb \
MYSQL_DEFAULTS_FILE="$HOME/.my.cnf" \
BACKUP_DIR="/var/backups/appdb" \
RETENTION_DAYS=14 \
./scripts/backup-mariadb.sh
```

The script writes a UTC timestamped `.sql.gz` file and a matching `.sha256`
file. Keep backups on a separate storage system as well as locally. Configure
object-storage encryption, access controls, lifecycle retention, and
credentials through the provider's supported mechanisms; never put credentials
in this repository or in command-line arguments.

## Verify the artifact

Run the helper, or perform the checks manually, before attempting a restore:

```sh
./scripts/verify-backup.sh /var/backups/appdb/appdb-YYYYMMDDTHHMMSSZ.sql.gz
```

The equivalent manual checks are:

```sh
cd /var/backups/appdb
sha256sum --check appdb-YYYYMMDDTHHMMSSZ.sql.gz.sha256
gzip --test appdb-YYYYMMDDTHHMMSSZ.sql.gz
```

These checks confirm file integrity, not recoverability. A backup is proven
only when a restore has succeeded in an isolated environment.

## Restore rehearsal

Create a disposable database on a staging or recovery system, then restore into
that database using a protected MySQL option file:

```sh
mysql --defaults-extra-file="$HOME/.my.cnf" -e \
  'CREATE DATABASE restore_rehearsal CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
gzip --decompress --stdout appdb-YYYYMMDDTHHMMSSZ.sql.gz |
  mysql --defaults-extra-file="$HOME/.my.cnf" restore_rehearsal
```

Confirm the application can read the restored data and record the restore
duration and any manual steps. Do not point a rehearsal at a production
database. A production restore needs a separate, reviewed recovery procedure,
an explicit target, and a fresh backup of the current target first.

## Operational limits

- `--single-transaction` is suitable for transactional tables such as InnoDB.
  Review locking and consistency requirements for other storage engines.
- The script keeps local backups only. Add a separately tested off-site upload
  step for the storage provider you use.
- Retention is based on filesystem modification time and is limited to matching
  dump files in `BACKUP_DIR`.
- Test this example against a disposable database before scheduling it.
