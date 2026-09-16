# 开发智能体启动套件（Dev-Agent Kit）

> 把任意一个项目，配成一个"懂它、能自主开发和测试"的开发智能体。
> 本套件从实践中抽象而来，**与技术栈无关、与 AI 产品无关**（Cursor / Claude Code / Codex / Kiro 等均可）。

> **脚本**：`templates/scripts/` 同时提供 **PowerShell（`.ps1`）** 与 **POSIX Bash（`.sh`）**，逻辑对齐。
> **脚本编码铁律**：所有 `.ps1` / `.sh` 一律纯 ASCII、不带 BOM；中文只写在 `.md` 里。`.md` 文件名可以含中文（脚本里用英文别名引用）。
> **许可**：MIT（见 `LICENSE`）。开源的是套件母本；业务代码与真实 `.env` 不要放进本仓库。

---

## 0. 这是什么 / 不是什么

- **是**：一套让任意 AI 编程工具在**某个具体项目**里能自主跑「定位现行逻辑 → 写码 → 自检/验证/对账证明没猜错 → 更新进度」闭环的**配置方法 + 模板 + 各家薄入口**。不把整仓塞进上下文。
- **不是**：一个要部署上线的产品；不是从零造 agent 框架。大脑（模型）由平台提供，你补的是**记忆 + 工具 + 闭环纪律**。

一句话定位：**给项目装一个"长期记忆 + 真实双手"，把"读过文档的 AI 助手"升级成"能独立干活的开发智能体"。**

本套件**不建代码库问答索引，也不自动记忆会话**。日常靠 SSOT 落点 + `rg` + `scan-project` 热文件摸到现行逻辑，只读命中文件；改完用 `lint` / `smoke` / `api-check`（默认摘要）证明没猜错。填 `AGENTS.md`、按技术栈适配 `scripts/`（约 30–60 分钟）——**分水岭不是「谁写的记忆」，而是「记忆能不能被代码复核」**；与实测冲突时以实测为准。

---

## 1. 智能体四件套（骨架，任何项目都一样）

| 组件 | 落地物 | 作用 |
|------|--------|------|
| 模型 | 平台提供（Cursor / Claude / Codex / Kiro …） | 无需自建 |
| 记忆 | `AGENTS.md` + **adapter 入口** + 一份 **SSOT 进度文档** | 规范/进度自动加载，不靠人肉复述 |
| 工具 | `scripts/`：**查状态 / 自检 / 验证 / 对账 / 结构扫描 / 连接写入**（`.ps1` 或 `.sh`） | 让 AI 真能动手，而非只会读 |
| 循环 | 固定闭环 + 收尾必更 SSOT | 自主迭代纠偏 |

**Adapter 是什么**：各家 AI 的「薄入口」，只负责让该工具自动加载上述核心。详见 `adapters/README.md`。

**Skill 是什么**：`skills/scaffold-dev-agent/` —— 教 AI 安装开发智能体 + 二开初始化。

### 新电脑 / 拷贝本仓库后（先做这一步）

把整个 `dev-agent-kit` 拷到新机器任意目录，在仓库根执行：

```powershell
.\install-global.ps1
```

```bash
chmod +x install-global.sh && ./install-global.sh
```

会把 Skill 写入各家全局目录，并生成 `kit-path.txt`（指向**本机**这份 kit）。之后在任意项目里一句话触发即可，不必再说路径。  
改完 Skill 后重新跑一遍 `install-global` 即可同步。

---

## 2. 六条通用洞见（最值钱，跨项目都成立）

1. **记忆要「每次都在」**：工具存在 ≠ 会被用。Cursor 用 `alwaysApply`；Claude 用 `CLAUDE.md`；Codex 读 `AGENTS.md`；Kiro 用 steering——都是同一意图。
2. **工具必须"真能执行"**：查库就真连库、自检就真跑、验证就真打接口。这是"智能体 vs 读过文档的助手"的分水岭。
3. **SSOT + 自动对账，对抗记忆漂移**：人工维护的进度文档一定会过时；要有一条命令能"核出真相"（见 `api-check`）。
4. **闭合验证缺口**：必须存在一个"改完立即能验"的环境（本地 dev server / 测试库），否则闭环断裂。
5. **工具要"响亮地失败"**：缺依赖必须报"缺依赖"，绝不能伪装成"一堆语法错"，否则 AI 会烧轮次去修不存在的问题。
6. **单一事实来源，物理清除矛盾源**：过时/矛盾的旧文档会毒化上下文，归档隔离甚至删除，只留白名单。

