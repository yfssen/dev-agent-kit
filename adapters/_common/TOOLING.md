# 工具层（AI 自主干活的固定入口）

本项目已具备可用工具，遇到相应任务**直接用**，不要说"无法访问"。

脚本：Windows 用 `*.ps1`，Linux/macOS 用 `*.sh`（逻辑相同）。

## 0. 初始化扫描 / MySQL 连接

```
./scripts/scan-project.ps1 [-OutFile docs/_scan-raw.md]
./scripts/mysql.ps1          # interactive; password from .env via MYSQL_PWD
./scripts/db.ps1 "<只读 SQL>"
```

双 git 时 `.env` 常在后端目录——改脚本里 `# ADAPT` 的 `.env` 路径。

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

## 4. 对账（谈进度/改错位前必跑）

```
./scripts/api-check.ps1
./scripts/api-check.sh
```

- 抽前端调用 ↔ 比对后端方法是否存在；输出带 `文件:行号`
- **这是错位表的对账源**：更新 SSOT 前先跑它拿真实清单

## 5. 标准工作闭环

```
对账(api-check) → 查状态(db) → 按规范写码 → 自检(lint) → 验证(smoke) → 更新 SSOT
```
