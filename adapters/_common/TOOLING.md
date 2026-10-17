# 工具层（AI 自主干活的固定入口）

本项目已具备可用工具，遇到相应任务**直接用**，不要说"无法访问"。

脚本：Windows 用 `*.ps1`，Linux/macOS 用 `*.sh`（逻辑相同）。

## 0. 初始化扫描 / 连接写入 / MySQL

```
./scripts/scan-project.ps1 [-OutFile docs/_scan-raw.md]
./scripts/apply-mysql-dsn.ps1 -Command 'mysql -h.. -u.. -p.. -D..'   # 解析连接命令/DSN -> 写入 .env
./scripts/mysql.ps1          # interactive; password from .env via MYSQL_PWD
./scripts/db.ps1 "<只读 SQL>"
```

双 git 时 `.env` 常在后端目录——改脚本里 `# ADAPT` 的 `.env` 路径。
`apply-mysql-dsn` 只在**初始化**时用（用户给出连接命令/DSN → 写入 `.env`，密码只留 `.env`）；无库则跳过。

## 1. 查真实状态（只读）

```
./scripts/db.ps1 "<只读 SQL>"        # ADAPT: 换成你项目的查库/查状态命令
./scripts/db.sh  "<只读 SQL>"
```

- 脚本自动读 `.env`，密码经环境变量传入，**不出现在命令行**
- **安全红线**：白名单——只允许**单条**只读语句（禁止 `;` 与 mysql `\g`/`\G`）；写操作/文件 I/O 被拦截
- 客户端路径：环境变量 `LZ_MYSQL` > PATH；找不到报 `exit 2`（依赖缺失，非查询错）

## 2. 自检（改完代码必跑）

```
./scripts/lint.ps1 <文件或目录>       # ADAPT: php -l / tsc --noEmit / ruff / mypy ...
./scripts/lint.sh  <文件或目录>
```

- **缺依赖时报 `exit 2`（依赖缺失），绝不误报成语法错**；真错才 `exit 1`
- 规则：**任何代码编辑后，收尾前必须自检通过**
- **ADAPT 陷阱**：若先 `cd` 到子目录再跑 eslint/tsc，相对路径必须先按**工作区根**解析再剥前缀（`.ps1`/`.sh` 一致）。`Join-Path` 的 base（如 `$env:ProgramFiles`）可能为空——先判空，否则终止性错误会带走整个候选块。
- **ADAPT 陷阱（`.ps1`）**：调用 checker 前设 `$global:LASTEXITCODE = $null`（不要赋 0，也不要写无作用域的 `$LASTEXITCODE = $null`，那会造出脚本局部变量把真退出码挡住）。PowerShell 退出码是进程级的，上一条留下的 `1` 在 checker 没启动时会被当成语法错。

## 3. 验证（接口/功能冒烟）

```
./scripts/smoke.ps1                    # 默认测本地
./scripts/smoke.sh
./scripts/smoke.ps1 -BaseUrl "<远程>"  # 测远程
./scripts/smoke.sh --base-url "<远程>"
```

- 用测试夹具自动取 token，无需手工种数据
- 判定：`PASS`=存活+正常；`WARN`=存活但业务报错；`FAIL`=网络错/404/非预期
- **本地环境要服务当前代码**，改完即可本地验证
- **ADAPT 陷阱**：`curl -w "%{http_code}" ... || echo 000` 会把 `200` 拼成 `200000`；只在输出为空时回退 `000`（见 `smoke.sh` 的 `http_code`）

## 4. 对账（谈进度/改错位前必跑）

```
./scripts/api-check.ps1
./scripts/api-check.sh
```

- 抽前端调用 ↔ 比对后端方法是否存在；输出带 `文件:行号`
- **这是错位表的对账源**：更新 SSOT 前先跑它拿真实清单
- 默认只打 **Summary + 前 20 条错位**（省 token）；全量用 `./scripts/api-check.ps1 -All` 或 `ALL=1 ./scripts/api-check.sh`

## 5. 验收闸（完成的定义；改完必跑）

```
./scripts/verify.ps1                 # 可选 -Target <文件>  -Full  -SsotStrict
./scripts/verify.sh                  # 可选 --target <文件> --full --ssot-strict
```

一条命令串起上面的 lint（**工作区内所有 git 仓**的改动代码）+ api-check + SSOT 是否回写 + 可选 smoke，打出 **PASS / FAIL / SKIP / WARN**，然后 `== Result: PASS|FAIL ==` 和 `== Done: yes|no ==`。
- **只有 FAIL 算没过闸**（exit 1）。缺 checker、没起服务、路径未配置 → SKIP，不挡未配好的项目。
- SSOT = **工作区根**顶级 `docs/*.md`（不是子仓里的 docs）。判定：根 git 里这些文件脏了，**或**最新 SSOT 的 mtime ≥ 最新改动代码 mtime − 2s。
- 代码改了但根 `docs/*.md` 没动 → 默认 WARN（`-SsotStrict` 才升为 FAIL）。
- smoke 探测的是**本项目 API**（GET `$BaseUrl` + 与 smoke 相同的第一个公开端点，响应里要有 `"code"`）。端口上是别的站点（phpstudy 默认页等）→ SKIP，不把完成闸卡死。要强制跑：`-Full` / `--full`。
- **声称任务做完之前必须引用本轮 `verify` 打出的 `Done: yes`**（`Result: PASS` 且 `WARN=0`）。只有 `FAIL` 让退出码为 1。有 `WARN` 时先补进度文档第六节一行，再跑同一条。第一条 `FAIL` 是下一次要改的地方。同一组检查连续失败三次时，按 `Next: STOP` 先复现，不要只改完再跑同一条。
- 新会话只读进度文档第二节和第六节最近 10 行，再打开这些落点。旧行留着。只有对外行为变了才改架构文档对应小节。修 bug 先复现一次。任务没要求却改过的文件要在回复里点名。

布局与扩展名在 `scripts/kit-layout.ps1` / `kit-layout.sh`（`$KitCodeExts` / `KIT_CODE_EXT` 默认 php/vue/js/ts/sql；可选 `$KitRepoNames` 限制子仓名单，空则自动发现一级子目录 `.git`）。

## 5b. 多 git / 根 docs（装完必认清）

同目录多仓（`admin/`、`pc_web/` … 各有 `.git`，工作区根常常**没有** `.git`）是一等公民，不是「单仓 PHP」特例。

- `verify` / `ssot-reminder` 扫：根若是 git 则计入，**再加上**每个一级子目录里的 `.git`。
- **多仓项目若不 ADAPT `kit-layout` / reminder，自动维护是假的**：旧逻辑只对工作区根跑 `git status`，根上无 `.git` 就直接 exit 0，永远不催补进度。
- 「改了代码」看 kit-layout 的扩展名，不是 lint 的 checker 扩展名。默认 `php -l` 对 `.vue` 会 skip（exit 0），但 `.vue` 仍算代码，会 nudge / 进 verify 的 SSOT 检查。

## 6. 标准工作闭环

```
定位现行逻辑（SSOT 落点 / rg / scan 的 Git hot files）
  → 只读命中文件（不要整仓、不要整份 _scan-raw）
  → 查状态(db) → 按规范写码
  → 收尾跑 verify（唯一完成闸）→ 按 WARN/FAIL 回写 SSOT 或修代码
```

**证明没猜错** = `verify` 的 Result 为 PASS，而不是模型「觉得对」。拆开查问题时仍用上面的 lint / smoke / api-check。
