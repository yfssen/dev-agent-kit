# WorkBuddy / CodeBuddy 入口（薄适配）

> 本文件优先于 `AGENTS.md` 被 WorkBuddy（CodeBuddy）加载。
> **权威内容仍在 `AGENTS.md` 与 `docs/项目进度与完成度.md`**，此处不重复业务细节。

## 必读

1. `AGENTS.md` — 项目简介、核心约束、工具入口
2. `docs/项目进度与完成度.md` — 进度 SSOT（谈进度/改完模块必更新）
3. `.codebuddy/rules/` — 工具层与进度行为（若已安装）

## 工具（直接执行，勿声称无法访问）

| 用途 | Windows | Unix |
|------|---------|------|
| 查状态 | `./scripts/db.ps1 "<只读SQL>"` | `./scripts/db.sh "<只读SQL>"` |
| 自检 | `./scripts/lint.ps1 <路径>` | `./scripts/lint.sh <路径>` |
| 冒烟 | `./scripts/smoke.ps1` | `./scripts/smoke.sh` |
| 对账 | `./scripts/api-check.ps1` | `./scripts/api-check.sh` |

缺依赖 → `exit 2`；业务/语法错 → `exit 1`。写库语句会被 `db` 脚本拦截。

## 闭环

```
api-check → db → 写码 → lint → smoke → 更新 SSOT
```
