#!/usr/bin/env bash
# Create a compressed, checksummed MariaDB/MySQL dump for one database.
# Credentials are read from a MySQL option file and never passed on the CLI.

set -Eeuo pipefail
umask 077

fail() {
  printf 'backup-mariadb: %s\n' "$*" >&2
  exit 1
}

: "${DB_NAME:?Set DB_NAME to the database to back up.}"
: "${MYSQL_DEFAULTS_FILE:?Set MYSQL_DEFAULTS_FILE to a protected MySQL option file.}"
: "${BACKUP_DIR:?Set BACKUP_DIR to the destination directory.}"

[[ "$DB_NAME" =~ ^[A-Za-z0-9_-]+$ ]] || fail 'DB_NAME may contain only letters, digits, underscores, and hyphens.'
[[ -f "$MYSQL_DEFAULTS_FILE" ]] || fail 'MYSQL_DEFAULTS_FILE does not point to a regular file.'

RETENTION_DAYS="${RETENTION_DAYS:-14}"
[[ "$RETENTION_DAYS" =~ ^[1-9][0-9]*$ ]] || fail 'RETENTION_DAYS must be a positive integer.'

for command_name in mysqldump gzip sha256sum cut find mktemp date; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

mkdir -p -- "$BACKUP_DIR"
backup_dir=$(cd -- "$BACKUP_DIR" && pwd -P)
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
archive="$backup_dir/${DB_NAME}-${timestamp}.sql.gz"
checksum="$archive.sha256"
[[ ! -e "$archive" && ! -e "$checksum" ]] || fail "Backup already exists for timestamp $timestamp. Retry in a second."

temporary_archive=$(mktemp "$backup_dir/.${DB_NAME}.XXXXXXXX")
temporary_checksum="${temporary_archive}.sha256"
published=0

cleanup() {
  rm -f -- "$temporary_archive" "$temporary_checksum"
  if [[ "$published" -eq 0 ]]; then
    rm -f -- "$archive" "$checksum"
  fi
}
trap cleanup EXIT

# Keep --defaults-extra-file as the first mysqldump option. The option file
# should be readable only by the account running this script (for example 0600).
mysqldump \
  --defaults-extra-file="$MYSQL_DEFAULTS_FILE" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --hex-blob \
  --default-character-set=utf8mb4 \
  "$DB_NAME" | gzip --stdout > "$temporary_archive"

gzip --test "$temporary_archive"
hash=$(sha256sum "$temporary_archive" | cut -d ' ' -f 1)
printf '%s  %s\n' "$hash" "$(basename -- "$archive")" > "$temporary_checksum"

mv -- "$temporary_archive" "$archive"
mv -- "$temporary_checksum" "$checksum"
published=1

# Retention only removes matching dump files in this destination directory.
while IFS= read -r -d '' expired_archive; do
  rm -f -- "$expired_archive" "$expired_archive.sha256"
done < <(find "$backup_dir" -maxdepth 1 -type f \
  -name "${DB_NAME}-*.sql.gz" -mtime "+${RETENTION_DAYS}" -print0)

printf 'Backup created: %s\n' "$archive"
printf 'Checksum:       %s\n' "$checksum"
