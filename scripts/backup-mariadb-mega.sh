#!/usr/bin/env bash
# Back up eligible MariaDB/MySQL databases locally or over SSH, then upload
# the compressed snapshots to a MEGAcmd remote directory.

set -Eeuo pipefail
umask 077
export TZ=UTC

fail() {
  printf 'backup-mariadb-mega: %s\n' "$*" >&2
  exit 1
}

: "${MEGA_REMOTE_ROOT:?Set MEGA_REMOTE_ROOT, for example /Backups/mysql.}"

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/mysql}"
LOG_FILE="${LOG_FILE:-$HOME/backup-logs/mysql-mega-backup.log}"
LOCK_FILE="${LOCK_FILE:-$HOME/.mysql-mega-backup.lock}"
MYSQL_BIN="${MYSQL_BIN:-mariadb}"
DUMP_BIN="${DUMP_BIN:-mariadb-dump}"
MYSQL_DEFAULTS_FILE="${MYSQL_DEFAULTS_FILE:-$HOME/.my.cnf}"
SSH_TARGET="${SSH_TARGET:-}"
REMOTE_MYSQL_DEFAULTS_FILE="${REMOTE_MYSQL_DEFAULTS_FILE:-}"
ALERT_TO="${ALERT_TO:-}"

# MEGA retention: one snapshot per day for seven days, four weekly, six monthly.
REMOTE_DAILY_DAYS="${REMOTE_DAILY_DAYS:-7}"
WEEKLY_KEEP="${WEEKLY_KEEP:-4}"
MONTHLY_KEEP="${MONTHLY_KEEP:-6}"
# Local retention: three snapshots per day for four days, plus weekly/monthly.
LOCAL_DAILY_DAYS="${LOCAL_DAILY_DAYS:-4}"
LOCAL_DAILY_KEEP="${LOCAL_DAILY_KEEP:-3}"

for value_name in REMOTE_DAILY_DAYS WEEKLY_KEEP MONTHLY_KEEP LOCAL_DAILY_DAYS LOCAL_DAILY_KEEP; do
  value="${!value_name}"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$value_name must be a positive integer."
done

mkdir -p -- "$BACKUP_ROOT" "$(dirname -- "$LOG_FILE")" "$(dirname -- "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# Keep a bounded diagnostic log rather than allowing cron output to grow forever.
if [[ -f "$LOG_FILE" ]] && (( $(stat -c '%s' "$LOG_FILE") > 5242880 )); then
  : > "$LOG_FILE"
fi
exec >>"$LOG_FILE" 2>&1
log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
log 'backup started'

run_dir=""
remote_run=""
remote_complete=false
cleanup_on_error() {
  local status=$?
  trap - EXIT
  if ((status != 0)); then
    log "backup failed (status=$status)"
    if [[ -n "$remote_run" && "$remote_complete" != true ]]; then
      timeout 120 mega-rm -rf "$remote_run" >/dev/null 2>&1 || true
    fi
    if [[ -n "$run_dir" && -d "$run_dir" ]]; then
      log "removing incomplete local snapshot $run_dir"
      rm -rf -- "$run_dir"
    fi
    if [[ -n "$ALERT_TO" && -x "$(command -v msmtp || true)" ]]; then
      if {
        printf 'To: %s\n' "$ALERT_TO"
        printf 'Subject: MySQL MEGA backup failed\n'
        printf 'Content-Type: text/plain; charset=UTF-8\n\n'
        printf 'Backup failed at %s (status %s).\n\n' "$(date -Is)" "$status"
        tail -n 60 "$LOG_FILE"
      } | timeout 30 msmtp -- "$ALERT_TO"; then
        log "failure alert accepted by SMTP for $ALERT_TO"
      else
        log 'could not send failure alert by email'
      fi
    elif [[ -n "$ALERT_TO" ]]; then
      log 'msmtp is unavailable; failure alert was not sent'
    fi
  fi
  exit "$status"
}
trap cleanup_on_error EXIT

