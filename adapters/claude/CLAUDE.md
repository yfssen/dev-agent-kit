# Claude Code 入口（薄适配）

> 本文件让 Claude Code 自动加载本项目的开发智能体约定。
> **权威内容在 `AGENTS.md` 与 `docs/项目进度与完成度.md`**，此处不重复业务细节。

## 必读

1. `AGENTS.md` — 项目简介、核心约束、工具入口
2. `docs/项目进度与完成度.md` — 进度 SSOT（谈进度/改完模块必更新）

## 代码生成铁律

- 源文件编码 **UTF-8**
- **无 BOM**（UTF-8 without BOM）
- 注释/文档字符串 **禁止表情符号/emoji**

## 工具（直接执行，勿声称无法访问）

| 用途 | Windows | Unix |
|------|---------|------|
| 结构扫描 | `./scripts/scan-project.ps1` | `./scripts/scan-project.sh` |
| MySQL 交互 | `./scripts/mysql.ps1` | `./scripts/mysql.sh` |
| 查状态 | `./scripts/db.ps1 "<只读SQL>"` | `./scripts/db.sh "<只读SQL>"` |
| 自检 | `./scripts/lint.ps1 <路径>` | `./scripts/lint.sh <路径>` |
| 冒烟 | `./scripts/smoke.ps1` | `./scripts/smoke.sh` |
| 对账 | `./scripts/api-check.ps1` | `./scripts/api-check.sh` |

缺依赖 → `exit 2`；业务/语法错 → `exit 1`。写库语句会被 `db` 脚本拦截。

## 闭环

```
api-check → db → 写码 → lint → smoke → 更新 SSOT
```
