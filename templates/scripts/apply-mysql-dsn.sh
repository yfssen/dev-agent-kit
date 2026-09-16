#!/usr/bin/env bash
# [apply-mysql-dsn] Write .env from mysql CLI command or DSN. ASCII-only.
# Usage:
#   ./scripts/apply-mysql-dsn.sh --command 'mysql -h127.0.0.1 -P3306 -uroot -pSecret -Dmydb'
#   ./scripts/apply-mysql-dsn.sh --dsn 'mysql://user:pass@127.0.0.1:3306/mydb'
#   ./scripts/apply-mysql-dsn.sh --env-path backend/.env --command '...'

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ENV_PATH="$ROOT/.env"
COMMAND=""
DSN=""

while [ "${1:-}" != "" ]; do
  case "$1" in
    --command) COMMAND="$2"; shift 2 ;;
    --dsn) DSN="$2"; shift 2 ;;
    --env-path) ENV_PATH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$ENV_PATH" in
  /*) ;;
  *) ENV_PATH="$ROOT/$ENV_PATH" ;;
esac

HOSTNAME=""; HOSTPORT="3306"; USERNAME=""; PASSWORD=""; DATABASE=""

if [ -n "$DSN" ]; then
  # mysql://user:pass@host:port/db
  if printf '%s' "$DSN" | grep -Eq '^mysql://[^:/]+:[^@]*@[^:/]+(:[0-9]+)?/[^?\s]+$'; then
    USERNAME=$(printf '%s' "$DSN" | sed -n 's|^mysql://\([^:]*\):.*|\1|p')
    PASSWORD=$(printf '%s' "$DSN" | sed -n 's|^mysql://[^:]*:\([^@]*\)@.*|\1|p')
    HOSTNAME=$(printf '%s' "$DSN" | sed -n 's|^mysql://[^@]*@\([^:/]*\).*|\1|p')
    HOSTPORT=$(printf '%s' "$DSN" | sed -n 's|^mysql://[^@]*@[^:/]*:\([0-9]*\)/.*|\1|p')
    [ -z "$HOSTPORT" ] && HOSTPORT="3306"
    DATABASE=$(printf '%s' "$DSN" | sed -n 's|^mysql://[^/]*/\([^?]*\)|\1|p' | tr -d '/')
  else
    echo "Unsupported DSN" >&2
    exit 2
  fi
elif [ -n "$COMMAND" ]; then
  HOSTNAME=$(printf '%s' "$COMMAND" | sed -n 's/.*-h[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -n1)
  [ -z "$HOSTNAME" ] && HOSTNAME=$(printf '%s' "$COMMAND" | sed -n 's/.*--host[= ]\([^[:space:]]*\).*/\1/p' | head -n1)
  HOSTPORT=$(printf '%s' "$COMMAND" | sed -n 's/.*-P[[:space:]]*\([0-9]*\).*/\1/p' | head -n1)
  [ -z "$HOSTPORT" ] && HOSTPORT=$(printf '%s' "$COMMAND" | sed -n 's/.*--port[= ]\([0-9]*\).*/\1/p' | head -n1)
  [ -z "$HOSTPORT" ] && HOSTPORT="3306"
  USERNAME=$(printf '%s' "$COMMAND" | sed -n 's/.*-u[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -n1)
  PASSWORD=$(printf '%s' "$COMMAND" | sed -n 's/.*-p\([^[:space:]-]*\).*/\1/p' | head -n1)
  DATABASE=$(printf '%s' "$COMMAND" | sed -n 's/.*-D[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -n1)
else
  echo "Provide --command or --dsn" >&2
  exit 2
fi

if [ -z "$HOSTNAME" ] || [ -z "$USERNAME" ] || [ -z "$DATABASE" ]; then
  echo "Parsed incomplete connection (need host, user, database)." >&2
  exit 2
fi

mkdir -p "$(dirname "$ENV_PATH")"
tmp=$(mktemp)
if [ -f "$ENV_PATH" ]; then
  # strip CR then rewrite keys
  tr -d '\r' < "$ENV_PATH" | awk -v h="$HOSTNAME" -v p="$HOSTPORT" -v u="$USERNAME" -v w="$PASSWORD" -v d="$DATABASE" '
    BEGIN { OFS="" }
    /^HOSTNAME=/ { print "HOSTNAME=" h; seen_h=1; next }
    /^HOSTPORT=/ { print "HOSTPORT=" p; seen_p=1; next }
    /^USERNAME=/ { print "USERNAME=" u; seen_u=1; next }
    /^PASSWORD=/ { print "PASSWORD=" w; seen_w=1; next }
    /^DATABASE=/ { print "DATABASE=" d; seen_d=1; next }
    { print }
    END {
      if (!seen_h) print "HOSTNAME=" h
      if (!seen_p) print "HOSTPORT=" p
      if (!seen_u) print "USERNAME=" u
      if (!seen_w) print "PASSWORD=" w
      if (!seen_d) print "DATABASE=" d
    }
  ' >"$tmp"
else
  printf 'HOSTNAME=%s\nHOSTPORT=%s\nUSERNAME=%s\nPASSWORD=%s\nDATABASE=%s\n' \
    "$HOSTNAME" "$HOSTPORT" "$USERNAME" "$PASSWORD" "$DATABASE" >"$tmp"
fi
mv "$tmp" "$ENV_PATH"

echo "Wrote .env (password hidden): host=$HOSTNAME port=$HOSTPORT user=$USERNAME db=$DATABASE"
echo "path=$ENV_PATH"
echo "Next: fill docs DB review markdown without password; run db.sh \"SELECT 1 AS ok\""
exit 0
