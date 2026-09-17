---
name: scaffold-dev-agent
description: >-
  Scaffolds a project into a development agent using the dev-agent-kit
  (memory + scripts + SSOT + adapters), then runs 二开 init/learn: structure,
  architecture, CRUD, dual-git, and MUST ask the user for MySQL connection
  command/DSN (or accept「无库」to skip DB for frontend-only projects), write
  .env when applicable, and fill DB review docs. Use when installing
  开发智能体, 项目初始化, or applying dev-agent-kit for Cursor/Claude/Codex/Kiro/WorkBuddy/Qoder.
description_zh: "安装开发智能体：拷贝记忆/脚本/SSOT/adapters，按 init-workflow 做项目初始化分析；有库要 MySQL，无库可回「无库」跳过。用于 scaffold-dev-agent、开发智能体、项目初始化。"
description_en: "Install a development agent (memory + scripts + SSOT + adapters) and run init-workflow. Ask for MySQL or accept 无库 for frontend-only."
---

# Scaffold Development Agent

Turn **any project** (including mid-development / 二开) into a development agent:
long-term memory + real scripts + closed loop + **one-shot project learn**.

## Hard rule: read then merge (never blind overwrite)

For **in-progress projects**, existing files win on project facts. Kit content is merged in.

1. Run the merge-safe installer (default: **no** `-Force` / `--force`).
2. Tags: `[NEW]` / `[SAME]` / `[MERGE]` (`path.kit-new`).
3. Every `[MERGE]`: **read existing + `*.kit-new` → merge → delete `*.kit-new`**.
4. `-Force` only when user explicitly wants overwrite.

### Merge policy

| Keep from existing | Add from kit |
|--------------------|--------------|
| Product facts, pitfalls, working scripts | Tool table, loop, missing adapters |
| `.env` / secrets / business code | Never copy secrets |

## Preconditions

1. Resolve kit root `KIT`:
   - Prefer `kit-path.txt` next to this `SKILL.md` (one line, absolute path). **Do not ask the user for the path if this file exists and is valid.**
   - Else ask once, or search for `dev-agent-kit` near common roots.
2. Target = workspace root (for dual-git: **parent folder that contains FE+BE**).
3. Do not invent business rules; prefer code evidence.
4. When writing code: encoding **UTF-8** (not GBK), **without BOM**; comments/docstrings **no emoji**.

## Workflow

```
Progress:
- [ ] 1. Detect OS + AI tools + layout (single vs dual-git)
- [ ] 2. Merge-safe install (core + adapters)
- [ ] 3. Resolve MERGE (read → merge → delete *.kit-new)
- [ ] 4. Project init/learn (REQUIRED unless user skips) — see init-workflow.md
- [ ] 5. Adapt scripts (.env path, lint, smoke, api-check)
- [ ] 6. Verify tools (db/mysql/lint/smoke/api-check as available)
```

### 1) Detect

| Signal | Tool |
|--------|------|
| `.cursor/` / Cursor | cursor |
| `CLAUDE.md` / Claude | claude |
| Codex | codex |
| `.kiro/` / Kiro | kiro |
| WorkBuddy / CodeBuddy / `.codebuddy/` | workbuddy |
| Qoder / `.qoder/` | qoder |

Also detect: child dirs with own `.git` → **dual-git** (record in AGENTS + 架构文档).

Default adapters if unclear: `cursor,claude` (+ `workbuddy` / `qoder` if those tools are in use).

### 2) Install (merge-safe)

```powershell
& "$KIT/skills/scaffold-dev-agent/scripts/install.ps1" -KitRoot $KIT -ProjectRoot . -Adapters "cursor,claude,workbuddy,qoder"
```

```bash
"$KIT/skills/scaffold-dev-agent/scripts/install.sh" "$KIT" . cursor,claude,workbuddy,qoder
```

exit 0 = clean; exit 2 = MERGE_NEEDED.

### 3) Merge pass

Read both sides; keep project facts; add kit tooling; delete `*.kit-new`.

Before merging line by line, classify each MERGE:

- Kit side is an **unfilled template** (placeholders like `<one-liner>` / `NN%` / `YYYY-MM-DD`) -> keep the project version, just delete the `*.kit-new`.
- Kit side is a **pure superset** (project never diverged) -> take the kit version as-is.
- Both sides have unique content -> only these need a real line-by-line merge.

### 4) Project init/learn（一口气做完）

**Follow [init-workflow.md](init-workflow.md).** Summary:

1. `./scripts/scan-project.ps1 -OutFile docs/_scan-raw.md`
2. **向用户索要 MySQL 连接命令或 DSN**（必问）→ 有库则 `apply-mysql-dsn` 写 `.env` → 填复盘文档 → `SELECT 1`；**用户回「无库」则复盘标跳过，不写假 .env，不阻塞后续学习**
3. Deep-read FE（+BE if any）→ `docs/项目结构与架构.md` + `AGENTS.md` + SSOT（无后端时写明待建）
4. Point scripts `# ADAPT`（含 `.env` 路径，双 git 常为 backend；无库可暂不改 db 路径）
5. 有库时：账号可全权限；写库须用户同意并用 `mysql.*`，且记入复盘日志

### 5–6) Adapt + verify

`# ADAPT` lint/smoke/api-check paths; then spot-check tools.
**Also run [init-workflow.md](init-workflow.md) Step D** (BOM / path normalize / curl status / empty env Join-Path) — install only copies files; it does not prove scripts work.

## Daily tools

| Use | Windows | Unix |
|-----|---------|------|
| Scan | `./scripts/scan-project.ps1` | `./scripts/scan-project.sh` |
| MySQL shell | `./scripts/mysql.ps1` | `./scripts/mysql.sh` |
| Read-only SQL | `./scripts/db.ps1 "..."` | `./scripts/db.sh "..."` |
| Lint / smoke / reconcile | `lint` / `smoke` / `api-check` | same |

## Closed loop

```
locate (SSOT + rg + scan hot files) → read hits only → api-check (summary) → db → code → lint → smoke → update SSOT rows touched
```

Do not dump `_scan-raw.md` or whole trees into the reply. Default `api-check` already truncates mismatch lists (`-All` / `ALL=1` for full).

## Non-goals

- Not an agent framework; do not dump business into kit
- Architecture doc ≠ progress SSOT

## References

- [init-workflow.md](init-workflow.md)
- [adapter-map.md](adapter-map.md)
- `$KIT/README.md` / `$KIT/操作文档.md`
