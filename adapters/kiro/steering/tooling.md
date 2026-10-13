# 工具层（Kiro steering）

本项目已具备可用工具，遇到相应任务**直接用**，不要说"无法访问"。
权威细节见根目录 `AGENTS.md`。脚本：Windows `*.ps1` / Unix `*.sh`。

## 入口

- 扫描：`./scripts/scan-project.ps1` 或 `./scripts/scan-project.sh`
- 写 `.env`：`./scripts/apply-mysql-dsn.ps1 -Command '...'` 或 `./scripts/apply-mysql-dsn.sh --command '...'`（初始化写入连接串；无库跳过）
- MySQL：`./scripts/mysql.ps1` 或 `./scripts/mysql.sh`
- 查状态：`./scripts/db.ps1` 或 `./scripts/db.sh`（只读白名单；写操作拦截；缺客户端 exit 2）
- 自检：`./scripts/lint.ps1` 或 `./scripts/lint.sh`（缺依赖 exit 2，非假阳性语法错）
- 冒烟：`./scripts/smoke.ps1` 或 `./scripts/smoke.sh`
- 对账：`./scripts/api-check.ps1` 或 `./scripts/api-check.sh`
- **验收闸**：`./scripts/verify.ps1` 或 `./scripts/verify.sh`（引用本轮 `Done: yes` 才算做完；WARN 也是 Done: no）。新会话只读进度第二节和第六节最近 10 行。只有对外行为变了才改架构文档。修 bug 先复现一次。多改的文件要在回复里点名。

## 闭环

```
定位（SSOT / rg / scan hot files）→ 只读命中文件 → db → 写码 → 收尾跑 verify（唯一完成闸）
```

不要把 `docs/_scan-raw.md` 整份贴进对话。`api-check` 默认摘要，全量加 `-All` / `ALL=1`。
SSOT = 工作区根 `docs/*.md`；多 git 扫一级子目录 `.git`（`scripts/kit-layout`）。**多仓不 ADAPT reminder = 假自动维护。改代码必须写 SSOT。**
