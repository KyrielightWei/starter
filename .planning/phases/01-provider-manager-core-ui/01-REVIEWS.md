---
phase: 01
reviewers: [glm-5, qwen3.6-plus]
reviewed_at: "2026-04-22"
plans_reviewed: [01-01-PLAN.md, 01-02-PLAN.md, 01-03-PLAN.md]
---

# Cross-AI Plan Review — Phase 01

## glm-5 Review

### Plan 01-01: Registry & Validator modules (TDD)

**Summary:** 这个计划建立了 Provider Manager 的核心数据层——validator.lua 负责输入验证，registry.lua 提供 CRUD API。整体设计合理，测试驱动开发方法恰当。但存在几个关键技术问题：对 providers.lua 的理解有偏差、delete_provider 实现过于简化、find_provider_line 使用硬编码路径。

**Strengths:**
- TDD 方法得当，测试用例覆盖核心验证场景
- Threat model 明确了输入验证边界
- 接口契约定义清晰（validate_provider_name 返回 bool + error_msg）
- 遵循现有 AGENTS.md 代码风格

**Concerns:**

| Severity | Issue |
|----------|-------|
| **HIGH** | `registry.lua` 第 191 行 `for name, def in pairs(Providers)` 错误——`Providers` 是模块而非 provider 列表。应使用 `Providers.list()` |
| **HIGH** | `delete_provider()` 只清理内存状态，不持久化到 `providers.lua` 文件。重启后 provider 会恢复 |
| **HIGH** | `find_provider_line()` 使用硬编码路径 `"lua/ai/providers.lua"` |
| **MEDIUM** | validator 正则不允许 kebab-case 中使用 `-` |
| **MEDIUM** | 未处理 `Providers.get(name)` 返回 nil 时的边界情况 |
| **LOW** | 测试用例未 mock `vim.notify` |

**Risk Assessment:** **MEDIUM** — 数据层实现有重大逻辑错误

---

### Plan 01-02: Picker UI with CRUD actions

**Summary:** Picker UI 计划构建了用户交互层，使用 FZF-lua 展示 provider 列表并绑定 Ctrl-A/D/E 快捷键。设计遵循 skill_studio picker 模式，但存在 API 选择偏差、空状态处理不完整等问题。

**Strengths:**
- Help window 实现完整，遵循 skill_studio 模式
- 确认对话框逻辑清晰
- Header hints 符合 UI-SPEC 规范
- Ctrl-key actions 绑定设计一致

**Concerns:**

| Severity | Issue |
|----------|-------|
| **HIGH** | FZF API 选择偏差（fzf_exec vs fzf_contents） |
| **HIGH** | name_map 构建依赖 Plan 01 的错误输出 |
| **MEDIUM** | 空状态提示文案语言不统一 |
| **MEDIUM** | vim.ui.input 异步 API 在 headless 测试中行为不确定 |
| **MEDIUM** | Ctrl-E 编辑未提示字段位置 |
| **LOW** | show_help 窗口高度固定 |

**Risk Assessment:** **HIGH** — FZF API 选择可能导致 picker 无法正常工作

---

### Plan 01-03: Integration + keymap/command

**Summary:** 集成计划负责将 Provider Manager 注册到 AI 模块。整体设计遵循 skill_studio 集成模式，但存在 ai/init.lua 结构理解偏差、keymap 位置未明确等问题。

**Strengths:**
- pcall 加载模式遵循 skill_studio 集成
- setup() 返回模块支持链式调用
- keymap/command 注册逻辑清晰

**Concerns:**

| Severity | Issue |
|----------|-------|
| **HIGH** | ai/init.lua setup() 函数结构理解偏差 |
| **MEDIUM** | `<leader>kp` 可能与现有 keymap 冲突 |
| **MEDIUM** | Human verify checkpoint 不够具体 |
| **LOW** | 未给出具体代码位置 |

**Risk Assessment:** **LOW** — 集成逻辑简单，主要是位置和冲突问题

---

## qwen3.6-plus Review

### Plan 01-01: Registry & Validator modules (TDD)

**Summary:** 该计划设计良好，采用 TDD 方法构建 Provider Manager 的底层基础设施。但存在几个关键问题：`delete_provider` 的实现只是内存删除而非文件持久化、`find_provider_line` 使用硬编码路径、缺少与 keys.lua 的集成考虑。

**Strengths:**
- TDD 方法确保代码质量，测试用例明确
- validator 的正则验证完整
- 重复检查符合现有 API 模式
- 威胁模型考虑了 Tampering 类别

**Concerns:**

| Severity | Issue |
|----------|-------|
| **HIGH** | `delete_provider()` 未持久化到文件 |
| **HIGH** | `find_provider_line()` 使用硬编码路径 |
| **MEDIUM** | `add_provider()` 缺少模板生成功能 |
| **MEDIUM** | 未考虑 `keys.lua` 的 `ai_keys.lua` 文件同步 |
| **LOW** | 测试用例未覆盖排序逻辑 |

**Suggestions:**
- `delete_provider()` 应追加文件修改逻辑
- 路径应动态计算
- `add_provider()` 应生成基础模板
- 添加 keys.lua 清理

**Risk Assessment:** **MEDIUM**

---

### Plan 01-02: Picker UI with CRUD actions

