#!/bin/sh
# [git-remote-add] Attach an existing remote URL and prove it with git ls-remote.
# ASCII-only. Does not git config, commit, or push.
# If ls-remote fails, the remote added by this run is removed.
# Usage:
#   ./scripts/git-remote-add.sh --repo backend --url 'git@host:backend.git'
#   ./scripts/git-remote-add.sh --repo . --url 'https://host/repo.git' --name origin

set -eu

repo="."
url=""
name="origin"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --url) url="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    *) echo "FAIL unknown arg"; exit 2 ;;
  esac
done

fail() {
  echo "FAIL $1"
  exit "$2"
}

printf '%s' "$name" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || fail "remote name rejected" 2

ok=0
printf '%s' "$url" | grep -Eq '^git@[A-Za-z0-9._-]+:[A-Za-z0-9._+/-]+$' && ok=1
printf '%s' "$url" | grep -Eq '^ssh://([A-Za-z0-9._-]+@)?[A-Za-z0-9._-]+(:[0-9]+)?/[A-Za-z0-9._+/-]+$' && ok=1
printf '%s' "$url" | grep -Eq '^https?://([A-Za-z0-9._-]+(:[^@/]*)?@)?[A-Za-z0-9._-]+(:[0-9]+)?/[A-Za-z0-9._+/-]+$' && ok=1
printf '%s' "$url" | grep -Eq '^file:///[A-Za-z]:/[A-Za-z0-9._+/-]+$' && ok=1
printf '%s' "$url" | grep -Eq '^file:///[A-Za-z0-9._+/-]+$' && ok=1
[ "$ok" -eq 1 ] || fail "url rejected" 2

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

case "$repo" in
  /*|[A-Za-z]:*) abs="$repo" ;;
  *) abs="$project_root/$repo" ;;
esac

if [ ! -d "$abs" ]; then
  fail "not a git repo" 2
fi
abs=$(CDPATH= cd -- "$abs" && pwd)

case "$abs" in
  "$project_root"|"$project_root"/*) ;;
  *) fail "repo outside project" 2 ;;
esac

[ -e "$abs/.git" ] || fail "not a git repo" 2
command -v git >/dev/null 2>&1 || fail "git not on PATH" 2

if (cd "$abs" && git remote) | grep -Fxq "$name"; then
  fail "remote $name already set" 2
fi

if ! (cd "$abs" && git remote add "$name" "$url"); then
  fail "git remote add failed" 2
fi

if ! (cd "$abs" && git ls-remote "$name") >/dev/null 2>&1; then
  (cd "$abs" && git remote remove "$name") || true
  fail "ls-remote failed; remote removed" 3
fi

echo "OK repo=$repo remote=$name ls-remote=ok"
exit 0
