# Skill Studio Enhancement - TODO

> Track implementation progress. Update status as work progresses.

**Status Legend:** `[ ]` Pending | `[~]` In Progress | `[x]` Done | `[-]` Skipped

---

## Phase 1: Core Data Structures

**File:** `lua/ai/skill_studio/registry.lua`

- [ ] Create `registry.lua` file
- [ ] Implement `paths` configuration (base, requirements, generated, index)
- [ ] Implement `sync_targets` configuration (project, global)
- [ ] Implement `load_index()` function
- [ ] Implement `save_index(index)` function
- [ ] Implement `get_requirement(name)` function
- [ ] Implement `set_requirement(name, data)` function
- [ ] Implement `list_requirements()` function
- [ ] Implement `enable_sync(name, target)` function
- [ ] Implement `disable_sync(name)` function
- [ ] Implement `sync_to_target(name)` function
- [ ] Add error handling for file operations
- [ ] Add unit tests

**Status:** `[ ] Not Started`

---

## Phase 2: Requirement Templates

**File:** `lua/ai/skill_studio/templates.lua`

- [ ] Create `templates.lua` file
- [ ] Define Skill requirement template structure
- [ ] Define Rule requirement template structure
- [ ] Define Command requirement template structure
- [ ] Define MCP requirement template structure
- [ ] Implement `get_template(type, target)` function
- [ ] Implement `validate_requirement(requirement)` function
- [ ] Implement `format_requirement_markdown(requirement)` function
- [ ] Implement `parse_requirement_markdown(content)` function
- [ ] Add template documentation

**Status:** `[ ] Not Started`

---

## Phase 3: AI Generator

**File:** `lua/ai/skill_studio/generator.lua`

- [ ] Create `generator.lua` file
- [ ] Implement `generate(name, opts)` main function
- [ ] Implement `build_prompt(requirement)` function
- [ ] Implement `call_avante(prompt)` function
- [ ] Implement `call_opencode(prompt)` function
- [ ] Implement `call_claude_code(prompt)` function
- [ ] Implement `call_ai(prompt, backend)` dispatcher
- [ ] Implement `save_generated(name, content, target)` function
- [ ] Implement `validate_generated(content)` function
- [ ] Implement `test_generated_skill(skill)` function
- [ ] Add progress notification during generation
- [ ] Add error handling for AI calls

**Status:** `[ ] Not Started`

---

## Phase 4: Requirement Extractor

**File:** `lua/ai/skill_studio/extractor.lua`

- [ ] Create `extractor.lua` file
- [ ] Implement `extract_from_skill(skill_path)` function
- [ ] Implement `extract_from_rule(rule_path)` function
- [ ] Implement `extract_from_mcp(mcp_path)` function
- [ ] Implement `parse_skill_content(content)` helper
- [ ] Implement `parse_rule_content(content)` helper
- [ ] Implement `parse_mcp_config(config)` helper
- [ ] Implement `to_requirement(parsed, type)` conversion
- [ ] Add validation of extracted requirements

**Status:** `[ ] Not Started`

---

## Phase 5: FZF Pickers

**File:** `lua/ai/skill_studio/picker.lua`

- [ ] Create `picker.lua` file
- [ ] Implement `open_requirements_picker()` function
- [ ] Implement requirements list formatting with status icons
- [ ] Implement `<CR>` edit action
- [ ] Implement `<C-s>` toggle sync action
- [ ] Implement `<C-g>` generate action
- [ ] Implement `<C-d>` deploy action
- [ ] Implement `<C-v>` view generated action
- [ ] Implement `<C-x>` delete action
- [ ] Implement `open_deployed_picker()` function
- [ ] Implement `scan_claude_skills()` function
- [ ] Implement `scan_claude_rules()` function
- [ ] Implement `scan_claude_mcps()` function
- [ ] Implement `scan_opencode_agents()` function
- [ ] Implement deployed list formatting
- [ ] Add help screen (`<C-?>`)

**Status:** `[ ] Not Started`

---

## Phase 6: Rule Support

**Files:** `lua/ai/skill_studio/templates.lua`, `validator.lua`

- [ ] Add Rule templates to `templates.lua`
- [ ] Add Rule validation to `validator.lua`
- [ ] Update `init.lua` deploy function for Rules
- [ ] Test Rule generation and deployment

**Status:** `[ ] Not Started`

---

## Phase 7: User Commands

**File:** `lua/ai/skill_studio/init.lua`

- [ ] Implement `:SkillRequirements` command
- [ ] Implement `:SkillDeployed` command
- [ ] Implement `:SkillNewRequirement` command
- [ ] Implement `:SkillGenerate <name> [target]` command
- [ ] Implement `:SkillSync <name> <target>` command
- [ ] Implement `:SkillUnsync <name>` command
- [ ] Implement `:SkillExtract <path>` command
- [ ] Add command completions
- [ ] Add command documentation

**Status:** `[ ] Not Started`

---

## Phase 8: Integration & Testing

- [ ] Integrate all modules in `init.lua`
- [ ] Update `setup()` function
- [ ] Test requirement creation flow
- [ ] Test AI generation flow
- [ ] Test sync/deploy flow
- [ ] Test extraction flow
- [ ] Test picker UI
- [ ] Add edge case handling
- [ ] Performance testing with many requirements

**Status:** `[ ] Not Started`

---

## Phase 9: Documentation

- [ ] Update `docs/skill-studio.md`
- [ ] Add requirement template examples
- [ ] Add usage examples
- [ ] Add troubleshooting guide
- [ ] Update `docs/README.md` if needed

**Status:** `[ ] Not Started`

---

## Progress Summary

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 1: Core Data Structures | Not Started | 0% |
| Phase 2: Requirement Templates | Not Started | 0% |
| Phase 3: AI Generator | Not Started | 0% |
| Phase 4: Requirement Extractor | Not Started | 0% |
| Phase 5: FZF Pickers | Not Started | 0% |
| Phase 6: Rule Support | Not Started | 0% |
| Phase 7: User Commands | Not Started | 0% |
| Phase 8: Integration & Testing | Not Started | 0% |
| Phase 9: Documentation | Not Started | 0% |

**Overall Progress:** 0%

---

## Notes

<!-- Add implementation notes here as work progresses -->

### 2026-03-30
- Initial plan created
- Plan document: `docs/skill-studio-plan.md`
- TODO document created