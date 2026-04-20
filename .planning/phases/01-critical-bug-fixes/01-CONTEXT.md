# Phase 1: Critical Bug Fixes - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

修复 5 个关键阻塞性 Bug，确保 AI 组件管理系统的核心功能（组件切换、配置生成、版本检测、卸载）正常工作。

**本阶段不交付:**
- 缓存 + 分发架构 (Phase 2)
- 进度 UI (Phase 4)
- 组件接口扩展 (Phase 2)

**下游代理须知:**
- 所有修复针对现有代码的 BUG，不改变接口设计
- 修复后配置生成器应能响应 `Switcher.get_active()` 返回的组件分配
- 错误处理需包含用户引导信息

</domain>

<decisions>
## 实现决策

### 错误处理策略
- **ED-01:** 当配置生成器找不到 switcher 指定的组件时，报错退出（不静默降级）
- **ED-02:** 错误信息需显示当前组件状态 + 提供快速修复操作选项（如「部署到工具」、「切换为其他组件」）
- **ED-03:** 错误处理统一应用于 `opencode.lua` 和 `claude_code.lua` 两个配置生成器

### 修复优先级
- **FIX-01** (opencode.lua 死代码) → **FIX-02** (opencode.lua 动态化) → **FIX-03** (claude_code.lua 动态化) → **FIX-04** (list_outdated) → **FIX-05** (ECC 卸载器)
- FIX-01 必须在 FIX-02 之前完成，因为死代码会导致运行时错误
- FIX-02 和 FIX-03 结构类似，可参考彼此实现

### 降级策略
- 阶段明确：**报错退出**而非自动降级，确保用户明确知道当前状态
- 不区分「未安装」和「未部署」场景，统一报错 + 引导

</decisions>

<canonical_refs>
## Canonical References

**下游代理在规划或实现前必须阅读以下内容。**

### 项目架构
- `.planning/PROJECT.md` — 项目目标、关键决策
- `.planning/ROADMAP.md` — 阶段目标和成功标准
- `.planning/REQUIREMENTS.md` — FIX-01 到 FIX-05 的详细需求
- `.planning/codebase/COMPONENTS.md` — 当前组件状态和已知 BUG
- `docs/dev/COMPONENT_MANAGER.md` — 完整设计文档
- `docs/dev/COMPONENT_MANAGER_LOG.md` — 工作日志和变更历史

### 代码文件
- `lua/ai/opencode.lua` — OpenCode 配置生成器 (需修复: 520 行, 453-516 行)
- `lua/ai/claude_code.lua` — Claude Code 配置生成器 (需修复: 硬编码 ECC)
- `lua/ai/components/switcher.lua` — 组件切换状态管理
- `lua/ai/components/registry.lua` — 组件注册表 (需修复 list_outdated)
- `lua/ai/components/ecc/uninstaller.lua` — ECC 卸载器 (需修复: 误删目录)
- `~/.local/state/nvim/ai_component_state.lua` — 状态文件路径

### 组件接口
- `lua/ai/components/interface.lua` — 组件接口规范定义
- `lua/ai/components/ecc/init.lua` — ECC 组件实现
- `lua/ai/components/gsd/init.lua` — GSD 组件实现
</canonical_refs>

<code_context>
## 现有代码洞察

### 可复用资产
- `Switcher.get_active(tool)` → 已存在，返回工具当前分配的组件名
- `Switcher.get_all()` → 已存在，返回所有工具分配映射
- `Registry.get(name)` → 已存在，返回指定组件对象
- `Registry.list()` → 已存在，列出所有组件（快速，无网络请求）

### 已建立模式
- 配置生成器通过 `M.generate_config()` 生成配置，然后写入工具特定文件
- 状态文件使用 `~/.local/state/nvim/` 目录
- 组件发现使用自动扫描 `lua/ai/components/` 目录下的子目录

### 集成点
- `opencode.lua:write_config()` → 写入 `~/.config/opencode/opencode.json`
- `claude_code.lua:write_settings()` → 写入 `~/.claude/settings.json`
- 组件安装/部署由 `ai/components/` 下的各组件模块处理
</code_context>

<specifics>
## 特定想法

无特定设计要求 — 采用标准修复方案。

</specifics>

<deferred>
## 延期想法

无 — 讨论保持在阶段范围内。

</deferred>

---

*Phase: 01-critical-bug-fixes*
*Context gathered: 2026-04-19*