---

## 3. 搭建步骤（照做即可复制）

> 目标项目根目录下操作。带 `# ADAPT` 的地方按你的技术栈改。
> 完整敲击步骤见 **`操作文档.md`**。

### 步骤 1 — 装核心 + 选装 adapter
1. 复制 `templates/AGENTS.md` → 项目根 `AGENTS.md`，填项目简介、目录、核心约束。
2. 复制 `templates/docs/项目进度与完成度.md` → 项目 `docs/`（SSOT）。
3. 复制 `templates/scripts/*` → 项目 `scripts/`（按 OS 保留 `.ps1` 和/或 `.sh`）。
4. **按你用的 AI 选装**（可多选），见 `adapters/README.md`：
   - Cursor → `adapters/cursor/*.mdc` → `.cursor/rules/`
   - Claude Code → `adapters/claude/CLAUDE.md` → 根目录
   - Codex → 通常只需 `AGENTS.md`
   - Kiro → `adapters/kiro/steering/*` → `.kiro/steering/`

### 步骤 2 — 适配脚本（按栈替换实现）

| 工具类别 | 模板 | PHP/TP6 | Node/TS | Python |
|----------|------|---------|---------|--------|
| 查状态 | `db.ps1` / `db.sh` | `mysql -e`（只读单语句） | prisma / psql | `manage.py dbshell` |
| 连接写入 | `apply-mysql-dsn.ps1` / `.sh` | 从连接命令写 `.env` | 同左 | 同左 |
| 结构扫描 | `scan-project.ps1` / `.sh` | 目录/双 git/栈信号 | 同左 | 同左 |
| 自检 | `lint.ps1` / `lint.sh` | `php -l` | `tsc --noEmit` / eslint | `ruff` / `mypy` |
| 验证 | `smoke.ps1` / `smoke.sh` | 打 HTTP 接口 | vitest / supertest | pytest |
| 对账 | `api-check.ps1` / `api-check.sh` | 前端 URL↔后端方法 | OpenAPI schema diff | 契约检查 |

另有 `mysql.ps1` / `mysql.sh`（交互或批准后的写库；写库须记入 `docs/数据库连接与复盘.md`）。

### 步骤 3 — 定闭环纪律
在所用 adapter 的工具层入口里固化：`定位（SSOT / rg / 热文件）→ 只读命中文件 → 对账摘要 → 查状态 → 写码 → 自检 → 验证 → 更新 SSOT 触及的行`。不要把整仓或 `_scan-raw` 整份塞进对话。

### 步骤 4 — 治理
1. 建 ignore（Cursor: `.cursorignore`），隔离历史/噪音目录。
2. 密钥只留 `.env`，脚本从 `.env` 读、走环境变量传递，**不进命令行/规则/文档**。
3. 只保留"有效文档白名单"，其余归档或删除。

---

## 4. 验收标准（怎么算"搭完了"）

逐条实测，全过才算：

- [ ] 给 AI 一个任务，它**不问就知道**查库/自检/验证的入口（记忆生效）
- [ ] `查状态` 脚本能返回真实数据；写操作被拦截（只读安全）
- [ ] `自检` 脚本：正常文件绿；**缺依赖时报"缺依赖"而非"语法错"**（响亮失败）
- [ ] `验证` 脚本：能起 token/夹具，打通 ≥1 个真实接口
- [ ] `对账` 脚本：一条命令输出真实差异清单（记忆自愈）
- [ ] 存在"改完立即能验"的本地环境（验证缺口已闭合）
- [ ] SSOT 存在且有变更记录；噪音目录已隔离

