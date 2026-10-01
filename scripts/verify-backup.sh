#!/usr/bin/env bash
# Verify a compressed dump and its adjacent SHA-256 sidecar.

set -Eeuo pipefail

fail() {
  printf 'verify-backup: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 ]] || fail 'Usage: verify-backup.sh FILE.sql.gz'
archive=$1
[[ -f "$archive" ]] || fail "Backup file not found: $archive"
[[ -f "${archive}.sha256" ]] || fail "Checksum file not found: ${archive}.sha256"

command -v sha256sum >/dev/null 2>&1 || fail 'Required command not found: sha256sum'
command -v gzip >/dev/null 2>&1 || fail 'Required command not found: gzip'

archive_dir=$(cd -- "$(dirname -- "$archive")" && pwd -P)
archive_name=$(basename -- "$archive")
(
  cd -- "$archive_dir"
  sha256sum --check "${archive_name}.sha256"
  gzip --test "$archive_name"
)

printf 'Backup integrity verified: %s\n' "$archive"
