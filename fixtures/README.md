# Fake Project (kit dry-run target)

> 与任何真实业务无关。用于验收「母本 → 安装 → 脚本」。
> **不要**在本目录维护 `scripts/` 副本（易过期/不安全）；`dry-run.ps1` 每次从 `templates/scripts/` 拷到 TEMP 工作区。
> 同理，本目录里的 adapter 文件（`.cursor/rules/`、`.kiro/steering/`、`CLAUDE.md` 等）**以 `dry-run` 从 `adapters/` 覆盖后为准**——此处同名副本不维护，也**不要手改来「跟一版」**（半新半旧比过期更误导）。要改工具层，只改 `adapters/`。
> 连接样例只提交 `.env.example`；`dry-run` 在 TEMP 里自动复制为 `.env`。

Run from kit root:

```powershell
./fixtures/dry-run.ps1
# optional CI: ./fixtures/dry-run.ps1 -RequireBash
```
