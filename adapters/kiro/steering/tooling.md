# 工具层（Kiro steering）

本项目已具备可用工具，遇到相应任务**直接用**，不要说"无法访问"。
权威细节见根目录 `AGENTS.md`。脚本：Windows `*.ps1` / Unix `*.sh`。

## 入口

- 扫描：`./scripts/scan-project.ps1` 或 `./scripts/scan-project.sh`
- MySQL：`./scripts/mysql.ps1` 或 `./scripts/mysql.sh`
- 查状态：`./scripts/db.ps1` 或 `./scripts/db.sh`（只读白名单；写操作拦截；缺客户端 exit 2）
- 自检：`./scripts/lint.ps1` 或 `./scripts/lint.sh`（缺依赖 exit 2，非假阳性语法错）
- 冒烟：`./scripts/smoke.ps1` 或 `./scripts/smoke.sh`
- 对账：`./scripts/api-check.ps1` 或 `./scripts/api-check.sh`

## 闭环

```
api-check → db → 写码 → lint → smoke → 更新 SSOT
```
