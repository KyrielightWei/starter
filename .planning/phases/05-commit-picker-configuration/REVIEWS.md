# Phase 05 — Commit Picker Configuration: Cross-AI Peer Review

**Reviewer:** Claude Code (internal review)
**Plan reviewed:** `05-PLAN.md`
**Date:** 2026-04-26
**Verdict:** CONDITIONALLY APPROVE

---

## Summary

The plan is well-structured with clear wave boundaries, covers both CDRV-03 and CDRV-04, and correctly identifies key technical patterns from Phase 4 and Provider Manager. Three HIGH severity issues must be addressed before execution. Several MEDIUM issues should be resolved to prevent implementation friction.

---

## Issues

### HIGH-01: Atomic Write Pattern Has Logic Bug

**Location:** 05-PLAN.md:224-240 (Implementation Notes > File Atomic Write Pattern)

**What's wrong:** The `atomic_write` function uses `os.rename()` which returns `nil` on success but the code checks `if not ok then` — in Lua, `nil` is falsy, so this check would *always* trigger the error path even on successful rename. The pattern should check `if ok == nil and err == nil` or `if ok ~= nil` (truthy), similar to how `file_util.lua:34-35` handles `vim.uv.fs_rename`.

Additionally, the plan's `atomic_write` does not handle the case where `os.rename` fails on different filesystems (cross-device), which `file_util.safe_write_file` handles with a fallback chain (uv.fs_rename → os.rename → direct write).

**Why it matters:** Config saves would silently fail, leaving users thinking changes persisted when they didn't. The `.tmp` file would remain orphaned.

**Suggested fix:** Reuse `file_util.safe_write_file` from `ai.provider_manager` instead of writing a new `atomic_write`. The existing function is battle-tested with the rename fallback chain. If the plan insists on a local version, fix the truthiness check:
```lua
local ok, err = os.rename(tmp_path, path)
if ok ~= nil then  -- Note: os.rename returns nil on success, error string on failure
  -- success path
end
```

---

### HIGH-02: Safe Config Parsing Approach Contradicts Itself

**Location:** 05-PLAN.md:62-65 (Wave 1 > Safe config parsing) vs 05-PLAN.md:213-220 (Implementation Notes)

**What's wrong:** The plan has contradictory guidance in the same file:
- Wave 1 Task 5 says: "Use `loadstring()` in a sandboxed environment or manual key extraction"
- Implementation Notes say: "Do NOT use `dofile()` or `loadstring()` directly on config file"

