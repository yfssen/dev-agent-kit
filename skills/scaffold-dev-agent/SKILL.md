---
name: scaffold-dev-agent
description: >-
  Already on this machine. When the user says scaffold-dev-agent, 开发智能体,
  or 项目初始化, read this file. init-workflow.md is the sibling file, not a
  second skill. Do not use find-skills or the skill marketplace for these
  names. Then scaffold the project (memory + scripts + SSOT + adapters) and
  run init/learn: structure, architecture, CRUD, dual-git. MUST ask for a
  MySQL connection command/DSN, or accept「无库」for frontend-only projects.
  Ask for an existing git remote URL per repo, or accept「无远程」.
description_zh: "本机已有的开发智能体安装技能。用户说 scaffold-dev-agent、开发智能体、项目初始化时直接读本文件；init-workflow.md 在同目录，不是另一个技能。不要用 find-skills，不要去技能市场搜索这两个名字。有库要 MySQL，无库可回「无库」。已有 git 地址问一次，可回「无远程」。"
description_en: "Local skill, already installed. When the user names scaffold-dev-agent or init-workflow, read this file and the sibling init-workflow.md. Do not search the skill marketplace or find-skills. Ask for MySQL or accept 无库. Ask for an existing git remote URL or accept 无远程."
---

# Scaffold Development Agent

## 先读本目录，不要去市场搜

`scaffold-dev-agent` 就是本文件。`init-workflow` 不是技能名，是同目录的 `init-workflow.md`。
技能市场和 find-skills 搜不到这两个名字。市场返回空是正常结果，继续读这两个文件，不要停。

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
- [ ] 5. Fill project-progress snapshot (no YYYY-MM-DD leftover) + ADAPT kit-layout / lint / smoke / api-check
- [ ] 6. Verify tools (db/mysql/lint/smoke/api-check/verify as available)
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

- Kit side is an **unfilled template** (placeholders like `<one-liner>` / `NN%` / `YYYY-MM-DD`) and the project file is already filled -> keep the project snapshot facts, but **still copy new kit behavior lines** the project lacks (「改代码必须写 SSOT」, SSOT = workspace-root `docs/*.md`, multi-git). Do not revert a filled snapshot back to placeholders. Then delete `*.kit-new`.
- Kit side is a **pure superset** (project never diverged) -> take the kit version as-is.
- Both sides have unique content -> line-by-line merge. **Project facts** = `# ADAPT` values (BaseUrl, ProbePath, `.env` path, checker command, filled progress). **Kit behavior** = multi-git scan (`kit-layout`), root-docs SSOT, code extensions, cooldown. Old single-repo `git status`, `.php`-only, and 1200s cooldown are previous kit defaults, not project facts — replace them with the `*.kit-new` behavior.
- Leaving any `*.kit-new` in place means the upgrade did not land. The installer's `MERGE GUIDE` lines say the same thing; follow them.

### 4) Project init/learn（一口气做完）

**Follow [init-workflow.md](init-workflow.md).** Summary:

1. `./scripts/scan-project.ps1 -OutFile docs/_scan-raw.md`
2. **Git layout** — follow init-workflow Step A2 then A3. Read `- advice:` and either record it or ask once. Local `git init` only after the user picks a folder. Then ask once for an existing remote URL on each `repo_remotes` entry that is `none`, or accept「无远程」. `git-remote-add` proves the URL with `ls-remote`. Do not open a Gitee or GitHub repo. Do not commit, do not push, do not `git config`.
3. **向用户索要 MySQL 连接命令或 DSN**（必问）→ 有库则 `apply-mysql-dsn` 写 `.env` → 填复盘文档 → `SELECT 1`；**用户回「无库」则复盘标跳过，不写假 .env，不阻塞后续学习**
4. Deep-read FE（+BE if any）→ `docs/项目结构与架构.md` + `AGENTS.md` + SSOT（无后端时写明待建）
5. **填 adapter `project-progress` 快照**（禁止留下 `YYYY-MM-DD` / `<一句话>`）；写清「改代码必须写 SSOT」
6. Point scripts `# ADAPT`（含 `kit-layout` 多 git / 代码扩展名；`.env` 路径，双 git 常为 backend；无库可暂不改 db 路径）
7. 有库时：账号可全权限；写库须用户同意并用 `mysql.*`，且记入复盘日志

