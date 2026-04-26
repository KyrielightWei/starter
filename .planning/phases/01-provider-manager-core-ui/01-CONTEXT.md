# Phase 1: Provider Manager Core UI - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

用户可以通过管理面板查看和管理 Provider/Model 配置，实现 CRUD 操作：
- 查看所有已配置的 Provider 和 Model（PMGR-01）
- 添加新的 Provider/Model 配置（PMGR-02）
- 删除 Provider/Model 配置（PMGR-03）
- 编辑 Provider/Model 配置（PMGR-04）

**不包含：** 可用性检测、Agent-Model 配置（属于 Phase 2-3）

</domain>

<decisions>
## Implementation Decisions

### 管理面板交互模式
- **D-01:** 扩展现有 `model_switch.lua` picker，添加 CRUD actions
- **D-02:** 保持两步选择流程（先选 provider → 再选 model），在每步添加 CRUD 操作

### CRUD 操作 UI 设计
- **D-03:** Ctrl-A 触发添加操作，弹出 vim.ui.input 输入 provider 名称
- **D-04:** Ctrl-D 触发删除操作，删除当前选中项（需确认）
- **D-05:** Ctrl-E 触发编辑操作，直接打开 `lua/ai/providers.lua` 编辑配置

### Provider 编辑范围
- **D-06:** 管理所有字段：endpoint/base_url、默认模型、static_models 列表、Provider 名称
- **D-07:** 支持重命名 Provider 显示名称

### 入口命令/Keymap（the agent discretion）
- **D-08:** Keymap `<leader>kp` 打开 Provider Manager
- **D-09:** User command `:AIProviderManager` 打开管理面板

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Definition
- `.planning/ROADMAP.md` §Phase 1 — Phase goal and success criteria
- `.planning/REQUIREMENTS.md` §PMGR-01-04 — Acceptance criteria for each requirement

### Project Context
- `.planning/PROJECT.md` — Core value and constraints
- `.planning/research/SUMMARY.md` — Stack recommendations and patterns

### Existing Code Patterns
- `lua/ai/model_switch.lua` — FZF-lua two-step picker pattern to extend
- `lua/ai/providers.lua` — Provider registry with 12 providers
- `lua/ai/keys.lua` — API key storage CRUD pattern
- `lua/ai/skill_studio/picker.lua` — Custom FZF-lua actions example

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `model_switch.lua`: FZF-lua picker with two-step flow (provider → model) — extend with CRUD actions
- `providers.lua`: `register()`, `list()`, `get()` API — foundation for registry operations
- `keys.lua`: `read()`, `write()`, `edit()` API — pattern for config file CRUD
- `skill_studio/picker.lua`: Custom FZF-lua actions (Ctrl-key bindings) — reference for action design

### Established Patterns
- **FZF-lua picker pattern**: `fzf_exec()` with `actions` table, multi-step selection
- **Lua config file pattern**: `dofile()` for read, `vim.fn.writefile()` for write
- **Lazy.nvim plugin pattern**: `keys = {}` trigger for keymaps, `cmd = {}` for user commands

### Integration Points
- `lua/ai/init.lua`: Add `<leader>kp` keymap and `:AIProviderManager` command
- `lua/plugins/ai.lua`: May need to adjust if keymap conflicts exist
- `~/.local/state/nvim/ai_keys.lua`: Storage for user-modified provider configs

</code_context>

<specifics>
## Specific Ideas

- FZF-lua picker 的 Ctrl-actions 应显示快捷键提示（如底部显示 `Ctrl-A: Add, Ctrl-D: Delete, Ctrl-E: Edit`）
- 编辑操作直接打开 `providers.lua` 而非弹出输入框，因为 provider 配置涉及多个字段
- 删除操作需要确认（`vim.ui.select` 或 `vim.ui.input` 确认），避免误删

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-provider-manager-core-ui*
*Context gathered: 2026-04-21*