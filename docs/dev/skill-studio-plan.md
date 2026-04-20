# Skill Studio Enhancement Plan

> AI-Powered Skill/Rule/MCP Generation and Management System

## Overview

Enhance Skill Studio with AI-powered generation capabilities, local requirements management, sync to Git-trackable directories, and FZF pickers for visualization.

---

## Requirements Summary

1. **AI Generation**: Generate skills/rules/mcps from requirement templates via Avante/OpenCode/Claude Code
2. **Detailed Templates**: Ensure generated content works on first try
3. **Rule Support**: Extend support for Rules (coding standards, workflows)
4. **Requirement Extraction**: Extract requirements from existing skills
5. **Local Management**:
   - Requirements stored locally by default
   - Select which requirements sync to config directories
   - Git-syncable via config subdirectory
   - Support disable sync
6. **FZF Pickers**:
   - View all requirements, sync status, Claude/OpenCode versions
   - View deployed skills/rules/mcps

---

## Architecture

### Directory Structure

```
~/.local/state/nvim/skill_studio/
├── requirements/              # Requirement storage (local)
│   ├── my-skill.req.md       # Requirement files
│   └── ...
├── generated/                 # Generated skills/rules/mcps
│   ├── claude/               # Claude Code versions
│   │   ├── skills/
│   │   ├── rules/
│   │   └── mcps/
│   └── opencode/             # OpenCode versions
│       ├── agents/
│       └── ...
└── index.json                # Index: requirement status, sync config

# Project-level sync directory (optional)
<project>/.claude/skills/      # Sync to project
~/.claude/skills/              # Sync to global
```

### Index Structure

```json
{
  "requirements": {
    "my-skill": {
      "file": "requirements/my-skill.req.md",
      "type": "skill",
      "created_at": "2026-03-30T10:00:00",
      "updated_at": "2026-03-30T11:00:00",
      "sync": {
        "enabled": true,
        "target": "project",
        "path": ".claude/skills/my-skill"
      },
      "versions": {
        "claude": {
          "generated": true,
          "path": "generated/claude/skills/my-skill/SKILL.md",
          "deployed": true,
          "last_validated": "2026-03-30T11:00:00"
        },
        "opencode": {
          "generated": false,
          "path": null,
          "deployed": false
        }
      }
    }
  }
}
```

---

## Implementation Phases

### Phase 1: Core Data Structures

**File:** `lua/ai/skill_studio/registry.lua`

Functions:
- `load_index()` / `save_index(index)`
- `get_requirement(name)` / `set_requirement(name, data)`
- `list_requirements()`
- `enable_sync(name, target)` / `disable_sync(name)`
- `sync_to_target(name)`

### Phase 2: Requirement Templates

**File:** `lua/ai/skill_studio/templates.lua`

Define detailed requirement templates for:
- Skills
- Rules
- Commands
- MCPs

### Phase 3: AI Generator

**File:** `lua/ai/skill_studio/generator.lua`

Functions:
- `generate(name, opts)` - Generate from requirement
- `call_ai(prompt, backend)` - Call Avante/OpenCode/Claude Code
- `build_prompt(requirement)` - Build AI prompt from requirement
- `save_generated(name, content, target)` - Save generated content

### Phase 4: Requirement Extractor

**File:** `lua/ai/skill_studio/extractor.lua`

Functions:
- `extract_from_skill(skill_path)`
- `extract_from_rule(rule_path)`
- `extract_from_mcp(mcp_path)`
- `to_requirement(parsed)` - Convert parsed content to requirement

### Phase 5: FZF Pickers

**File:** `lua/ai/skill_studio/picker.lua`

Functions:
- `open_requirements_picker()` - List all requirements
- `open_deployed_picker()` - List deployed skills/rules/mcps
- `scan_claude_skills()` / `scan_claude_rules()` / `scan_claude_mcps()`
- `scan_opencode_agents()`

### Phase 6: Rule Support

Extend templates and validators for Rules.

### Phase 7: User Commands

