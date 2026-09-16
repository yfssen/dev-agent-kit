---
description: 项目智能体工具层：查状态、自检、验证、对账
alwaysApply: true
enabled: true
---

# 工具层（WorkBuddy / CodeBuddy）

本项目已具备可用工具，遇到相应任务**直接用**，不要说"无法访问"。
权威细节见根目录 `AGENTS.md` / `CODEBUDDY.md`。脚本：Windows `*.ps1` / Unix `*.sh`。

## 入口

- 扫描：`./scripts/scan-project.ps1` 或 `./scripts/scan-project.sh`
- 写 `.env`：`./scripts/apply-mysql-dsn.ps1 -Command '...'` 或 `./scripts/apply-mysql-dsn.sh --command '...'`（初始化写入连接串；无库跳过）
- MySQL：`./scripts/mysql.ps1` 或 `./scripts/mysql.sh`（密码经环境变量，不进命令行）
- 查状态：`./scripts/db.ps1` 或 `./scripts/db.sh`（只读白名单；写操作拦截；缺客户端 exit 2）
- 自检：`./scripts/lint.ps1` 或 `./scripts/lint.sh`（缺依赖 exit 2，非假阳性语法错）
- 冒烟：`./scripts/smoke.ps1` 或 `./scripts/smoke.sh`
- 对账：`./scripts/api-check.ps1` 或 `./scripts/api-check.sh`

ADAPT 陷阱：相对路径先按工作区根解析再 `cd` 子目录；`curl … || echo 000` 会拼成 `200000`；`Join-Path` 的 env base 可能为空须先判空；写文件勿用 PS5.1 的 `Set-Content -Encoding utf8`（会带 BOM）。

## 闭环

```
定位（SSOT / rg / scan hot files）→ 只读命中文件 → api-check 摘要 → db → 写码 → lint → smoke → 更新 SSOT 触及的行
```

不要把 `docs/_scan-raw.md` 整份贴进对话。`api-check` 默认摘要，全量加 `-All` / `ALL=1`。
