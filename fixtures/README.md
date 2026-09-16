# Fake Project (kit dry-run target)

> 与任何真实业务无关。用于验收「母本 → 安装 → 脚本」。
>
> **本目录只留靶场骨架**（`AGENTS.md`、`docs/`、`.env.example`、`mock-router.php`、前后端样例、`.cursorignore`）。
> **不要**提交 `scripts/` 或 adapter 同名文件（`.cursor/rules/`、`.kiro/`、`.codebuddy/`、`.qoder/`、`CLAUDE.md`、`CODEBUDDY.md`）。
> `dry-run.ps1` 拷到 TEMP 后，从 `templates/scripts/` 和 `adapters/` 注入；仓库里的过期副本不是事实源，半同步比不维护更误导。
> 连接样例只提交 `.env.example`；`dry-run` 在 TEMP 里自动复制为 `.env`。

Run from kit root:

```powershell
./fixtures/dry-run.ps1
# optional CI: ./fixtures/dry-run.ps1 -RequireBash
```
