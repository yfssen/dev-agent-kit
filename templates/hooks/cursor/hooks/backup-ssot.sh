#!/usr/bin/env bash
# Cursor preCompact SSOT backup (POSIX). ASCII only, no BOM. Side-effect only.
# Snapshots docs/*.md before context compaction so progress is never lost.
set +e
cat >/dev/null 2>&1

docs="./docs"
[ -d "$docs" ] || exit 0

backup="$docs/.ssot-backups"
mkdir -p "$backup"
stamp="$(date '+%Y%m%d-%H%M%S')"

for f in "$docs"/*.md; do
  [ -f "$f" ] || continue
  cp -f "$f" "$backup/$stamp-$(basename "$f")" 2>/dev/null
done

# Prune: keep newest 40 snapshots.
ls -1t "$backup"/*.md 2>/dev/null | tail -n +41 | while read -r old; do
  rm -f "$old"
done
exit 0
