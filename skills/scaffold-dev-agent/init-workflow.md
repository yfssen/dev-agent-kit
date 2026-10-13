# Project init / learn workflow（二开标准初始化）

> 安装开发智能体后**默认一口气跑完**本流程。  
> **硬规则：必须向用户确认数据库**——有库则索要 MySQL 连接命令（或 DSN）并写 `.env`；**用户明确说「无库」则可跳过**，并在复盘文档记「跳过」。  
> 开发账号通常具备增删改查全权限；日常探查仍用只读 `db.*`，写库必须记复盘日志。

Run after merge-safe install + MERGE 处理完毕。

## When

- User asks to scaffold / install 开发智能体 on a **real** (often 二开) project
- User asks for 项目初始化 / 整体分析 / 标准开工

Skip only if user says「只装文件、先别分析」.  
**即使跳过深度分析，只要要用库，仍须索要连接信息。**  
**纯前端 / 暂无后端**：仍须问一次；用户回「无库」后按 Step B-skip，不阻塞其余学习。

## Layout: dual-git under one folder

```
<workspace>/          # kit files live here
  <backend>/          # own .git ; .env often here
  <frontend>/         # own .git
```

Frontend-only (common early stage):

```
<workspace>/          # kit files here
  vue-app/ or src/    # frontend only; no backend, no MySQL yet
```

1. Kit at workspace root (parent of FE+BE) unless user says otherwise.
2. Record each side path + own `.git` yes/no. If no backend: record「暂无后端 / 无库」.
3. Commit in the repo you changed.
4. Point `db`/`mysql`/`apply-mysql-dsn` `# ADAPT` `.env` to backend `.env` when dual-git.
5. SSOT is always **workspace-root** `docs/*.md`, even when child dirs (`admin/`, `pc_web/`, …) each have their own `.git`. Do not assume docs live inside the only git repo.
6. ADAPT `scripts/kit-layout.ps1` / `kit-layout.sh` (`$KitCodeExts` / `KIT_CODE_EXT`, optional `$KitRepoNames`). **Multi-git projects that skip this ADAPT have fake auto-maintenance**: root often has no `.git`, so an unadapted reminder `git status`s the root, exits 0, and never nudges.

## Step A — Structural scan

```powershell
./scripts/scan-project.ps1 -OutFile docs/_scan-raw.md
```

```bash
./scripts/scan-project.sh docs/_scan-raw.md
```

## Step A2 — Git layout（安装和升级都读这一段）

读扫描里的 `## Git layout`，只看 `- advice:`。不在 Gitee/GitHub 上新建仓库，不 `git config`，不提交，不推送。已有的远程地址在 Step A3 问。

升级时项目里可能还是旧的 `scripts/scan-project`，没有下面这张表。先把套件 `*.kit-new` 里的 `## Git layout` 合进项目脚本，再跑合完的扫描。没有这段就还是旧能力。

| advice | 安装时 | 升级时（脚本已含 Git layout） |
|--------|--------|--------|
| `record_single` | 记「单仓」，不问 | 同样只记，不改 |
| `record_multi` | 记「多仓」和已有 `.git` 的子目录，不问。根目录保持没有 git | 同样只记 |
| `ask_empty` | 问一次：不建 / 当前目录一个仓 / 先建子目录再各自建仓（可只先做一边） | 不再问。空目录选择只在第一次安装做 |
| `ask_children` | 只对 `project_dirs_without_git` 问一次：各建本机仓，或当前目录一个仓。根目录在「各建」时不建 git | 只列出还没有 `.git` 的目录，问一次。已有仓库不动 |
| `ask_parent` | 问一次：算上层仓库的一部分，还是当前目录单独建仓 | 同样问一次，不擅自建 |
| `nested` | 报告嵌套仓库（根和子目录都有 `.git`）。不再建仓 | 同样只报告 |

用户选定要建的文件夹后：先写 `.gitignore`（至少 `.env`、`node_modules`、`vendor`），再在该文件夹 `git init`。已有 `.git` 的跳过。`docs/`、`scripts/` 不建仓。

## Step A3 — 已有远程地址（安装和升级都问；必问一次）

本机仓库定下来之后再问。扫描 `- repo_remotes:` 里值是 `none` 的每一项问一个地址。`root=none` 表示工作区根这个仓库。子目录写成 `backend=none` 这种。已经有远程名的项不再问。

服务器上的空仓库由用户事先建好。工具只把地址写进本机仓库。

```text
这些本机仓库还没有远程地址：（按扫描列出）
请给每个目录一个已存在的地址：git@服务器:路径.git ，或 ssh:// ，或 https:// 。
全部不要远程，回复「无远程」。
某一个不要，写「目录名 无远程」。
```

用户给了地址才运行（密码不要写进 Markdown；回复里也不要回显带密码的 URL）：

