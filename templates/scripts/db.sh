#!/usr/bin/env bash
# [query-state] Read-only DB query helper. Reads .env. See tooling rules.
# Allowed: SINGLE statement starting with SELECT/SHOW/DESCRIBE/DESC/EXPLAIN.
# Rejects multi-statement (;) and file I/O. Encoding: ASCII-only (no BOM).
# ADAPT: for Postgres/other, swap the client resolution + invocation at the bottom.

set -eu

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 \"<read-only SQL>\"" >&2
  exit 2
fi
SQL="$1"

# --- Single statement only: ONE trailing ';' is allowed; separators and \g / \G are not ---
NORM=$(printf '%s' "$SQL" | sed -e 's/[[:space:]]*$//' -e 's/;$//' -e 's/[[:space:]]*$//')
case "$NORM" in
  *';'*)
    echo "Read-only helper: multi-statement SQL is not allowed (no ';' separator, no \\g / \\G)." >&2
    exit 1
    ;;
esac
if printf '%s' "$NORM" | grep -Eq '\\[gG]' ; then
  echo "Read-only helper: multi-statement SQL is not allowed (no ';' separator, no \\g / \\G)." >&2
  exit 1
fi

# --- Whitelist: statement must START with a read-only keyword ---
trimmed=$(printf '%s' "$SQL" | sed 's/^[[:space:]]*//')
case "$trimmed" in
  [Ss][Ee][Ll][Ee][Cc][Tt]*|[Ss][Hh][Oo][Ww]*|[Dd][Ee][Ss][Cc][Rr][Ii][Bb][Ee]*|[Dd][Ee][Ss][Cc][[:space:]]*|[Ee][Xx][Pp][Ll][Aa][Ii][Nn]*)
    ;;
  *)
    echo "Read-only helper: only SELECT/SHOW/DESCRIBE/EXPLAIN are allowed." >&2
    exit 1
    ;;
esac

# --- Hard-block file I/O ---
if printf '%s' "$SQL" | grep -Eiq '\b(INTO[[:space:]]+OUTFILE|INTO[[:space:]]+DUMPFILE|LOAD_FILE|LOAD[[:space:]]+DATA)\b'; then
  echo "Read-only helper: file I/O is not allowed." >&2
  exit 1
fi

# --- Resolve client: $LZ_MYSQL > PATH ---
MYSQL_BIN=""
if [ -n "${LZ_MYSQL:-}" ] && [ -x "$LZ_MYSQL" ]; then
  MYSQL_BIN="$LZ_MYSQL"
elif command -v mysql >/dev/null 2>&1; then
  MYSQL_BIN="mysql"
fi
if [ -z "$MYSQL_BIN" ]; then
  echo "mysql client not found. Set LZ_MYSQL, or add it to PATH." >&2
  exit 2
fi

# --- Read connection from .env (strip CR for Windows CRLF) ---   # ADAPT
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ENV_PATH="$SCRIPT_DIR/../.env"
if [ ! -f "$ENV_PATH" ]; then
  echo ".env not found: $ENV_PATH" >&2
  exit 2
fi

HOSTNAME=""; DATABASE=""; USERNAME=""; PASSWORD=""; HOSTPORT="3306"
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
  case "$line" in
    HOSTNAME=*) HOSTNAME=${line#HOSTNAME=} ;;
    DATABASE=*) DATABASE=${line#DATABASE=} ;;
    USERNAME=*) USERNAME=${line#USERNAME=} ;;
    PASSWORD=*) PASSWORD=${line#PASSWORD=} ;;
    HOSTPORT=*) HOSTPORT=${line#HOSTPORT=} ;;
  esac
done < "$ENV_PATH"

if [ -z "$HOSTNAME" ] || [ -z "$USERNAME" ] || [ -z "$DATABASE" ]; then
  echo ".env missing HOSTNAME/USERNAME/DATABASE." >&2
  exit 2
fi

export MYSQL_PWD="$PASSWORD"
cleanup() { unset MYSQL_PWD; }
trap cleanup EXIT

"$MYSQL_BIN" -h "$HOSTNAME" -P "$HOSTPORT" -u "$USERNAME" -D "$DATABASE" --default-character-set=utf8 -e "$SQL"
