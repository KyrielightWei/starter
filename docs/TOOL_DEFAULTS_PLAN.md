# Tool-Specific Default Configuration & Multi-Model Support

## Overview

Extend the existing global default provider/model system to support per-tool (OpenCode, Claude Code) independent default configurations with multi-model slots. Add a model recommender module that analyzes model capabilities and automatically suggests appropriate models for different roles (fast, reasoning, balanced).

## Requirements

- Each tool (opencode, claude) can have its own default provider + model, independent of global default
- Claude Code supports multi-model configuration: main_model, small_model, haiku_model, opus_model, sonnet_model
- OpenCode supports: model (main) and small_model (fast alternative)
- Priority chain: tool_defaults > global_default > hardcoded fallback
- Intelligent model recommendation based on capability profiles (reusing existing `model_selector.lua` patterns)
- Model Switch UI extended to select configuration target (global / opencode / claude)
- Full backward compatibility with existing `ai_keys.lua` format

## Architecture Changes

| File | Change Type | Description |
|------|-------------|-------------|
| `lua/ai/keys.lua` | Modify | Add `tool_defaults` section read/write, new APIs |
| `lua/ai/model_recommender.lua` | **New** | Model capability analysis and backup recommendation |
| `lua/ai/model_switch.lua` | Modify | Add target selection step (global/opencode/claude) + multi-model UI |
| `lua/ai/provider_manager/registry.lua` | Modify | Add `get_tool_default(tool)` / `set_tool_default(tool, config)` |
| `lua/ai/claude_code.lua` | Modify | Use tool-specific config for multi-model env vars |
| `lua/ai/opencode.lua` | Modify | Use tool-specific config for model/small_model |
| `lua/ai/config_resolver.lua` | Modify | Resolve tool defaults in `get_defaults()` |

## Data Structure Design

### Extended `ai_keys.lua` format

```lua
return {
  global_default = {
    provider = "zenmux",
    model = "anthropic/claude-opus-4.6",
  },

  -- NEW: Tool-specific defaults
  tool_defaults = {
    opencode = {
      provider = "zenmux",
      main_model = "anthropic/claude-sonnet-4.6",
      small_model = "anthropic/claude-haiku-4.5",
    },
    claude = {
      provider = "bailian_coding",
      main_model = "glm-5",
      small_model = "qwen3.5-plus",
      haiku_model = "qwen3.5-plus",
      opus_model = "glm-5",
      sonnet_model = "qwen3.6-plus",
    },
  },

  profile = "default",
  bailian_coding = { ... },
  zenmux = { ... },
}
```

### Model Slot Definitions

| Tool | Slot | Fallback Chain | Maps To |
|------|------|----------------|---------|
| opencode | main_model | tool.main_model > global_default.model | `opencode.json` "model" |
| opencode | small_model | tool.small_model > tool.main_model | `opencode.json` "small_model" |
| claude | main_model | tool.main_model > global_default.model | `ANTHROPIC_MODEL` |
| claude | small_model | tool.small_model > tool.main_model | `ANTHROPIC_SMALL_FAST_MODEL` |
| claude | haiku_model | tool.haiku_model > tool.small_model | `ANTHROPIC_DEFAULT_HAIKU_MODEL` |
| claude | opus_model | tool.opus_model > tool.main_model | `ANTHROPIC_DEFAULT_OPUS_MODEL` |
| claude | sonnet_model | tool.sonnet_model > tool.main_model | `ANTHROPIC_DEFAULT_SONNET_MODEL` |

## Implementation Steps

### Phase 1: Data Layer (Keys + Registry API)

**1.1 Extend `Keys` module with tool_defaults read/write**

File: `lua/ai/keys.lua`

- Add `M.get_tool_default(tool_name)` that reads `tbl.tool_defaults[tool_name]` and returns `{ provider, main_model, small_model, ... }` or nil
- Add `M.set_tool_default(tool_name, config)` that writes to `tbl.tool_defaults[tool_name]`
- Update `M.write()` to serialize `tool_defaults` section (preserving existing format)
- Update `M.ensure()` to include empty `tool_defaults = {}` placeholder in new files

**1.2 Extend Registry with tool-aware APIs**