```powershell
./scripts/git-remote-add.ps1 -Repo backend -Url 'git@服务器:backend.git'
```

```bash
./scripts/git-remote-add.sh --repo backend --url 'git@服务器:backend.git'
```

脚本用 `git ls-remote` 核对。成功才留下远程。失败会删掉刚加上的远程，并告诉用户。不 `git config`，不提交，不推送。

用户回「无远程」：在进度里记下跳过，不算初始化失败。升级时同样只问仍然是 `none` 的仓库。

## Step B — Ask for MySQL connection（必问；有库才写入）

**Do not guess password.**  
**Must ask once** — even if scan found no DB signals (confirm user is not missing config).

Ask the user (copy this prompt if needed):

```text
请提供开发库 MySQL 连接（任选一种）：
1) 完整命令，例如：
   mysql -h127.0.0.1 -P3306 -uroot -p你的密码 -D库名
2) DSN：
   mysql://用户:密码@主机:端口/库名
并说明：.env 应写在哪个路径（单仓根目录 / 双 git 的 backend/.env）？
账号一般具备增删改查权限即可。

若当前项目无 MySQL（纯前端 / 暂无后端），直接回复「无库」即可，
我会把 docs/数据库连接与复盘.md 标为跳过，并继续完成结构与进度文档。
```

### B1 — User provides connection

1. Run apply script（密码只进 `.env`，不要写入 Markdown、不要在回复里回显密码）:

```powershell
./scripts/apply-mysql-dsn.ps1 -Command '用户给的命令' -EnvPath 'backend\.env'
# or: -Dsn 'mysql://...'
```

```bash
./scripts/apply-mysql-dsn.sh --command '...' --env-path backend/.env
```

2. Fill `docs/数据库连接与复盘.md`：**主机/端口/用户/库名/.env 路径/权限说明**；**禁止写密码**.
3. Self-check: `./scripts/db.ps1 "SELECT 1 AS ok"`
4. Adapt `# ADAPT` `.env` path in `db.*` / `mysql.*` / `apply-mysql-dsn.*` if needed.

### B2 — User says「无库」（或「暂无后端 / 暂无数据库」）

**合法跳过，不算初始化失败。** Do not keep asking for passwords.

1. Fill `docs/数据库连接与复盘.md`:
   - 状态：`跳过（纯前端 / 暂无库）`
   - 原因：用户确认无 MySQL（可摘用户原话）
   - 录入日期；`.env` 写入：`跳过`；`SELECT 1`：`N/A`
2. In `AGENTS.md` + `docs/项目结构与架构.md` + SSOT: state **当前仅前端，后端与库待建**.
3. Do **not** create `.env` with fake credentials. Do **not** run `db`/`mysql` until a real connection exists.
4. `api-check` / backend `smoke`: mark N/A or skip; frontend lint/smoke may still run if adapted.
5. Later when backend appears: re-run Step B1 (see 使用指南「先前端、后加后端」).

### Write policy（全权限账号 + 可复盘；仅在有库时）

| 动作 | 工具 | 复盘 |
|------|------|------|
| 只读探查 | `db.ps1` / `db.sh`（单语句、禁 `;`） | 可选记一行 |
| INSERT/UPDATE/DELETE/DDL | 须用户明确同意后用 `mysql.ps1`（或用户批准的等价方式） | **必须**追加到 `docs/数据库连接与复盘.md` 第三节 |

## Step C — Deep learn

Fill:

1. `docs/项目结构与架构.md`（含「仅前端 / 无后端」若适用）
2. `AGENTS.md`（含双 git 或单前端、核心约束、DB 摘要指向复盘文档——含「跳过」状态）
3. `docs/项目进度与完成度.md`
4. Adapter `project-progress` **快照必填**：把 `YYYY-MM-DD` / `<一句话>` / `<需求文档路径>` 换成项目事实。留下占位符 = 未完成 init（模型谈进度读到空壳）。写清「**改代码必须写 SSOT**」。
5. `# ADAPT` `scripts/kit-layout`（多 git 扫描 + 代码扩展名：PHP+Vue 至少 php/vue/js/ts/sql）+ lint/smoke/api-check/verify（无后端时路径可标 TODO/N/A；lint 的 checker 扩展名可以比 kit-layout 窄——`.vue` 算代码会 nudge，但默认 `php -l` 会 skip 而不是误解析）

Checklist:

```
Learn progress:
- [ ] Asked user for MySQL (or user said 无库 → 复盘 marked 跳过)
- [ ] SELECT 1 ok / FAIL recorded / N/A (无库)
- [ ] Git layout from scan advice (record, or the one question answered; local git init only where chosen)
- [ ] Remote URL asked for each repo_remotes=none (or user said 无远程). git-remote-add ls-remote ok / skipped
- [ ] project-progress snapshot filled (no YYYY-MM-DD leftover)
- [ ] kit-layout ADAPT'd (child .git + code exts) OR confirmed single-repo PHP default is correct
- [ ] Backend / frontend stack + CRUD conventions (or 后端待建)
- [ ] 二开约束 + UTF-8 / no BOM / no emoji in comments / 直写少包一层
- [ ] api-check once if feasible (else N/A)
```

