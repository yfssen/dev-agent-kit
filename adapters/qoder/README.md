# Qoder 适配说明

Qoder **原生读 `AGENTS.md`**，并支持 `.qoder/rules/*.md`（与 AGENTS 冲突时 rules 优先）。

安装本 adapter 时：

1. 核心已提供 `AGENTS.md`
2. 再拷 `adapters/qoder/rules/*` → `.qoder/rules/`（工具层 + 进度纪律，`alwaysApply`）

无需第二份业务记忆；进度只认 SSOT。
