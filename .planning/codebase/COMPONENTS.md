# Component Map

## Active Components

### ECC (Everything Claude Code)
- **Type**: Framework
- **Install**: `git clone` + `npm install`
- **Cache**: Not yet implemented (uses temp `/tmp/ecc-install`)
- **Deploy**: Direct copy to `~/.claude/` via `install-apply.js`
- **Targets**: Claude Code, OpenCode
- **Status**: ✅ Installed and working
- **Shim**: `lua/ai/ecc.lua` → `lua/ai/components/ecc/`

### GSD (Get Shit Done)
- **Type**: Framework
- **Install**: `npx get-shit-done-cc@latest`
- **Cache**: Not yet implemented
- **Deploy**: Direct write via npx installer
- **Targets**: Claude Code, OpenCode, Gemini, Cursor, Codex, Windsurf
- **Status**: ⚠️ Detection works, but deployment broken (config generator ignores switcher)
- **Shim**: `lua/ai/gsd.lua` → `lua/ai/components/gsd/`

## Component Manager State
- Registry: ✅ Working
- Discovery: ✅ Working (2 components found)
- Picker UI: ✅ Working (fzf-lua)
- Switcher: ✅ Working (state file written)
- **Integration: ❌ NOT WORKING** — `opencode.lua` and `claude_code.lua` ignore switcher state
- Cache+Deploy architecture: ❌ Not implemented

## Critical Bugs
1. `opencode.lua:520` — calls non-existent `Ecc.ensure_installed()`
2. `opencode.lua:453-516` — dead code block
3. Config generator hardcodes ECC, ignores switcher
4. ECC uninstaller deletes ALL content in `~/.claude/commands/` etc.
