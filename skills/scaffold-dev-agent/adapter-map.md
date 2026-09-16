# Adapter map (per AI tool config)

Core is always the same. Adapters only place **thin loaders** where each product looks.

| Tool | Kit source | Install into project | Load mechanism |
|------|------------|----------------------|----------------|
| Cursor | `adapters/cursor/*.mdc` | `.cursor/rules/` | `alwaysApply: true` |
| Claude Code | `adapters/claude/CLAUDE.md` | `CLAUDE.md` (repo root) | auto-read |
| Codex | (none required) | `AGENTS.md` already core | native AGENTS.md |
| Kiro | `adapters/kiro/steering/*` | `.kiro/steering/` | steering files |
| WorkBuddy / CodeBuddy | `adapters/workbuddy/CODEBUDDY.md` + `rules/*` | `CODEBUDDY.md` + `.codebuddy/rules/` | CODEBUDDY.md priority; else AGENTS.md |
| Qoder | `adapters/qoder/rules/*` | `.qoder/rules/` | AGENTS.md + rules (`alwaysApply`) |
| Shared prose | `adapters/_common/*` | do not copy by default | edit adapters from this |

Install aliases: `workbuddy` and `codebuddy` are the same adapter.

## Multi-tool

Same project may install several adapters. All must point at:

- `AGENTS.md`
- `scripts/db|lint|smoke|api-check` (`.ps1` / `.sh`)
- `docs/项目进度与完成度.md` (SSOT)

## Adding a new tool

1. Create `adapters/<name>/` thin entry (point to core; no business).
2. Add one row to this table.
3. Extend `scripts/install.*` `-Adapters` list.
4. Keep Skill workflow unchanged.