# Execute a database command locally, or quote each argument for the remote shell.
source_exec() {
  if [[ -n "$SSH_TARGET" ]]; then
    local remote_command
    printf -v remote_command '%q ' "$@"
    timeout --signal=TERM --kill-after=30 6h ssh \
      -o BatchMode=yes -o ConnectTimeout=30 -o ServerAliveInterval=60 \
      "$SSH_TARGET" "$remote_command"
  else
    "$@"
  fi
}

for command_name in gzip sha256sum mega-ls mega-put mega-mkdir mega-rm python3 flock timeout stat; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done
if [[ -n "$SSH_TARGET" ]]; then
  command -v ssh >/dev/null 2>&1 || fail 'Required command not found: ssh'
  [[ -n "$REMOTE_MYSQL_DEFAULTS_FILE" ]] || fail 'Set REMOTE_MYSQL_DEFAULTS_FILE when SSH_TARGET is used.'
  [[ "$REMOTE_MYSQL_DEFAULTS_FILE" = /* ]] || fail 'REMOTE_MYSQL_DEFAULTS_FILE must be an absolute remote path.'
  source_exec test -r "$REMOTE_MYSQL_DEFAULTS_FILE" || fail 'Remote MySQL option file is unreadable.'
  [[ "$(source_exec stat -c '%a' "$REMOTE_MYSQL_DEFAULTS_FILE")" == 600 ]] || fail 'Remote MySQL option file must have mode 600.'
  source_exec command -v "$MYSQL_BIN" >/dev/null || fail "Remote command not found: $MYSQL_BIN"
  source_exec command -v "$DUMP_BIN" >/dev/null || fail "Remote command not found: $DUMP_BIN"
else
  [[ -r "$MYSQL_DEFAULTS_FILE" ]] || fail "MySQL option file is unreadable: $MYSQL_DEFAULTS_FILE"
  [[ "$(stat -c '%a' "$MYSQL_DEFAULTS_FILE")" == 600 ]] || fail "MySQL option file must have mode 600: $MYSQL_DEFAULTS_FILE"
  command -v "$MYSQL_BIN" >/dev/null 2>&1 || fail "Required command not found: $MYSQL_BIN"
  command -v "$DUMP_BIN" >/dev/null 2>&1 || fail "Required command not found: $DUMP_BIN"
fi
if [[ -n "$ALERT_TO" ]]; then
  command -v msmtp >/dev/null 2>&1 || fail 'ALERT_TO is set but msmtp is unavailable.'
fi

mysql_query() {
  local defaults_file="$MYSQL_DEFAULTS_FILE"
  if [[ -n "$SSH_TARGET" ]]; then defaults_file="$REMOTE_MYSQL_DEFAULTS_FILE"; fi
  source_exec "$MYSQL_BIN" "--defaults-extra-file=$defaults_file" --batch --skip-column-names "$@"
}

dump_database() {
  local defaults_file="$MYSQL_DEFAULTS_FILE"
  if [[ -n "$SSH_TARGET" ]]; then defaults_file="$REMOTE_MYSQL_DEFAULTS_FILE"; fi
  source_exec "$DUMP_BIN" "--defaults-extra-file=$defaults_file" \
    --single-transaction --quick --routines --events --triggers \
    --hex-blob --default-character-set=utf8mb4 "$@"
}

ensure_mega_dir() {
  local target="$1"
  # MEGAcmd can return status 54 when mkdir -p targets an existing directory.
  if timeout 120 mega-ls "$target" >/dev/null 2>&1; then return 0; fi
  if timeout 120 mega-mkdir -p "$target" >/dev/null 2>&1; then return 0; fi
  if timeout 120 mega-ls "$target" >/dev/null 2>&1; then return 0; fi
  log "MEGA directory is unavailable or could not be created: $target"
  return 1
}

ensure_mega_dir "$MEGA_REMOTE_ROOT"

database_query="SELECT SCHEMA_NAME FROM information_schema.SCHEMATA
 WHERE SCHEMA_NAME NOT IN ('information_schema','performance_schema','mysql','sys')
   AND LOWER(SCHEMA_NAME) NOT LIKE 'mysql%'
   AND LOWER(SCHEMA_NAME) NOT LIKE '%test'
 ORDER BY SCHEMA_NAME"
database_output="$(mysql_query --execute="$database_query")"
[[ -n "$database_output" ]] || fail 'No eligible databases were found.'
mapfile -t databases <<<"$database_output"

stamp="$(date -u +%Y%m%d-%H%M)"
run_dir="$BACKUP_ROOT/$stamp"
[[ ! -e "$run_dir" ]] || fail "Local snapshot already exists for $stamp; retry in another minute."
mkdir -m 700 -- "$run_dir"

for database in "${databases[@]}"; do
  safe_database="$(printf '%s' "$database" | LC_ALL=C tr -cs 'A-Za-z0-9._-' '_')"
  dump_file="$run_dir/${safe_database}.sql.gz"
  escaped_database="$(printf '%s' "$database" | sed "s/'/''/g")"
  table_query="SELECT TABLE_NAME FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = '$escaped_database' AND TABLE_NAME LIKE 'cache%' ORDER BY TABLE_NAME"
  table_output="$(mysql_query --execute="$table_query")"
  cache_tables=()
  if [[ -n "$table_output" ]]; then mapfile -t cache_tables <<<"$table_output"; fi
  ignore_args=()
  for table in "${cache_tables[@]}"; do
    [[ -n "$table" ]] && ignore_args+=("--ignore-table=$database.$table")
  done
  log "dumping $database (excluding ${#ignore_args[@]} cache% tables)"
  dump_database "${ignore_args[@]}" --databases "$database" | gzip -1 > "$dump_file"
  gzip --test "$dump_file"
done

printf '%s\n' "${databases[@]}" > "$run_dir/databases.txt"
(
  cd -- "$run_dir"
  sha256sum ./*.sql.gz databases.txt > SHA256SUMS
)

remote_run="$MEGA_REMOTE_ROOT/$stamp"
ensure_mega_dir "$remote_run"
if ! timeout --signal=TERM --kill-after=30 6h mega-put "$run_dir"/* "$remote_run" >/dev/null 2>&1; then
  fail 'MEGA upload failed or exceeded six hours.'
fi

remote_listing="$(timeout 120 mega-ls "$remote_run" 2>/dev/null)" || fail 'Could not list the uploaded snapshot on MEGA.'
for file in "$run_dir"/*; do
  grep -Fxq -- "$(basename -- "$file")" <<<"$remote_listing" || fail "Uploaded file is missing on MEGA: $(basename -- "$file")"
done
remote_complete=true

# Remote retention only considers timestamped directories created by this script.
python3 - "$MEGA_REMOTE_ROOT" "$stamp" "$REMOTE_DAILY_DAYS" "$WEEKLY_KEEP" "$MONTHLY_KEEP" <<'PYREMOTE'
import datetime as dt
import re
import subprocess
import sys

root, current, daily_days, weekly_keep, monthly_keep = sys.argv[1:]
daily_days, weekly_keep, monthly_keep = map(int, (daily_days, weekly_keep, monthly_keep))
utc = dt.timezone.utc

def parse_stamp(name):
    if re.fullmatch(r"\d{8}-\d{4}", name):
        return dt.datetime.strptime(name, "%Y%m%d-%H%M").replace(tzinfo=utc)
    if re.fullmatch(r"\d{8}T\d{6}Z", name):
        return dt.datetime.strptime(name, "%Y%m%dT%H%M%SZ").replace(tzinfo=utc)
    return None

now = parse_stamp(current)
listing = subprocess.run(
    ["mega-ls", "-l", "--time-format=ISO6081_WITH_TIME", root],
    check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120
).stdout
runs = []
for line in listing.splitlines():
    fields = line.split()
    if len(fields) >= 5 and fields[0].startswith("d"):
        when = parse_stamp(fields[-1])
        if when is not None:
            runs.append((when, fields[-1]))
runs.sort(reverse=True)
if not any(name == current for _, name in runs):
    raise SystemExit("current snapshot is not listed; remote retention cancelled")

keep = {current}
daily, weekly, monthly = {}, {}, {}
for when, name in runs:
    age = (now.date() - when.date()).days
    if 0 <= age < daily_days:
        daily.setdefault(when.date(), []).append((when, name))
    if 0 <= age < 28:
        weekly.setdefault(when.isocalendar()[:2], []).append((when, name))
    if 0 <= age < 183:
        monthly.setdefault((when.year, when.month), []).append((when, name))
for group in daily.values():
    keep.add(max(group)[1])
for group in sorted(weekly.values(), key=lambda g: max(x[0] for x in g), reverse=True)[:weekly_keep]:
    keep.add(max(group)[1])
for group in sorted(monthly.values(), key=lambda g: max(x[0] for x in g), reverse=True)[:monthly_keep]:
    keep.add(max(group)[1])
for _, name in runs:
    if name not in keep:
        target = f"{root}/{name}"
        print(f"Removing old MEGA snapshot: {target}")
        result = subprocess.run(
            ["timeout", "120", "mega-rm", "-rf", target],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=130
        )
        if result.returncode != 0:
            raise SystemExit(f"could not remove old MEGA snapshot: {name}")
PYREMOTE

# Local retention: keep the most recent N runs per day, plus weekly and monthly snapshots.
python3 - "$BACKUP_ROOT" "$LOCAL_DAILY_DAYS" "$LOCAL_DAILY_KEEP" "$WEEKLY_KEEP" "$MONTHLY_KEEP" <<'PYLOCAL'
import datetime as dt
import pathlib
import re
import shutil
import sys

root = pathlib.Path(sys.argv[1])
daily_days, daily_keep, weekly_keep, monthly_keep = map(int, sys.argv[2:])
utc = dt.timezone.utc

def parse_stamp(name):
    if re.fullmatch(r"\d{8}-\d{4}", name):
        return dt.datetime.strptime(name, "%Y%m%d-%H%M").replace(tzinfo=utc)
    if re.fullmatch(r"\d{8}T\d{6}Z", name):
        return dt.datetime.strptime(name, "%Y%m%dT%H%M%SZ").replace(tzinfo=utc)
    return None

now = dt.datetime.now(utc)
runs = []
for path in root.iterdir():
    when = parse_stamp(path.name) if path.is_dir() else None
    if when is not None:
        runs.append((when, path))
runs.sort(reverse=True)
keep = set()
daily, weekly, monthly = {}, {}, {}
for when, path in runs:
    age = (now.date() - when.date()).days
    if 0 <= age < daily_days:
        daily.setdefault(when.date(), []).append((when, path))
    if 0 <= age < 28:
        weekly.setdefault(when.isocalendar()[:2], []).append((when, path))
    if 0 <= age < 183:
        monthly.setdefault((when.year, when.month), []).append((when, path))
for group in daily.values():
    keep.update(path for _, path in sorted(group, reverse=True)[:daily_keep])
for group in sorted(weekly.values(), key=lambda g: max(x[0] for x in g), reverse=True)[:weekly_keep]:
    keep.add(max(group)[1])
for group in sorted(monthly.values(), key=lambda g: max(x[0] for x in g), reverse=True)[:monthly_keep]:
    keep.add(max(group)[1])
for when, path in runs:
    if path not in keep:
        shutil.rmtree(path)
        print(f"Removed old local snapshot: {path}")
PYLOCAL

trap - EXIT
log "backup completed: $remote_run"
