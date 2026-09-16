# Project init / learn workflow（二开标准初始化）

> 安装开发智能体后**默认一口气跑完**本流程。  
> **硬规则：必须向用户索要 MySQL 连接命令（或 DSN）**，写入 `.env`，并落 `docs/数据库连接与复盘.md` 供复盘。  
> 开发账号通常具备增删改查全权限；日常探查仍用只读 `db.*`，写库必须记复盘日志。

Run after merge-safe install + MERGE 处理完毕。

## When

- User asks to scaffold / install 开发智能体 on a **real** (often 二开) project
- User asks for 项目初始化 / 整体分析 / 标准开工

Skip only if user says「只装文件、先别分析」.  
**即使跳过深度分析，只要要用库，仍须索要连接信息。**

## Layout: dual-git under one folder

```
<workspace>/          # kit files live here
  <backend>/          # own .git ; .env often here
  <frontend>/         # own .git
```

1. Kit at workspace root (parent of FE+BE) unless user says otherwise.
2. Record each side path + own `.git` yes/no.
3. Commit in the repo you changed.
4. Point `db`/`mysql`/`apply-mysql-dsn` `# ADAPT` `.env` to backend `.env` when dual-git.

## Step A — Structural scan

```powershell
./scripts/scan-project.ps1 -OutFile docs/_scan-raw.md
```

```bash
./scripts/scan-project.sh docs/_scan-raw.md
```

## Step B — Ask for MySQL connection（必做，向用户索要）

**Do not guess password. Do not skip this step.**

Ask the user (copy this prompt if needed):

```text
请提供开发库 MySQL 连接（任选一种）：
1) 完整命令，例如：
   mysql -h127.0.0.1 -P3306 -uroot -p你的密码 -D库名
2) DSN：
   mysql://用户:密码@主机:端口/库名
并说明：.env 应写在哪个路径（单仓根目录 / 双 git 的 backend/.env）？
账号一般具备增删改查权限即可。
```

Then:

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

### Write policy（全权限账号 + 可复盘）

| 动作 | 工具 | 复盘 |
|------|------|------|
| 只读探查 | `db.ps1` / `db.sh`（单语句、禁 `;`） | 可选记一行 |
| INSERT/UPDATE/DELETE/DDL | 须用户明确同意后用 `mysql.ps1`（或用户批准的等价方式） | **必须**追加到 `docs/数据库连接与复盘.md` 第三节 |

## Step C — Deep learn

Fill:

1. `docs/项目结构与架构.md`
2. `AGENTS.md`（含双 git、核心约束、DB 摘要指向复盘文档）
3. `docs/项目进度与完成度.md`
4. Adapter progress stubs
5. `# ADAPT` lint/smoke/api-check

Checklist:

```
Learn progress:
- [ ] Asked user for MySQL connection + wrote .env + 复盘 doc
- [ ] SELECT 1 ok (or recorded FAIL reason)
- [ ] Repo layout (single / dual-git)
- [ ] Backend / frontend stack + CRUD conventions
- [ ] 二开约束 + UTF-8 / no BOM / no emoji in comments
- [ ] api-check once if feasible
```

## Done when

- [ ] User was asked for MySQL link; `.env` written; `docs/数据库连接与复盘.md` filled (no password)
- [ ] `docs/项目结构与架构.md` + `AGENTS.md` + SSOT seeded
- [ ] `db`/`mysql` `.env` path correct
- [ ] New chat can work without re-asking architecture (may still need DB if `.env` missing)
