# Adapters（各家薄入口）

> 核心（`templates/`：记忆 + 脚本 + SSOT）与工具无关。
> Adapter 只解决一件事：**让某家 AI 自动加载这套核心**。

## 合同（任何 adapter 必须满足）

1. **指向核心**：明确要求读 `AGENTS.md`、跑 `scripts/`、维护 SSOT。
2. **薄**：不复制业务知识；项目事实只写在 `AGENTS.md` / SSOT（且须可被代码验证）。
3. **可叠加**：同一项目可同时装 Cursor + Claude + WorkBuddy + Qoder 等。
4. **不绑栈**：不出现具体业务路径。

## 目录

| Adapter | 安装到项目 | 机制 |
|---------|------------|------|
| `cursor/` | `.cursor/rules/*.mdc` | `alwaysApply: true` |
| `claude/` | 根目录 `CLAUDE.md` | Claude Code 自动读 |
| `codex/` | （通常无需额外文件） | Codex 原生读 `AGENTS.md` |
| `kiro/` | `.kiro/steering/*.md` | Kiro steering |
| `workbuddy/` | `CODEBUDDY.md` + `.codebuddy/rules/` + 项目级 `.codebuddy/skills/scaffold-dev-agent/` | WorkBuddy/CodeBuddy（别名 `codebuddy`） |
| `qoder/` | `.qoder/rules/*.md` | Qoder（另原生读 `AGENTS.md`） |
| `_common/` | 不直接拷贝 | 共享母本（含 `CODING.md`：无 BOM、注释无表情） |

## 安装（推荐用 Skill 安装器，merge-safe）

```powershell
$kit = "<套件路径>\dev-agent-kit"
& "$kit\skills\scaffold-dev-agent\scripts\install.ps1" `
  -KitRoot $kit -ProjectRoot . `
  -Adapters "cursor,claude,workbuddy,qoder,kiro"
```

手动拷贝示例：

```powershell
# WorkBuddy
Copy-Item "$kit\adapters\workbuddy\CODEBUDDY.md" .\CODEBUDDY.md
New-Item -ItemType Directory -Force .codebuddy\rules | Out-Null
Copy-Item "$kit\adapters\workbuddy\rules\*" .\.codebuddy\rules\

# Qoder
New-Item -ItemType Directory -Force .qoder\rules | Out-Null
Copy-Item "$kit\adapters\qoder\rules\*" .\.qoder\rules\
```

装完后仍须按 `操作文档.md` 填占位符、改 `# ADAPT`。

**在研项目**：安装器默认 **merge-safe**（不覆盖）。已存在 → `*.kit-new`，先读再合并，合并后删除。仅用户明确要求时才 `-Force`。
