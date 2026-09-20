

# 开发智能体启动套件（Dev-Agent Kit）

> 把任意一个项目，配成一个"懂它、能自主开发和测试"的开发智能体。本套件从实践中抽象而来，**与技术栈无关、与 AI 产品无关**（Cursor / Claude Code / Codex / Kiro 等均可）。

## 项目简介

Dev-Agent Kit 是一套让 AI 编程工具在具体项目里自主完成「定位现行逻辑 → 写码 → 自检/验证/对账 → 更新进度」闭环的配置方法、模板与各家薄入口。本套件不把整仓塞进上下文，而是通过记忆、工具和闭环纪律，让 AI 从"读过文档的助手"升级成"能独立干活的开发智能体"。

**核心价值**：与模型无关、与技术栈无关，提供统一的智能体开发框架，让 AI 具备长期记忆能力和真实操作能力。

## 核心特性

- **技术栈无关**：提供 PHP、Node.js、Python 等多套脚本模板，按需适配
- **AI 产品无关**：支持 Cursor、Claude Code、Codex、Kiro、WorkBuddy、Qoder 等主流 AI 编程工具
- **轻量级入口**：各 AI 工具通过薄 adapter 加载核心配置，不增加认知负担
- **完整闭环**：定位 → 只读 → 对账 → 查状态 → 写码 → 自检 → 验证 → 更新 SSOT
- **SSOT 设计**：单一事实来源设计，通过 `api-check` 等工具自动对账，防止记忆漂移

## 支持的 AI 工具

| 工具 | 适配方式 | 安装位置 |
|------|----------|----------|
| Cursor | `.mdc` 规则文件 | `.cursor/rules/` |
| Claude Code | `CLAUDE.md` | 项目根目录 |
| Codex | `AGENTS.md` | 项目根目录 |
| Kiro | steering 文件 | `.kiro/steering/` |
| WorkBuddy | `CODEBUDDY.md` + 规则 | `.codebuddy/` |
| Qoder | 规则文件 | `.qoder/rules/` |

## 快速开始

### 新环境初始化

将本仓库克隆到本地后，在仓库根目录执行：

```powershell
# PowerShell
.\install-global.ps1

# Bash
chmod +x install-global.sh && ./install-global.sh
```

此操作会将 Skill 写入各 AI 工具的全局目录，并生成 `kit-path.txt` 指向本机上的 kit 路径。

### 项目级部署

在目标项目根目录下：

1. 复制 `templates/AGENTS.md` → 项目根 `AGENTS.md`
2. 复制 `templates/docs/项目进度与完成度.md` → 项目 `docs/` 目录
3. 复制 `templates/scripts/*` → 项目 `scripts/` 目录
4. 按需安装对应 AI 工具的 adapter

## 目录结构

```
dev-agent-kit/
├── install-global.ps1|.sh           # 全局安装脚本
├── README.md                         # 本文档
├── 操作文档.md                       # 落地操作指南
├── 各工具使用指南.md                 # 各 AI 工具使用说明
│
├── skills/                           # 全局 Skill
│   └── scaffold-dev-agent/           # 开发智能体安装与初始化
│       ├── SKILL.md
│       ├── init-workflow.md          # 项目初始化标准流程
│       └── scripts/
│
├── adapters/                         # 各家 AI 薄入口
│   ├── README.md                     # Adapter 合同与安装说明
│   ├── _common/                      # 共享文案母本
│   ├── cursor/                       # Cursor 适配
│   ├── claude/                       # Claude Code 适配
│   ├── codex/                        # Codex 适配
│   ├── kiro/steering/                # Kiro 适配
│   ├── workbuddy/                    # WorkBuddy 适配
│   └── qoder/                        # Qoder 适配
│
├── templates/                        # 项目模板
│   ├── AGENTS.md                     # 项目入口模板
│   ├── cursor-rules/                 # Cursor 规则副本
│   ├── docs/                         # 文档模板
│   │   ├── 项目进度与完成度.md       # SSOT 进度文档
│   │   ├── 项目结构与架构.md         # 项目结构说明
│   │   └── 数据库连接与复盘.md       # 数据库连接摘要
│   └── scripts/                      # 脚本模板
│       ├── db.ps1 / db.sh            # 查状态（只读）
│       ├── mysql.ps1 / mysql.sh      # 交互/写库
│       ├── scan-project.ps1 / .sh    # 结构扫描
│       ├── lint.ps1 / lint.sh        # 自检
│       ├── smoke.ps1 / smoke.sh      # 验证
│       └── api-check.ps1 / api-check.sh  # 对账
│
└── fixtures/                         # 测试用例
    ├── dry-run.ps1                   # 验收测试脚本
    └── fake-project/                 # 靶场项目
```

## 脚本工具说明

| 脚本 | 用途 | 安全特性 |
|------|------|----------|
| `db` | 查询数据库状态 | 只读单语句，禁止多语句 |
| `mysql` | 交互式/批准后的写库 | 需人工批准，禁用 `;` 和 `\g` |
| `scan-project` | 项目结构扫描 | 用于初始化学习 |
| `lint` | 代码自检 | 缺依赖时报"缺依赖"，不伪装成语法错误 |
| `smoke` | 接口/功能冒烟验证 | 需打通真实接口 |
| `api-check` | 进度对账 | 自动生成差异清单 |
| `apply-mysql-dsn` | 从 DSN 写入 .env | 连接配置安全写入 |

## 验收标准

部署完成后，项目应满足以下条件：

- [ ] AI 能够自主使用查库、自检、验证等脚本工具
- [ ] `db` 脚本返回真实数据，写操作被安全拦截
- [ ] `lint` 脚本对正常文件通过，对缺依赖报错明确（非语法错误伪装）
- [ ] `smoke` 脚本能访问至少一个真实接口
- [ ] `api-check` 脚本能输出真实进度差异
- [ ] 存在"改完立即能验"的本地环境
- [ ] SSOT 文档存在且有变更记录

执行验收测试：

```powershell
./fixtures/dry-run.ps1
```

## 六条通用洞见

1. **记忆要「每次都在」**：工具存在 ≠ 会被使用，需在各 AI 平台配置自动加载
2. **工具必须"真能执行"**：查库就真连库、自检就真跑，这是智能体与普通助手的分水岭
3. **SSOT + 自动对账**：人工维护的进度文档必过时，需有命令能"核出真相"
4. **闭合验证缺口**：必须存在"改完立即能验"的环境，否则闭环断裂
5. **工具要"响亮地失败"**：错误信息必须明确，避免 AI 烧轮次去修不存在的问题
6. **单一事实来源**：过时/矛盾的文档会毒化上下文，需归档隔离或删除

## 适用场景

**值得使用**：
- 长期维护的项目
- 多人协作、多轮对话的场景
- 复杂或有历史包袱的项目

**不建议使用**：
- 一次性脚本或 Demo
- 几十行代码的简单项目（基建成本 > 收益）

## 许可证

本项目采用 MIT 许可证开源，详见 `LICENSE` 文件。

## 致谢

本套件从实践中抽象而来，目标是让更多项目能够享受 AI 辅助开发的效率提升，同时保持代码质量和工程规范的严谨性。