File: `lua/ai/provider_manager/registry.lua`

- Add `M.get_tool_default(tool_name)` that returns `{ provider, model }` with fallback to global_default
- Add `M.set_tool_default(tool_name, config)` that delegates to `Keys.set_tool_default` and triggers sync
- Add `M.get_tool_model(tool_name, slot)` that resolves a specific model slot with fallback chain

**1.3 Update `Keys.write()` serialization for tool_defaults**

- In `M.write()`, after writing `global_default`, serialize `tool_defaults` as a nested Lua table
- In the main loop, add `tool_defaults` to the skip list alongside `profile` and `global_default`

---

### Phase 2: Model Recommender Module

**2.1 Create model_recommender.lua**

File: `lua/ai/model_recommender.lua` (NEW)

- Create module that reuses `model_selector.lua` capability profiles
- Implement `M.recommend_for_tool(tool_name, provider_name, main_model)`:
  - Analyzes main_model's profile
  - Recommends complementary models for each slot
  - Returns `{ small_model = "...", opus_model = "...", sonnet_model = "...", haiku_model = "..." }`
- Implement `M.get_model_profile(provider_name, model_id)`:
  - Check `model_selector.lua` profiles first
  - Fallback: check `providers.model_info`
  - Fallback: return generic balanced profile

**2.2 Extend model_selector profiles for zenmux models**

File: `lua/ai/model_selector.lua`

- Add profiles for zenmux models: `anthropic/claude-opus-4.7`, `anthropic/claude-opus-4.6`, `anthropic/claude-sonnet-4.6`, `anthropic/claude-haiku-4.5`, `z-ai/glm-5.1`, `deepseek/deepseek-v4-pro`, etc.

---

### Phase 3: Model Switch UI Enhancement

**3.1 Add target selection step**

File: `lua/ai/model_switch.lua`

- Add Step 0 before current Step 1 with options: Global Default, OpenCode, Claude Code
- If tool selected, proceed with provider > main_model > ask about backup models

**3.2 Add multi-model configuration UI for tools**

- After main model is selected, show options: Auto-recommend, Manual select, Skip
- If "Auto-recommend": call `model_recommender.recommend_for_tool()`, display recommendations, confirm
- If "Manual select": for each slot, show fzf picker
- On confirm, call `Registry.set_tool_default(tool, config)`

---

### Phase 4: Configuration Generation Updates

**4.1 Update claude_code.lua to use tool defaults**

File: `lua/ai/claude_code.lua`

- Modify `build_provider_settings()`:
  - Call `Registry.get_tool_default("claude")` instead of `Registry.get_global_default()`
  - Map multi-model slots to env vars
  - Fallback: if no tool default, fall through to global_default

**4.2 Update opencode config_resolver to use tool defaults**

File: `lua/ai/config_resolver.lua`

- Modify `M.get_defaults()`:
  - Call `Registry.get_tool_default("opencode")`
  - If exists, use tool_default for model and small_model
  - Fallback: current behavior (global_default)

---

### Phase 5: Testing & Validation

**5.1 Unit tests for Keys tool_defaults API**

File: `tests/ai/keys_tool_defaults_spec.lua` (NEW)

**5.2 Unit tests for model_recommender**

File: `tests/ai/model_recommender_spec.lua` (NEW)

**5.3 Integration tests for config generation**

File: `tests/ai/tool_defaults_integration_spec.lua` (NEW)

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Backward incompatibility | High | All new APIs return nil/fallback when tool_defaults absent |
| UI flow complexity | Medium | "Auto-recommend" option reduces friction |
| Model profile coverage | Medium | Multi-level fallback in `get_model_profile` |
| Serialization bugs | Medium | Explicit test coverage |

## Success Criteria

- [ ] `Keys.get_tool_default()` / `set_tool_default()` work correctly
- [ ] Model Switch shows target selection
- [ ] Auto-recommend fills all model slots
- [ ] Claude Code settings show correct multi-model env vars
- [ ] OpenCode config uses tool-specific models
- [ ] Backward compatible with existing configs

## Estimated Effort

~750 lines of changes across 7-8 files (2 new modules, 5-6 modified).
