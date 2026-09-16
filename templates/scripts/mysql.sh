#!/usr/bin/env bash
# [mysql-shell] Open interactive MySQL using .env. ASCII-only.
# Password via MYSQL_PWD env (not argv). See tooling / AGENTS.md.
# ADAPT: .env path + key names (HOSTNAME/DATABASE/USERNAME/PASSWORD/HOSTPORT).

set -eu

MYSQL_BIN=""
if [ -n "${LZ_MYSQL:-}" ] && [ -x "$LZ_MYSQL" ]; then
  MYSQL_BIN="$LZ_MYSQL"
elif command -v mysql >/dev/null 2>&1; then
  MYSQL_BIN="mysql"
fi
if [ -z "$MYSQL_BIN" ]; then
  echo "mysql client not found. Set LZ_MYSQL or add to PATH." >&2
  exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ENV_PATH="$SCRIPT_DIR/../.env"   # ADAPT: often backend/.env in dual-git layout
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

echo "Connecting ${USERNAME}@${HOSTNAME}:${HOSTPORT}/${DATABASE} (password hidden)"

export MYSQL_PWD="$PASSWORD"
cleanup() { unset MYSQL_PWD; }
trap cleanup EXIT

if [ "$#" -gt 0 ]; then
  "$MYSQL_BIN" -h "$HOSTNAME" -P "$HOSTPORT" -u "$USERNAME" -D "$DATABASE" --default-character-set=utf8 "$@"
else
  "$MYSQL_BIN" -h "$HOSTNAME" -P "$HOSTPORT" -u "$USERNAME" -D "$DATABASE" --default-character-set=utf8
fi
