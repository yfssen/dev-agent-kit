---
description: Coding rules: no BOM, no emoji, write it straight
alwaysApply: true
trigger: always_on
---

# 代码生成铁律

1. **编码 UTF-8**：源码/文本配置一律 UTF-8。
2. **无 BOM**：UTF-8 without BOM。
3. **注释无表情**：禁止 emoji/表情符号；用文字（OK/FAIL/TODO）。
4. `*.ps1` / `*.sh`：纯 ASCII、无 BOM。
5. **直写，少包一层**：逻辑放在现有函数里，能从入口顺着看到结果。不为一次调用新造接口、基类、工厂或通用层。后端沿现有控制器和服务往下写，不先搭用不上的分层。
