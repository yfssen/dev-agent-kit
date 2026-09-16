# Fake Project AI Guide

> Dry-run fixture for dev-agent-kit. Not a real product.

## Project

Minimal PHP-shaped layout used only to exercise kit scripts.

| Dir | Role |
|-----|------|
| `backend/` | Fake API controllers |
| `frontend/` | Fake URL call sites |
| `docs/` | SSOT |
| `scripts/` | Kit tools |

## Constraints

1. No real business logic
2. Scripts must stay read-only for db writes
3. Missing checker must exit 2

## Tool entry

| Use | Windows | Unix |
|-----|---------|------|
| query | `./scripts/db.ps1 "<SQL>"` | `./scripts/db.sh "<SQL>"` |
| lint | `./scripts/lint.ps1 <path>` | `./scripts/lint.sh <path>` |
| smoke | `./scripts/smoke.ps1` | `./scripts/smoke.sh` |
| reconcile | `./scripts/api-check.ps1` | `./scripts/api-check.sh` |
