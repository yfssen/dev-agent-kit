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

## Step A — Structural scan

```powershell
./scripts/scan-project.ps1 -OutFile docs/_scan-raw.md
```

```bash
./scripts/scan-project.sh docs/_scan-raw.md
```

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
4. Adapter progress stubs
5. `# ADAPT` lint/smoke/api-check（无后端时路径可标 TODO/N/A）

Checklist:

```
Learn progress:
- [ ] Asked user for MySQL (or user said 无库 → 复盘 marked 跳过)
- [ ] SELECT 1 ok / FAIL recorded / N/A (无库)
- [ ] Repo layout (single / dual-git / frontend-only)
- [ ] Backend / frontend stack + CRUD conventions (or 后端待建)
- [ ] 二开约束 + UTF-8 / no BOM / no emoji in comments
- [ ] api-check once if feasible (else N/A)
```

Daily after init: locate via SSOT / `rg` / scan Git hot files; read only the hits; prove with `lint` + `smoke` + `api-check` summary (`-All` / `ALL=1` for full). Do not paste whole `docs/_scan-raw.md`.

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

## Done when

- [ ] User was asked for MySQL; either `.env` written + 复盘 filled, **or** 复盘 marked 跳过（无库）
- [ ] `docs/项目结构与架构.md` + `AGENTS.md` + SSOT seeded
- [ ] If has DB: `db`/`mysql` `.env` path correct; if 无库: docs state 待建
- [ ] New chat can work without re-asking architecture (may still need DB if `.env` missing and project now has a backend)
- [ ] **Step D 实测通过**（工具层真的能跑，不只是「文件已拷贝」）——BOM / 相对路径 / curl 状态码 / 空环境变量 Join-Path 逐项验过；**未过 Step D 不算装完**