Daily after init: read `docs/项目进度与完成度.md` section 二 and the last 10 rows of section 六, then only the code they point at. Do not read every doc. Do not delete older section 六 rows. If the request already says what and where, do it. Several independent pieces: each must reach `Done: yes` before the next starts. Update `docs/项目结构与架构.md` in the same turn only when observable behavior changes (API, table meaning, route, permission, git layout); read that section in full first. Refactors and docs-only edits do not rewrite it. For a bug, read the error and reproduce once before editing. The first `[FAIL]` is the only next edit. Claim done only by quoting `== Done: yes ==` from a `verify` run in this same turn. On `WARN` with no `FAIL`, append one section 六 row that lists each changed code path, then re-run. The next session opens those paths. Name any changed file the task did not ask for. Do not paste whole `docs/_scan-raw.md`.

## Step D — Tool-layer self-check（装完必查，别信「已安装」）

安装脚本只保证文件到位，不保证脚本**能跑对**。逐项实测，别只看 exit code：

1. **BOM**：`scan-project.ps1` 等写文件的脚本，确认输出首字节不是 `EF BB BF`。
   PowerShell 5.1 的 `Set-Content -Encoding utf8` **会写 BOM**；用
   `[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))`。
2. **相对路径归一化**：`.sh` 里若先 `cd` 到子目录再调外部工具，必须先把用户给的相对路径
   按**工作区根**解析成绝对路径再剥离子目录前缀；否则子目录内查不到文件，报成假 FAIL。
   `.ps1` 与 `.sh` 两个版本要行为一致。
3. **curl 状态码**：`curl -w "%{http_code}" ... || echo "000"` 在 curl 非零退出但仍打印状态码时
   会拼成 `200000`。改为「输出为空才回退 000」。
4. **环境变量可能为空**：`Join-Path $env:ProgramFiles ...` 在 `$env:ProgramFiles` 为空时抛参数绑定
   错误并**中止整个候选块**（后续候选也不会试）。所有 Join-Path 的 base 都要先判空。
5. **本机 Node 版本**：默认 PATH 上的 Node 可能 `<18`。候选顺序建议
   PATH → `D:\tools\node` → Volta → `~/.workbuddy-ai/binaries/node/versions/*`（取最高版本）。
6. **产物核实**：有生成器（如 `tools/*.mjs`）的项目，别只信脚本写好了 —— **确认产物真的落盘**，
   并逐个校验站内链接可达（`scan-project` 不查断链）。
7. **别急着记缺口**：产物可能在你看之前几分钟才生成。下结论前重新 `ls`/`stat` 一次。
8. **Windows PATHEXT 可能被截断**：环境块过大时 `$env:PATHEXT` 可能丢掉 `.EXE` / `.CMD`。
   `Get-Command node`/`npm` 会命中同名 `.js` 或直接找不到，报成「缺 Node」。
   先看 PATHEXT 是否还含 `.EXE` 与 `.CMD`；解析 checker 用 **`.exe`/`.cmd` 全路径**（或 `LZ_PHP` / 同等变量），不要靠无扩展名命令。
9. **长管道会被进程创建开销掐断**：会包装/审计每条外部命令的环境里，
   `git | sed | sort | uniq | head` 这种串可能卡住、空输出或中途退出——不一定是 git 失败。
   实测 `scan-project` 时确认 **Git hot files 段真有行**（或明确的 skipped 原因）；ADAPT 时少 fork，中间结果写临时文件。

## Done when

- [ ] User was asked for MySQL; either `.env` written + 复盘 filled, **or** 复盘 marked 跳过（无库）
- [ ] `docs/项目结构与架构.md` + `AGENTS.md` + SSOT seeded
- [ ] Adapter `project-progress` 快照已填（无 `YYYY-MM-DD` / `<一句话>` 占位）；写清「改代码必须写 SSOT」
- [ ] `kit-layout` 已按多仓/栈 ADAPT（或确认单仓 PHP 默认即可）。多仓项目不 ADAPT reminder = 假自动维护
- [ ] If has DB: `db`/`mysql` `.env` path correct; if 无库: docs state 待建
- [ ] New chat can work without re-asking architecture (may still need DB if `.env` missing and project now has a backend)
- [ ] **Step D 实测通过**（工具层真的能跑，不只是「文件已拷贝」）——BOM / 相对路径 / curl 状态码 / 空环境变量 Join-Path / PATHEXT / 热文件段有输出，逐项验过；**未过 Step D 不算装完**
