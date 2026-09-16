---
description: Project tooling entry for query/lint/smoke/reconcile
alwaysApply: true
trigger: always_on
---

# 工具层（Qoder）

本项目已具备可用工具，遇到相应任务**直接用**，不要说"无法访问"。
权威细节见根目录 `AGENTS.md`。脚本：Windows `*.ps1` / Unix `*.sh`。

> 与 `AGENTS.md` 冲突时，以本 rules 为准；业务事实仍以 `AGENTS.md` / SSOT 为源。

## 入口

- 查状态：`./scripts/db.ps1` 或 `./scripts/db.sh`（只读白名单；写操作拦截；缺客户端 exit 2）
- 自检：`./scripts/lint.ps1` 或 `./scripts/lint.sh`（缺依赖 exit 2，非假阳性语法错）
- 冒烟：`./scripts/smoke.ps1` 或 `./scripts/smoke.sh`
- 对账：`./scripts/api-check.ps1` 或 `./scripts/api-check.sh`

## 闭环

```
api-check → db → 写码 → lint → smoke → 更新 SSOT
```