### Upgrade（项目里已有旧工具，本次能力当时还没有）

升级不是重做初始化。顺序是：

1. merge-safe 安装。`scripts/scan-project.ps1` 和 `.sh` 若与套件不同，会写成 `*.kit-new`。
2. 旧项目的扫描脚本没有 `## Git layout`。这一段是套件行为，从 `*.kit-new` 合进项目里的脚本。项目改过的 `# ADAPT` 保留。合完删掉 `*.kit-new`。
3. 用合完的 `scripts/scan-project` 再扫一次。`record_single` / `record_multi` 只核对，不改已有仓库。`ask_children` 列出还没有 `.git` 的项目目录并问一次。`ask_empty` 升级时不再问。`- repo_remotes:` 里仍然是 `none` 的仓库，按 Step A3 问一次已有地址，或接受「无远程」。已经有远程名的不动。不在网站上新建仓库，不提交，不推送。

### 5–6) Adapt + verify

`# ADAPT` kit-layout（多 git + 扩展名）/ lint/smoke/api-check/verify paths; then spot-check tools (end with `scripts/verify`). **多仓项目不 ADAPT reminder = 假自动维护。**
**Also run [init-workflow.md](init-workflow.md) Step D** (BOM / path normalize / curl status / empty env Join-Path / PATHEXT / scan hot files actually printed) — install only copies files; it does not prove scripts work.

## Daily tools

| Use | Windows | Unix |
|-----|---------|------|
| Scan | `./scripts/scan-project.ps1` | `./scripts/scan-project.sh` |
| MySQL shell | `./scripts/mysql.ps1` | `./scripts/mysql.sh` |
| Read-only SQL | `./scripts/db.ps1 "..."` | `./scripts/db.sh "..."` |
| Lint / smoke / reconcile / gate | `lint` / `smoke` / `api-check` / **`verify`** | same |

## Closed loop

```
read progress inventory → open only those hits → code → run verify → quote Done: yes
```

**Read.** On a new session, read `docs/项目进度与完成度.md` section 二 and the last 10 rows of section 六. Then open only the code those rows point at. Do not read every doc. Do not delete older section 六 rows.

**Size.** If the request already says what to change and where, do it. If it is several independent pieces, finish one through `Done: yes` before starting the next. If the change grows, stop and say so.

**Behavior vs internals.** Update `docs/项目结构与架构.md` in the same turn only when observable behavior changes (API, table meaning, route, permission, git layout). Read that matching section in full before editing it. A refactor, tooling edit, or docs-only edit gets a section 六 row and does not rewrite the architecture doc.

**Bug.** Read the error, reproduce it once, then edit. The first `[FAIL]` line is the only next edit. Re-run the same `verify`.

**Done.** Claim done only by quoting `== Done: yes ==` from a `verify` run in this same turn (`Result: PASS` and `WARN=0`). Exit code 1 happens only on `FAIL`. A `WARN` still exits 0 and prints `Done: no`. The latest section 六 row must contain each changed code path (`admin/x.php`, not only a summary). `verify` lists any path the row omits. Add that row and re-run. In that same reply, name any changed file the task did not ask for. The next session opens the paths in that row.

Do not dump `_scan-raw.md` or whole trees into the reply. Default `api-check` already truncates mismatch lists (`-All` / `ALL=1` for full).

## Non-goals

- Not an agent framework; do not dump business into kit
- Architecture doc ≠ progress SSOT

## References

- [init-workflow.md](init-workflow.md)
- [adapter-map.md](adapter-map.md)
- `$KIT/README.md` / `$KIT/操作文档.md`