Lua 5.1 (Neovim's embedded Lua) does **not** support environment sandboxing for `loadstring()`. There is no safe sandbox in Lua 5.1 — `loadstring()` always has access to the full environment. This makes Wave 1 Task 5's suggestion technically infeasible.

The existing `file_util.read_lua_table` uses `dofile()` with path validation (checking file is within `ai/` directory). For the new commit_picker config at `~/.config/nvim/commit_picker_config.lua`, this path check needs to be adapted — but the pattern of "trust user-owned config files, parse with dofile in protected call" is appropriate here.

**Why it matters:** If implementors follow the `loadstring()` suggestion, they might introduce a security vulnerability or write a broken parser. If they follow the manual parsing guidance, it's unnecessarily complex for user-owned config files.

**Suggested fix:** Use `pcall(dofile, path)` + field validation, consistent with `file_util.read_lua_table`. For user-owned config files (`~/.config/nvim/`), this is the appropriate trust boundary. Add a secondary safety net of validating every field against the schema after parsing:
```lua
local raw = pcall(dofile, path)
local config = {}
config.mode = type(raw.mode) == "string" and raw.mode or "unpushed"
config.count = type(raw.count) == "number" and raw.count or 20
config.base_commit = (type(raw.base_commit) == "string" and raw.base_commit:match("^%x+$")) or nil
```

---

### HIGH-03: Validator Reuse from Provider Manager is a Mismatch

**Location:** 05-PLAN.md:117-119 (Wave 2 > File structure)

**What's wrong:** The plan suggests `local Validator = require("ai.provider_manager.validator")` for use in commit_picker config validation. Looking at the actual `validator.lua`, it only exports `validate_provider_name()` — a function specifically for validating that a provider name is kebab-case and unique in the registry. This is completely unrelated to validating `{ mode, count, base_commit }` config values.

**Why it matters:** Importing a module that exposes no useful functions wastes a require and creates a misleading dependency. It also tightens coupling between commit_picker and provider_manager for zero benefit.

**Suggested fix:** Build config validation inline in `config.lua`. The schema is simple enough (3 fields, basic type checks, enumerate mode):
- `mode`: `vim.tbl_contains({ "unpushed", "last_n", "since_base" }, config.mode)`
- `count`: `type(config.count) == "number" and config.count > 0`
- `base_commit`: nil or `config.base_commit:match("^%x%x%x%x%x%x%x[%x]*$")` (7-40 hex chars)

---

### MEDIUM-01: Base Commit SHA Validity Not Verified Against Git History

**Location:** 05-PLAN.md:44 (Wave 1 > validate_config), 05-PLAN.md:176 (Threat Model T-05-03)

**What's wrong:** The plan validates `base_commit` as "7-40 hex chars" but doesn't verify that the SHA actually exists in the repository's git history. A valid-format SHA from a different repo, or one that was garbage-collected or force-pushed away, would pass validation but cause git commands to fail.

**Why it matters:** After a `git rebase --force` or `git gc`, the stored base_commit could become a dangling SHA. The fallback logic handles this at runtime, but validation would fail to catch the issue proactively.

**Suggested fix:** Add optional runtime validation: in `validate_config()`, if `base_commit` is set, run `git cat-file -t <sha>` to verify it resolves to a `commit` object. This is a cheap operation (< 100ms) and provides early warning. Or alternatively, document that validation only checks format, and rely on the fallback chain for runtime validation.

---

### MEDIUM-02: No Test Infrastructure Referenced

**Location:** 05-PLAN.md (entire file)

**What's wrong:** The plan has no mention of tests. Phase 4 also lacked tests (verified: no `tests/commit_picker/` directory exists), but Wave 1's verification steps ("Module loads without errors", "get_config returns defaults") are essentially test cases that could be formalized as `plenary.nvim` specs.

**Why it matters:** Without tests, regression risk is high — especially since Wave 3 modifies three existing files that Phase 4 built carefully with prior review fixes.

**Suggested fix:** Add a lightweight Wave 1.5 or append to Wave 1: create `tests/commit_picker/config_spec.lua` with specs for:
- `get_config()` returns defaults when file missing
- `save_config()` writes parseable file
- `validate_config()` rejects invalid mode, negative count, non-hex SHA
- `reset_to_defaults()` writes known-good config

---

### MEDIUM-03: init.lua Calls Wrong Submodule Path in ai/init.lua

**Location:** 05-PLAN.md:152-155 (Wave 3 > Keymap registration)

**What's wrong:** The plan says "Check existing keymaps: commit picker is `<leader>kC`" and proposes adding `:AICommitConfig`. But looking at `lua/ai/init.lua:118-121`, the existing keymap uses `pcall(require, "commit_picker.init")` — not `require("commit_picker")`. The plan should clarify whether `:AICommitConfig` is registered in `commit_picker/init.lua`'s `setup()` (which already exists) OR in `lua/ai/init.lua`'s commands table.

**Why it matters:** Inconsistent registration location creates confusion. If registered in `commit_picker/init.lua`, it works because `ai/init.lua:219-222` calls `CommitPicker.setup()`. If registered in `ai/init.lua`, it needs the commands table updated.

**Suggested fix:** Explicitly state that `:AICommitConfig` should be added to `commit_picker/init.lua:setup()` alongside the existing `:AICommitPicker` registration. This is consistent with the plan's Wave 3 Task 2 item ("Add `:AICommitConfig` user command in `setup()`"). Document that no change to `ai/init.lua` is needed for the command.

---

### MEDIUM-04: Mode Routing Code Has Hardcoded Chinese String

**Location:** 05-PLAN.md:244-269 (Implementation Notes > Mode Routing Logic)

**What's wrong:** The fallback messages in the example code use hardcoded Chinese strings:
- `"未找到远程或未推送的提交，回退到最近 " .. config.count .. " 条"`
- `"基础提交不可用，回退到最近 " .. config.count .. " 条"`

Phase 4 init.lua already uses this pattern (line 65: `"获取未推送提交失败: "`) and the project convention is Chinese error messages (per AGENTS.md). However, the plan should note that the count in the message should be `config.count` not hardcoded `20`, and should match the exact format convention from Phase 4.

Also, the fallback message in Phase 4 includes ahead/behind counts when available (line 76: `"没有未推送的提交 (ahead %d, behind %d)"`). The plan's unpushed fallback should similarly include this diagnostic info.

**Why it matters:** Inconsistent message formatting creates a jarring user experience. Missing ahead/behind counts reduce debuggability.

**Suggested fix:** In Wave 3 Task 1, include ahead/behind info in the unpushed fallback message:
```lua
local ab = Git.get_ahead_behind()
vim.notify(string.format("未找到远程提交 (ahead %d, behind %d)，回退到最近 %d 条",
  ab.ahead, ab.behind, config.count), vim.log.levels.WARN)
```

---

### LOW-01: Cache MTIME Detection Not Fully Specified

**Location:** 05-PLAN.md:59 (Wave 1 > Cache behavior)

**What's wrong:** "Cache keyed by file mtime for automatic staleness detection" — the plan doesn't explain how mtime is obtained or compared in Lua. `vim.loop.fs_stat()` returns mtime as `{ sec, nsec }` table, which requires a specific access pattern.

**Why it matters:** Implementor may use incorrect mtime access (`stat.mtime` vs `stat.mtime.sec`) leading to cache never invalidating.

**Suggested fix:** Provide the mtime check snippet:
```lua
local stat = vim.loop.fs_stat(path)
if stat and cached_mtime and stat.mtime.sec == cached_mtime.sec then
  return cached_config
end
```

---

### LOW-02: display.lua Base Commit Highlighting Not Fully Specified

**Location:** 05-PLAN.md:147-150 (Wave 3 > Modify display.lua)

**What's wrong:** "Highlight the base commit line with different color or prefix marker" — the plan shows `★ base | abc1234 feat: ...` but doesn't specify how display.lua would receive the `base_commit` parameter. Currently, `display.show_picker()` accepts `(commits, opts)` where `opts` contains `{ on_select }`, but there's no mechanism to pass a `base_commit` for highlighting.

**Why it matters:** The display.lua integration needs a clear interface for receiving and processing the base commit for visual differentiation.

**Suggested fix:** Specify that `opts` gains a new field `opts.base_commit` (full SHA string), and display.lua iterates commits to find the matching one, prefixing its display line with the marker and different ANSI color.

---

### LOW-03: Config File Location Not in XDG Conventions

**Location:** 05-PLAN.md:28-29, 05-PLAN.md:43

**What's wrong:** Config path is `~/.config/nvim/commit_picker_config.lua`, which matches the existing pattern from `ai_keys.lua` and `opencode.template.jsonc`. However, the project uses XDG paths for some configs (e.g., `~/.config/opencode/api_key_{provider}.txt`). This isn't wrong per se, but should be noted as a deliberate choice to keep all nvim configs together.

**Why it matters:** Minor — just ensuring consistency with the decision documented in 05-CONTEXT.md ("New dedicated config file, separate from ai_keys.lua").

**Suggested fix:** No change needed — the path is consistent with 05-CONTEXT.md decisions and existing project conventions. Just document the rationale: "Follows the nvim-internal config convention (~/.config/nvim/) for user-facing Lua config files."

---

### INFO-01: Scope Boundary Assessment

**Location:** Phase 5 overall vs Phase 6 requirements (ROADMAP.md:146-159)

**Assessment:** Phase 5 does not encroach on Phase 6 territory. Phase 6 (CDRV-05, CDRV-06) is about *navigating between commits during diff review* — selecting one commit to view its diff, or selecting two commits to view the diff between them. Phase 5's `get_commit_range()` returns git args to *fetch* commits, not to *navigate* between them during review. The scope boundary is clean.

---

### INFO-02: Wave Ordering is Sensible

**Assessment:** The wave decomposition (Config → UI → Integration) follows the correct dependency chain. Wave 3 correctly depends on Wave 1 (config module must exist for git.lua to read it) and Wave 2 (settings UI doesn't block integration but is in Wave 2 for parallelism). The verification steps per wave are adequate for unit-level checks but would benefit from an E2E test.

---

## Issue Summary Table

| ID | Severity | Category | Wave/Section | Status |
|----|----------|----------|--------------|--------|
| HIGH-01 | HIGH | Correctness | Wave 1 (atomic write) | Must fix before execute |
| HIGH-02 | HIGH | Correctness | Wave 1 (config parsing) | Must fix before execute |
| HIGH-03 | HIGH | Dependencies | Wave 2 (file structure) | Must fix before execute |
| MED-01 | MEDIUM | Risks | Wave 1 (validation) | Should fix |
| MED-02 | MEDIUM | Quality | Entire plan | Should fix |
| MED-03 | MEDIUM | Consistency | Wave 3 (keymap reg) | Should fix |
| MED-04 | MEDIUM | Consistency | Wave 3 (fallback msgs) | Should fix |
| LOW-01 | LOW | Completeness | Wave 1 (cache) | Nice to fix |
| LOW-02 | LOW | Completeness | Wave 3 (display.lua) | Nice to fix |
| LOW-03 | INFO | Consistency | Config path | No action needed |
| INFO-01 | INFO | Scope | Phase 5 vs 6 | No action needed |
| INFO-02 | INFO | Quality | Wave ordering | No action needed |

---

## Overall Verification

### Completeness: PASS
- CDRV-03 (configure count): Covered in Waves 1-3
- CDRV-04 (base commit): Covered in Waves 1-3
- Scope presets (unpushed/last N/since base): Covered in config schema and mode routing

### Correctness: CONDITIONAL
- Technical approach is sound EXCEPT for HIGH-01 (atomic write bug), HIGH-02 (loadstring sandbox), HIGH-03 (validator mismatch)

### Dependencies: CONDITIONAL
- Phase 4 module references are correct (git.lua, init.lua, display.lua)
- MISSING: No mention of `selection.lua` — Phase 5 doesn't need to modify it, which is correct
- HIGH-03: Validator reuse is incorrect

### Quality: PASS
- Waves are well-scoped with clear boundaries
- Verification steps per wave are functional
- Would benefit from formal test specs (MED-02)

### Risks: PARTIAL
- Fallback chains are well-specified
- Threat model covers 6 threats (T-05-01 through T-05-06) — adequate
- Missing: SHA validity after gc/rebase (MED-01)

### Consistency: CONDITIONAL
- Error message language (Chinese): Consistent ✓
- Module naming (commit_picker.config): Consistent ✓
- Config file format (Lua table return): Consistent ✓
- Atomic write pattern: Bug in proposed code (HIGH-01)
- Validator reuse: Doesn't match actual module (HIGH-03)

### Scope creep: PASS
- Phase 5 boundaries are clean — no Phase 6 functionality included

---

## Verdict: CONDITIONALLY APPROVE

The plan is well-designed and covers both required user stories (CDRV-03, CDRV-04). The wave decomposition is logical, the threat model is thorough, and integration with Phase 4 modules is correctly understood.

**Blockers before execution (3 HIGH issues):**
1. Fix atomic write logic — the `os.rename()` truthiness check is backwards
2. Resolve config parsing contradiction — use `pcall(dofile)` + validation, not `loadstring()` sandbox
3. Remove validator reuse suggestion — build config validation inline

**Recommended improvements (4 MEDIUM issues):**
- Add lightweight test specs for config module
- Clarify `:AICommitConfig` registration location
- Consistently include ahead/behind info in fallback messages
- Optionally verify base_commit SHA against git history

---

*Review completed by Claude Code, 2026-04-26*