**母本自检（不碰业务仓）**：

```powershell
./fixtures/dry-run.ps1
```

> 前置：`php` 在 PATH（或设 `LZ_PHP`）——lint / smoke 项需要它；缺 php 时这两项会报 `FAIL`，属环境前置而非脚本缺陷。  
> 有 Git Bash 时会跑 `.sh`（含 `install.sh` merge-safe）；CI 用 `-RequireBash`，缺 bash 即失败。GitHub Actions 在 push/PR 上跑同一条，不靠人记得。

---

## 5. 目录

> 想直接动手？看 **`操作文档.md`**。  
> 各 AI 怎么触发？看 **`各工具使用指南.md`**。

```
dev-agent-kit/
  install-global.ps1|.sh             # 新电脑一键：写入各家全局 skills + kit-path
  README.md                          # 本文件：方法论 + 步骤 + 验收
  操作文档.md                        # 落地 SOP（照着敲）
  各工具使用指南.md                  # Cursor/Kiro/WorkBuddy/Qoder/Codex 怎么用
  skills/
    scaffold-dev-agent/              # 全局 Skill：安装 + 二开初始化学习
      SKILL.md
      init-workflow.md               # 一口气分析 FE/BE 的标准流程
      adapter-map.md
      scripts/install.ps1|.sh
  adapters/                          # 各家 AI 薄入口（可叠加）
    README.md                        # adapter 合同 + 安装
    _common/                         # 共享文案母本
    cursor/                          # → .cursor/rules/*.mdc
    claude/                          # → CLAUDE.md
    codex/                           # Codex 用 AGENTS.md（说明）
    kiro/steering/                   # → .kiro/steering/*.md
    workbuddy/                       # → CODEBUDDY.md + .codebuddy/rules/
    qoder/                           # → .qoder/rules/
  templates/
    AGENTS.md                        # 项目入口模板（Codex 原生）
    cursor-rules/                    # 与 adapters/cursor 同步的副本（兼容旧路径）
    docs/
      项目进度与完成度.md            # SSOT 骨架
      项目结构与架构.md              # 初始化学习产出
      数据库连接与复盘.md            # MySQL 连接摘要 + 写库复盘（无密码）
    scripts/
      db.ps1 / db.sh                 # 查状态（只读单语句；禁 ; 与 \g）
      apply-mysql-dsn.ps1 / .sh      # 从连接命令/DSN 写 .env
      mysql.ps1 / mysql.sh           # 交互 / 批准后的写库
      scan-project.ps1 / .sh         # 结构扫描（初始化用）
      lint.ps1 / lint.sh             # 自检
      smoke.ps1 / smoke.sh           # 验证
      api-check.ps1 / api-check.sh   # 对账
  fixtures/
    README.md
    dry-run.ps1                      # 假项目空跑验收（TEMP 副本；可选 -RequireBash）
    fake-project/                    # 靶场骨架（无 scripts、无 adapter 副本；dry-run 从 templates + adapters 注入 TEMP）
```

---

## 6. 什么时候值得搞

- **值得**：长期维护、多人/多对话、复杂或有历史包袱的项目。基建成本会被反复摊薄。
- **不值得**：一次性脚本、几十行 demo。搭基建的成本 > 收益。

---

## 7. 同步约定（kit 与项目实例，避免双份漂移）

kit 里的 `templates/scripts/*` 与 `adapters/*` 是**母本**；拷进项目后的文件是**实例**。

1. **母本 = kit**：结构性改进（安全拦截、退出码语义、adapter 合同）**先改 kit，再同步到各项目实例**。
2. **实例专属**：仅适配某项目的内容（路径、端点、`# ADAPT`）**只留在实例**，不回灌母本。
3. **判断标准**：问"这改动对别的项目也成立吗？" —— 成立 → 进 kit；只对本项目成立 → 留实例。
4. **Cursor 规则双份**：`adapters/cursor/` 为权威；`templates/cursor-rules/` 保持同步副本，方便旧 SOP。
5. **禁止**：把具体业务（如某产品仓）的代码/文档写进本 kit。
