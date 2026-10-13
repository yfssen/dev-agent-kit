# Hooks：把「闭环纪律」变成系统强制

> 一句话：手册里写「AI 要自检、别乱 push、别直接写库」是**靠自觉**；钩子是**系统在事件发生时自动执行**，不靠 AI 记得。
> 这就是把规矩从「嘴上说」升级成「确定性拦截」。

本目录是 **Cursor** 的钩子模板（第一批）。Claude / Codex 的钩子是下一批。

---

## 装了什么（3 个钩子）

| 钩子 | 触发时机 | 作用 | 能否拦截 |
|------|----------|------|----------|
| `guard-shell` | 执行 shell 命令**前** | `git push` / `rm -rf` / `git reset --hard` / 直连 mysql 写 / 覆盖 `.env` 时**弹出确认** | 可（`ask`，你点确认才跑） |
| `auto-lint` | AI 改完文件**后** | 自动对改动的文件跑 `scripts/lint`；**失败才**把结果回灌给 AI 让它修 | 否（只回灌上下文） |
| `backup-ssot` | 上下文压缩**前** | 自动快照 `docs/*.md`（SSOT）到 `docs/.ssot-backups/`，防进度丢失 | 否（纯备份） |
| `ssot-reminder` | （已停用，不再挂 `stop`） | 旧版会把整份未提交清单用 `followup_message` **自动发进对话**。脏工作区（IDE 元数据、升级 SQL、上百个文件）会变成一条很长的用户消息，并再开一轮 Agent。进度是否回写只看 `scripts/verify` 的 SSOT WARN | 否 |

设计原则：
- **ask 不 deny**：危险命令只是弹确认，主动权仍在你手里，不会把人卡死。
- **fail-open**：钩子脚本自己出错时默认放行，不会因为钩子挂了导致整个 shell 用不了。
- **响亮地失败对齐**：`lint` 退出码 `2`（检查器缺失，如没装 php）会被**跳过**，不冒充成代码错误；只有退出码 `1`（真语法错）才回灌。
- **不要用 `stop` + `followup_message` 催 SSOT**。Cursor 会把它当成用户发出的下一条消息：出现在输入框里，并再跑一轮 Agent。多仓脏树会列出 `.phpstorm.meta.php`、`public/upgrade/sql/*.sql` 和「+210 more」，体验很差。脚本仍留在 `hooks/` 里，但是空操作（读完 stdin 就退出），防止旧 `hooks.json` 还在调用时继续发消息。新模板的 `hooks.json` 已去掉 `stop`。
- **完成闸是 `verify`，不是钩子**：钩子是过程中的护栏；声称任务做完前必须跑 `scripts/verify`（lint + api-check + SSOT + 可选 smoke），`Done: yes` 才算过。SSOT 过期是 `WARN`，退出码仍为 0，但 `Done: no`，不进聊天。

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

默认按 **PHP + Vue** 的代码扩展名配好了（`.php/.vue/.js/.ts/.sql`），但 **lint 检查器默认仍是 `php -l`**（非 php 文件 skip，exit 0）。换栈改：

- `scripts/kit-layout.ps1`：`$KitCodeExts`（什么算「改了代码」；verify / ssot-reminder 共用）；可选 `$KitRepoNames` 限制子仓名单
- `scripts/kit-layout.sh`：`KIT_CODE_EXT` / `KIT_REPO_NAMES`
- `hooks/auto-lint.ps1`：`$exts`（哪些写入会触发 lint；非 php 仍会调用 lint，由 lint skip）
- `hooks/auto-lint.sh`：`case "$path"` 那一行
- `scripts/lint.ps1` / `lint.sh`：`$checkExts` / `*.php`（检查器真正能解析的扩展名）

**多仓项目不 ADAPT `kit-layout` = 假自动维护。** 根上常无 `.git` 时，只对工作区根跑 `git status` 会漏掉子仓。SSOT 在工作区根 `docs/`，不要假定它在某个子仓的 git 里。是否回写由 `verify` 判断，不要再挂会自动发消息的 `stop` 钩子。

`auto-lint` 调用的是项目里的 `scripts/lint.ps1` / `scripts/lint.sh`。

`guard-shell` 的拦截规则（SQL 写、push、删除等）在脚本里是明文正则，想加/减自己改。

---

## 怎么验证它真的在工作

1. **guard-shell**：让 AI 跑一条 `git push`（或你自己在 Cursor 终端触发），应弹出确认。
2. **auto-lint**：故意让 AI 写一个有语法错的 `.php`，AI 应在下一步收到「Auto-lint FAILED」并去修；同时 `scripts/.lint-last.log` 有记录。
3. **backup-ssot**：长对话触发压缩后，`docs/.ssot-backups/` 里出现带时间戳的快照。
4. **ssot-reminder**：对话结束时**不应**再出现「SSOT auto-maintain / SSOT check...」这种自动发出的长消息。进度用 `./scripts/verify.ps1` 看 `[WARN] ssot`。若项目里的 `.cursor/hooks.json` 仍有 `stop` → `ssot-reminder`，升级时删掉该段，或换成现在这个空脚本。

如果 `auto-lint` 没触发：先把 `hooks.json` 里 `postToolUse` 的 `"matcher": "Write"` 去掉，确认基础钩子能跑，再按 Cursor 的 **Hooks** 输出面板排查工具名。

---

## 注意

- 钩子脚本一律 **ASCII、无 BOM、无表情**（和 kit 其它脚本同规矩）；中文只写在本 `.md`。
- `scripts/.lint-last.log`、`docs/.ssot-backups/`、`.cursor/hooks/.ssot-nudge-last` 建议进 `.gitignore`。
- 钩子是**项目级**、随仓库走，可被 review；不要把密钥写进钩子脚本。
