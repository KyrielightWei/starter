# Skill Studio Enhancement - TODO

> Track implementation progress. Update status as work progresses.

**Status Legend:** `[ ]` Pending | `[~]` In Progress | `[x]` Done | `[-]` Skipped

---

## Phase 1: Core Data Structures

**File:** `lua/ai/skill_studio/registry.lua`

- [x] Create `registry.lua` file
- [x] Implement `paths` configuration (base, requirements, generated, index)
- [x] Implement `sync_targets` configuration (project, global)
- [x] Implement `load_index()` function
- [x] Implement `save_index(index)` function
- [x] Implement `get_requirement(name)` function
- [x] Implement `set_requirement(name, data)` function
- [x] Implement `list_requirements()` function
- [x] Implement `enable_sync(name, target)` function
- [x] Implement `disable_sync(name)` function
- [x] Implement `sync_to_target(name)` function
- [x] Add error handling for file operations
- [x] Add scan functions for deployed content

**Status:** `[x] Completed`

---

## Phase 2: Requirement Templates

**File:** `lua/ai/skill_studio/templates.lua`

- [x] Create `templates.lua` file
- [x] Define Skill requirement template structure
- [x] Define Rule requirement template structure
- [x] Define Command requirement template structure
- [x] Define MCP requirement template structure
- [x] Implement `get_template(type, target)` function
- [x] Implement `validate_requirement(requirement)` function
- [x] Implement `format_requirement_markdown(requirement)` function
- [x] Implement `parse_requirement_markdown(content)` function
- [x] Add template documentation

**Status:** `[x] Completed`

---

## Phase 3: AI Generator

**File:** `lua/ai/skill_studio/generator.lua`

- [x] Create `generator.lua` file
- [x] Implement `generate(name, opts)` main function
- [x] Implement `build_prompt(requirement)` function
- [x] Implement `call_avante(prompt)` function
- [x] Implement `call_opencode(prompt)` function
- [x] Implement `call_claude_code(prompt)` function
- [x] Implement `call_ai(prompt, backend)` dispatcher
- [x] Implement `save_generated(name, content, target)` function
- [x] Implement `validate_generated(content)` function
- [x] Implement `test_generated_skill(skill)` function
- [x] Add progress notification during generation
- [x] Add error handling for AI calls

**Status:** `[x] Completed`

---

## Phase 4: Requirement Extractor

**File:** `lua/ai/skill_studio/extractor.lua`

- [x] Create `extractor.lua` file
- [x] Implement `extract_from_skill(skill_path)` function
- [x] Implement `extract_from_rule(rule_path)` function
- [x] Implement `extract_from_mcp(mcp_path)` function
- [x] Implement `parse_skill_content(content)` helper
- [x] Implement `parse_rule_content(content)` helper
- [x] Implement `parse_mcp_config(config)` helper
- [x] Implement `to_requirement(parsed, type)` conversion
- [x] Add validation of extracted requirements

**Status:** `[x] Completed`

---

## Phase 5: FZF Pickers

**File:** `lua/ai/skill_studio/picker.lua`

- [x] Create `picker.lua` file
- [x] Implement `open_requirements_picker()` function
- [x] Implement requirements list formatting with status icons
- [x] Implement `<CR>` edit action
- [x] Implement `<C-s>` toggle sync action
- [x] Implement `<C-g>` generate action
- [x] Implement `<C-d>` deploy action
- [x] Implement `<C-v>` view generated action
- [x] Implement `<C-x>` delete action
- [x] Implement `open_deployed_picker()` function
- [x] Implement `scan_claude_skills()` function (in registry.lua)
- [x] Implement `scan_claude_rules()` function (in registry.lua)
- [x] Implement `scan_claude_mcps()` function (in registry.lua)
- [x] Implement `scan_opencode_agents()` function (in registry.lua)
- [x] Implement deployed list formatting
- [x] Add help screen (`<C-?>`)

**Status:** `[x] Completed`

---

## Phase 6: Rule Support

**Files:** `lua/ai/skill_studio/templates.lua`, `validator.lua`

- [x] Add Rule templates to `templates.lua`
- [x] Add Rule validation to `validator.lua`
- [x] Update `init.lua` deploy function for Rules
- [x] Test Rule generation and deployment

**Status:** `[x] Completed`

---

## Phase 7: User Commands

**File:** `lua/ai/skill_studio/init.lua`

- [x] Implement `:SkillRequirements` command
- [x] Implement `:SkillDeployed` command
- [x] Implement `:SkillNewRequirement` command
- [x] Implement `:SkillGenerate <name> [target]` command
- [x] Implement `:SkillSync <name> <target>` command
- [x] Implement `:SkillUnsync <name>` command
- [x] Implement `:SkillExtract <path>` command
- [x] Add command completions
- [x] Add command documentation

**Status:** `[x] Completed`

---

## Phase 8: Integration & Testing

- [x] Integrate all modules in `init.lua`
- [x] Update `setup()` function
- [ ] Test requirement creation flow
- [ ] Test AI generation flow
- [ ] Test sync/deploy flow
- [ ] Test extraction flow
- [ ] Test picker UI
- [ ] Add edge case handling
- [ ] Performance testing with many requirements

**Status:** `[~] In Progress`

---

## Phase 9: Documentation

- [x] Update `docs/skill-studio.md`
- [x] Add requirement template examples
- [x] Add usage examples
- [ ] Add troubleshooting guide
- [ ] Update `docs/README.md` if needed

**Status:** `[~] In Progress`

---

## Progress Summary

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 1: Core Data Structures | Completed | 100% |
| Phase 2: Requirement Templates | Completed | 100% |
| Phase 3: AI Generator | Completed | 100% |
| Phase 4: Requirement Extractor | Completed | 100% |
| Phase 5: FZF Pickers | Completed | 100% |
| Phase 6: Rule Support | Completed | 100% |
| Phase 7: User Commands | Completed | 100% |
| Phase 8: Integration & Testing | In Progress | 25% |
| Phase 9: Documentation | In Progress | 60% |

**Overall Progress:** 87%

---

## Notes

### 2026-03-30
- Initial plan created
- Plan document: `docs/skill-studio-plan.md`
- TODO document created
- **Implementation completed:**
  - Phase 1-7 全部完成
  - 新增文件：
    - `lua/ai/skill_studio/registry.lua` - 需求注册表管理
    - `lua/ai/skill_studio/templates.lua` - 需求模板定义
    - `lua/ai/skill_studio/generator.lua` - AI 生成模块
    - `lua/ai/skill_studio/extractor.lua` - 需求提取模块
    - `lua/ai/skill_studio/picker.lua` - FZF Pickers
  - 更新文件：
    - `lua/ai/skill_studio/validator.lua` - 添加 Rule 验证支持
    - `lua/ai/skill_studio/init.lua` - 添加新命令
    - `docs/skill-studio.md` - 更新文档

### 技术注意事项
- `validator.lua` 使用 `goto` 语法（LuaJIT 支持，Lua 5.1 不支持）
- 所有模块语法已通过 `luac -p` 验证
- Neovim 环境下可直接使用