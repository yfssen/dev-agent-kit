# Codex 适配说明

Codex 原生读取项目根目录 **`AGENTS.md`**，因此：

1. **必装核心即可**：拷贝 `templates/AGENTS.md` → 项目 `AGENTS.md`，填好占位符。
2. **无需额外入口文件**（本目录故意不放第二份记忆，避免双源漂移）。
3. 可选：若团队还用 Cursor/Claude/Kiro，再叠加对应 adapter；内容仍以 `AGENTS.md` + SSOT 为准。

## 建议在 AGENTS.md「工具入口」表中同时列出 `.ps1` / `.sh`

见 `templates/AGENTS.md` 已留双列写法（或按 OS 删一列）。

## 闭环（与其它 adapter 相同）

```
api-check → db → 写码 → lint → smoke → 更新 SSOT
```