| Command | Description |
|---------|-------------|
| `:SkillRequirements` | Open requirements picker |
| `:SkillDeployed` | View deployed skills/rules/mcps |
| `:SkillNewRequirement` | Create new requirement |
| `:SkillGenerate <name> [target]` | Generate from requirement |
| `:SkillSync <name> <target>` | Set sync target |
| `:SkillUnsync <name>` | Disable sync |
| `:SkillExtract <path>` | Extract requirement from existing file |

---

## UI Design

### Requirements Picker

```
╔══════════════════════════════════════════════════════════════════╗
║  Skill Studio - Requirements                    <C-?> for help   ║
╠══════════════════════════════════════════════════════════════════╣
║  [✓] my-skill (skill) [Claude:✓] [OpenCode:✗]                    ║
║  [✗] code-reviewer (skill) [Claude:✓] [OpenCode:✓]               ║
║  [✓] coding-standards (rule) [Claude:✓] [OpenCode:✗]             ║
║  [✓] filesystem (mcp) [Claude:✓] [OpenCode:N/A]                  ║
╠══════════════════════════════════════════════════════════════════╣
║  Actions: <CR>编辑 <C-s>同步 <C-g>生成 <C-d>部署 <C-x>删除       ║
╚══════════════════════════════════════════════════════════════════╝
```

### Deployed Picker

```
╔══════════════════════════════════════════════════════════════════╗
║  Skill Studio - Deployed Skills                 <C-?> for help  ║
╠══════════════════════════════════════════════════════════════════╣
║  [Claude/Project] skill: my-skill                                 ║
║  [Claude/Project] rule: coding-standards                          ║
║  [Claude/Global] mcp: filesystem                                  ║
║  [OpenCode/Project] agent: code-reviewer                          ║
╠══════════════════════════════════════════════════════════════════╣
║  Actions: <CR>查看 <C-e>编辑 <C-r>重新生成 <C-u>更新需求          ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Sync Flow

```
Requirement File (requirements/my-skill.req.md)
    ↓ generate
generated/claude/skills/my-skill/SKILL.md
generated/opencode/agents/my-skill.md
    ↓ deploy (if sync enabled)
[Project] .claude/skills/my-skill/SKILL.md
[Global] ~/.claude/skills/my-skill/SKILL.md
```

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lua/ai/skill_studio/registry.lua` | Create | Requirement registry and index management |
| `lua/ai/skill_studio/templates.lua` | Create | Requirement template definitions |
| `lua/ai/skill_studio/generator.lua` | Create | AI generation module |
| `lua/ai/skill_studio/extractor.lua` | Create | Requirement extraction module |
| `lua/ai/skill_studio/picker.lua` | Create | FZF pickers |
| `lua/ai/skill_studio/init.lua` | Modify | Add new commands |
| `lua/ai/skill_studio/validator.lua` | Modify | Add Rule validation |
| `docs/skill-studio.md` | Modify | Update documentation |

---

## Dependencies

| Dependency | Usage |
|------------|-------|
| Avante module | AI generation (optional) |
| Terminal module | Call OpenCode/Claude Code |
| Context module | Gather project context |
| Validator module | Validate generated content |
| FZF Lua | Picker UI |

---

## Risks

| Risk | Level | Mitigation |
|------|-------|------------|
| AI generates unusable content | MEDIUM | Detailed templates + validation + testing |
| Incomplete requirement extraction | LOW | AI-assisted extraction + manual confirmation |
| Rule format compatibility | LOW | Follow Claude Code official docs |
| Complex MCP configuration | MEDIUM | Multiple templates + validation tools |

---

## Estimated Effort: 17-25 hours

| Phase | Time |
|-------|------|
| Phase 1: Core Data Structures | 3-4h |
| Phase 2: Requirement Templates | 2-3h |
| Phase 3: AI Generator | 3-4h |
| Phase 4: Requirement Extractor | 2-3h |
| Phase 5: FZF Pickers | 3-4h |
| Phase 6: Rule Support | 1-2h |
| Phase 7: Commands | 1-2h |
| Testing & Docs | 2-3h |