**Summary:** Picker UI 设计遵循了 skill_studio/picker.lua 的成熟模式。但存在几个集成风险：empty state 的处理与 name_map 冲突、vim.ui.input 的回调上下文丢失、Step 2 model selection 标记 TODO 但未实现。

**Strengths:**
- Ctrl-key actions 绑定完整
- Help Window 实现与 skill_studio 一致
- Display format 符合 UI-SPEC
- Header 提示字符串清晰

**Concerns:**

| Severity | Issue |
|----------|-------|
| **HIGH** | Empty state 处理存在 bug |
| **HIGH** | `vim.ui.input` 回调中 `selected` 变量上下文可能丢失 |
| **MEDIUM** | `<CR>` Select action 标注 TODO，缺少 Step 2 实现 |
| **MEDIUM** | 确认对话框应使用 `vim.ui.select` |
| **LOW** | 测试未覆盖 action handlers |

**Suggestions:**
- Empty state 应检查并 early return
- Add/Delete 后应刷新 picker
- 复用 model_switch.lua 的模型获取逻辑
- 确认改用 vim.ui.select

**Risk Assessment:** **MEDIUM**

---

### Plan 01-03: Integration + keymap/command

**Summary:** Integration 计划简洁，遵循 skill_studio 的 pcall 加载模式。但 Human Verify checkpoint 的验证步骤缺少关键测试场景。

**Strengths:**
- `init.lua` 结构遵循 skill_studio 模式
- Keymap 与现有 `<leader>k` prefix 一致
- 命令命名符合风格
- Human Verify 提供完整验证步骤清单

**Concerns:**

| Severity | Issue |
|----------|-------|
| **MEDIUM** | Human Verify 步骤未考虑操作后刷新 |
| **MEDIUM** | ai/init.lua 整合位置不明确 |
| **LOW** | 测试未验证 keymap/command 实际注册 |
| **LOW** | delegation 可能丢失闭包上下文 |

**Risk Assessment:** **LOW**

---

## Consensus Summary

### Agreed Strengths (2+ reviewers)

1. **TDD 方法得当** — 两个 reviewer 都认可测试驱动开发方法
2. **Ctrl-key actions 绑定完整** — Help window 和 header hints 设计一致
3. **Integration 结构正确** — pcall 加载模式遵循 skill_studio

### Agreed Concerns (HIGH priority — both reviewers raised)

| Concern | Severity | Plan | Fix Required |
|---------|----------|------|--------------|
| `delete_provider()` 未持久化到文件 | HIGH | 01-01 | 实现文件修改逻辑，移除 M.register() 行 |
| `find_provider_line()` 硬编码路径 | HIGH | 01-01 | 使用 `vim.fn.stdpath("config")` 或项目相对路径 |
| Empty state name_map 处理 bug | HIGH | 01-02 | 检查并 early return，避免选中空提示行 |
| Registry.list_providers() 返回结构错误 | HIGH | 01-01 | 使用 `Providers.list()` 而非 `pairs(Providers)` |

### Divergent Views

| Issue | glm-5 View | qwen3.6-plus View | Resolution |
|-------|------------|-------------------|------------|
| FZF API 选择 | 认为 fzf_exec vs fzf_contents 是 HIGH 问题 | 未提及 API 选择问题 | **采用 fzf_exec**（与 model_switch.lua 一致，更简单） |
| keys.lua 集成 | 未提及 | 认为 MEDIUM 问题（删除后 keys.lua 残留） | **采纳 qwen 建议**：添加 Keys.cleanup(name) |
| Step 2 缺失 | 未明确提及 | 认为 MEDIUM 问题，核心功能不完整 | **采纳 qwen 建议**：实现 model selection 或明确标注 deferred |

### Requirement Coverage Assessment

| Requirement | Status | Notes |
|-------------|--------|-------|
| PMGR-01 查看所有 Provider | PARTIAL | `list_providers()` 完成，但 Step 2 model selection 缺失 |
| PMGR-02 添加 Provider | PARTIAL | 打开文件编辑，但缺少模板生成 |
| PMGR-03 删除 Provider | FAIL | 内存删除不持久化，重启后恢复 |
| PMGR-04 编辑 Provider | PASS | Ctrl-E 打开 providers.lua 功能完整 |

---

## Recommended Fixes Before Execution

### Priority 1 (Blocking)

1. **Plan 01-01 Task 2:** 修改 `delete_provider()` 实现文件持久化
2. **Plan 01-01 Task 2:** 使用 `Providers.list()` 替代 `pairs(Providers)`
3. **Plan 01-01 Task 2:** 动态计算 `providers.lua` 路径

### Priority 2 (Important)

4. **Plan 01-02 Task 1:** 修复 empty state 的 name_map 处理
5. **Plan 01-02 Task 1:** 明确 FZF API 使用 `fzf_exec`
6. **Plan 01-02:** 实现 Step 2 model selection 或标注 deferred

### Priority 3 (Enhancement)

7. **Plan 01-01:** 添加 keys.lua cleanup
8. **Plan 01-01:** 添加 provider 配置模板生成
9. **Plan 01-02:** 确认对话框改用 vim.ui.select

---

## Overall Risk Assessment

**MEDIUM-HIGH**

Phase 01 无法满足所有 acceptance criteria，主要因为：
- PMGR-03（删除）功能不完整（不持久化）
- PMGR-01（查看）Step 2 缺失

---

*Reviews completed: 2026-04-22*
*To incorporate feedback: `/gsd-plan-phase 1 --reviews`*