# Hooks：把「闭环纪律」变成系统强制

> 一句话：手册里写「AI 要自检、别乱 push、别直接写库」是**靠自觉**；钩子是**系统在事件发生时自动执行**，不靠 AI 记得。
> 这就是把规矩从「嘴上说」升级成「确定性拦截」。

本目录是 **Cursor** 的钩子模板（第一批）。Claude / Codex 的钩子是下一批。

---

## 装了什么（4 个钩子）

| 钩子 | 触发时机 | 作用 | 能否拦截 |
|------|----------|------|----------|
| `guard-shell` | 执行 shell 命令**前** | `git push` / `rm -rf` / `git reset --hard` / 直连 mysql 写 / 覆盖 `.env` 时**弹出确认** | 可（`ask`，你点确认才跑） |
| `auto-lint` | AI 改完文件**后** | 自动对改动的文件跑 `scripts/lint`；**失败才**把结果回灌给 AI 让它修 | 否（只回灌上下文） |
| `backup-ssot` | 上下文压缩**前** | 自动快照 `docs/*.md`（SSOT）到 `docs/.ssot-backups/`，防进度丢失 | 否（纯备份） |
| `ssot-reminder` | 一轮回答**结束时** | 若本轮改了代码但 `docs/*.md`（SSOT）没更新，**提醒 AI 回写**，让「跨会话记忆」和代码别脱节 | 否（soft 提醒；带 20 分钟冷却，不唠叨） |

设计原则：
- **ask 不 deny**：危险命令只是弹确认，主动权仍在你手里，不会把人卡死。
- **fail-open**：钩子脚本自己出错时默认放行，不会因为钩子挂了导致整个 shell 用不了。
- **响亮地失败对齐**：`lint` 退出码 `2`（检查器缺失，如没装 php）会被**跳过**，不冒充成代码错误；只有退出码 `1`（真语法错）才回灌。
- **提醒不强制**：`ssot-reminder` 只在「改了代码、没改 SSOT」时软提醒一次，20 分钟内不再重复（靠 `.cursor/hooks/.ssot-nudge-last` 冷却），`hooks.json` 里又加了 `loop_limit: 1` 兜底，不会卡住迭代。它只看**工作区未提交改动**，不依赖任何向量库——这就是 kit 的「跨会话记忆」：记忆存在 git 里的 markdown，这个钩子只负责催你保持它新鲜。
- **完成闸是 `verify`，不是钩子**：钩子是过程中的护栏；声称任务做完前必须跑 `scripts/verify`（lint + api-check + SSOT + 可选 smoke），`Result: PASS` 才算过。

---

## 安装

跟着 kit 的安装器走，加一个 `hooks` adapter（可选，默认不装）：

```powershell
$kit = "E:\www\1-mypro\dev-agent-kit"
& "$kit\skills\scaffold-dev-agent\scripts\install.ps1" `
  -KitRoot $kit -ProjectRoot . -Adapters "cursor,hooks"
```

```bash
"$kit/skills/scaffold-dev-agent/scripts/install.sh" "$kit" . cursor,hooks
```

装完项目里会有：

```
.cursor/
  hooks.json              # Windows 用（调用 .ps1）
  hooks.posix.json        # mac/linux 用（调用 .sh）
  hooks/
    guard-shell.ps1    guard-shell.sh
    auto-lint.ps1      auto-lint.sh
    backup-ssot.ps1    backup-ssot.sh
    ssot-reminder.ps1  ssot-reminder.sh
```

Cursor 会监听 `hooks.json`，保存即重载；不生效就重启 Cursor，并在设置里的 **Hooks** 标签确认已加载。

### Windows vs mac/linux

- **Windows**：直接用 `hooks.json`（走 PowerShell，`.ps1` 用原生 JSON 解析，不依赖 `jq`）。
- **mac/linux**：把 `hooks.posix.json` 重命名为 `hooks.json`（走 bash，`.sh` 优先用 `jq`，没有则降级扫描）。

---

## 按你的技术栈适配（`# ADAPT`）

默认按 **PHP** 配好了。换栈改这几处扩展名：

- `hooks/auto-lint.ps1`：`$exts = @('.php')`
- `hooks/auto-lint.sh`：`case "$path" in *.php) ... ` 这一行
- `hooks/ssot-reminder.ps1`：`$exts = @('.php')`（判定「改的是代码」用）
- `hooks/ssot-reminder.sh`：`*.php)` 那一行

`ssot-reminder` 的冷却时间默认 1200 秒（20 分钟），在脚本顶部 `$cooldownSec` / `cooldown_sec` 调。

`auto-lint` 调用的是项目里的 `scripts/lint.ps1` / `scripts/lint.sh`——那个脚本本身也要按栈适配（见 `templates/scripts/lint.*` 的 `# ADAPT`）。

`guard-shell` 的拦截规则（SQL 写、push、删除等）在脚本里是明文正则，想加/减自己改。

---

## 怎么验证它真的在工作

1. **guard-shell**：让 AI 跑一条 `git push`（或你自己在 Cursor 终端触发），应弹出确认。
2. **auto-lint**：故意让 AI 写一个有语法错的 `.php`，AI 应在下一步收到「Auto-lint FAILED」并去修；同时 `scripts/.lint-last.log` 有记录。
3. **backup-ssot**：长对话触发压缩后，`docs/.ssot-backups/` 里出现带时间戳的快照。
4. **ssot-reminder**：让 AI 改一个 `.php` 但别碰 `docs/*.md`，这轮结束时它应收到「SSOT check...」提醒去回写；20 分钟内再改代码不会重复提醒。

如果 `auto-lint` 没触发：先把 `hooks.json` 里 `postToolUse` 的 `"matcher": "Write"` 去掉，确认基础钩子能跑，再按 Cursor 的 **Hooks** 输出面板排查工具名。

---

## 注意

- 钩子脚本一律 **ASCII、无 BOM、无表情**（和 kit 其它脚本同规矩）；中文只写在本 `.md`。
- `scripts/.lint-last.log`、`docs/.ssot-backups/`、`.cursor/hooks/.ssot-nudge-last` 建议进 `.gitignore`。
- 钩子是**项目级**、随仓库走，可被 review；不要把密钥写进钩子脚本。
