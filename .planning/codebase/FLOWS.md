# Flows — Key Data Flows and Interactions

**Project:** LazyVim Neovim Configuration with AI Integration
**Mapped:** 2026-04-21

## Flow 1: AI Module Bootstrap

```
Neovim starts
  │
  ▼
init.lua sources lua/config/lazy.lua
  │
  ▼
Lazy.nvim scans lua/plugins/*.lua
  │
  ├─ plugins/ai.lua → loads avante.nvim (VeryLazy)
  │                      └─ config: require("ai").setup()
  │
  ├─ plugins/opencode.lua → registers user commands
  │                           (OpenCodeGenerateConfig, ClaudeCodeGenerateConfig, etc.)
  │                           schedules config_watcher.watch()
  │
  └─ plugins/terminal.lua → configures toggleterm + registers keymaps
```

**Trigger chain:**
1. `plugins/ai.lua` fires on `VeryLazy` event
2. Calls `require("ai").setup()` in `init.lua`
3. `setup()` merges options, then loads `avante_adapter.lua`
4. `register_backend("avante", adapter)` stores backend, generates keymaps + commands
5. Also calls `SkillStudio.setup()` if module exists

## Flow 2: User Presses `<leader>kc` (AI Chat)

```
User presses <leader>kc
  │
  ▼
init.lua keymap → call("chat")
  │
  ▼
call() wrapper checks:
  ├─ backend registered? → if no, warn and return
  ├─ backend.impl.chat exists? → if no, warn and return
  └─ backend.impl.chat() → execute
         │
         ▼
  avante_adapter.lua → chat()
         │
         ▼
  avante/methods.lua → actual Avante.nvim API call
         │
         ▼
  avante.nvim opens chat panel (Rust binary handles LLM communication)
```

## Flow 3: Provider + Key Resolution for AI Tools

```
User configures API key
  │
  ▼
:AIEditKeys → keys.edit()
  │
  ▼
Keys module writes to ~/.config/nvim/ai_keys.lua
  │  returns { bailian_coding = { key = "...", base_url = "..." }, ... }
  │
  ▼
Config watcher detects BufWritePost on ai_keys.lua
  │  (500ms debounce)
  │
  ▼
Sync.sync_all() triggered
  │
  ├─► OpenCode write_config()
  │     │
  │     ▼
  │   ConfigResolver.resolve()
  │     ├─ get_defaults()     → base model, permission settings
  │     ├─ read_template()    → opencode.template.jsonc (JSONC → JSON)
  │     ├─ read_project_config() → .opencode.json (if exists)
  │     ├─ deep_merge(all layers)
  │     ├─ resolve_refs()     → ${env:VAR}, ${provider:x:endpoint}, etc.
  │     └─ build_provider_config() → iterates Providers registry,
  │           builds provider entries with baseURL + apiKey from Keys module
  │     │
  │     ▼
  │   Writes ~/.config/opencode/config.json
  │
  ├─► Claude Code write_settings()
  │     │
  │     ▼
  │   Uses ConfigResolver + Providers + Keys → generates settings.json + CLAUDE.md
  │
  └─► Cache invalidated (5s TTL reset)
```

## Flow 4: Config Hot-Reload

```
User edits ~/.config/nvim/prompts/code_style.md
  │
  ▼
BufWritePost autocmd fires
  │
  ▼
ConfigWatcher callback:
  ├─ matches pattern "*.md" in prompts? → yes (if configured)
  └─ debounce_sync() starts 500ms timer
        │
        ▼ (500ms later)
  do_sync():
    ├─ Sync.sync_all({ silent = true })
    │   ├─ OpenCode writes new config (includes merged prompts)
    │   └─ Claude Code writes new settings
    └─ ConfigResolver.invalidate_cache()
```

## Flow 5: Context Collection (AICopyContext)

```
User runs :AICopyContext
  │
  ▼
context.lua get_context({ file, project, diagnostics })
  │
  ├─ get_current_file_info()
  │   └─ bufnr → filepath, filetype, line count, modified state
  │
  ├─ get_visual_selection()
  │   └─ '< and '> marks → extracted lines with col offsets
  │
  ├─ get_project_summary()
  │   ├─ find root marker (.git, package.json, ...) upward
  │   ├─ git branch --show-current
  │   ├─ git status --porcelain
  │   └─ project name and root path
  │
  ├─ get_lsp_diagnostics()
  │   └─ vim.diagnostic.get(bufnr) → errors, warnings, hints, info
  │
  └─ get_cursor_context()
      └─ cursor position + 20 lines of surrounding context
  │
  ▼
format_context_for_prompt() → markdown-formatted string
  │
  ▼
vim.fn.setreg("+", formatted) → system clipboard
  │
  ▼
"Context copied to clipboard" notification
```

## Flow 6: System Prompt Composition

```
:AIEditPrompts → opens ~/.config/nvim/prompts/ directory
  │
  OR
  │
  ▼
system_prompt.for_tool("opencode")
  │
  ▼
Looks up M.tool_files.opencode = ["todo_workflow.md", "code_style.md", "custom.md"]
  │
  ▼
for each filename:
  ├─ read_file(filename) → get content from prompts dir
  └─ if content is non-empty, include it
  │
  ▼
Concatenate all non-empties with "\n\n" separator
  │
  ▼
Returns composed system prompt string
  │
  ▼
Used by OpenCode/Claude Code/Avante config generation
```

## Flow 7: Terminal Management

```
User presses <leader>tt → TermSelect
  │
  ▼
ai.terminal_picker.open()
  │
  ▼
fzf-lua lists all managed terminals (by label)
  │
  ├─ Select existing → toggle/switch to it
  └─ Create new → terminal.create_free({ direction = "float" })
                    │
                    ▼
                  toggleterm.nvim creates terminal buffer
                    │
                    ▼
                  Labels it, registers in managed list
                    │
                    ▼
                  Lualine extension shows:
                  [label1] │ [label2] in status bar
```

**Code-to-terminal flow:**
```
User selects code in visual mode, presses <leader>tL
  │
  ▼
Get lines from '< to '> marks
  │
  ▼
Send each line to toggleterm terminal #1
  │
  ▼
terminal:send(line)
```

## Flow 8: Git Binary Resolution (Diffview)

```
Neovim starts, diffview.nvim plugin loaded
  │
  ▼
opts function runs:
  ├─ load_local_config() → ~/.local/state/nvim/diffview_local.lua
  │   returns { git_path = "/path/to/git" } or { git_path = nil }
  │
  ├─ defer_fn(100ms) → check_and_init_git()
  │   │
  │   ├─ If custom path exists and valid → use it
  │   ├─ If system git >= 2.31 → OK
  │   └─ If system git too old → show_git_version_warning()
  │       ├─ parse_git_version(system_git)
  │       ├─ find_git_executables() → scan PATH + common paths
  │       ├─ filter valid candidates (>= 2.31)
  │       └─ vim.ui.select → show options
  │           ├─ Select found git → apply_git_path()
  │           ├─ Custom path → handle_custom_git_input()
  │           └─ Skip → use default
  │
  └─ get_git_cmd() → returns git command array
      ├─ If .git is file (worktree) → read .git content, extract gitdir
      └─ Return [git_bin, "--git-dir=...", "--work-tree=..."] or [git_bin]
```

## Flow 9: Sync Engine — Full Picture

```
User runs :AISyncAll or :AISyncSelect
  │
  ▼
sync.lua sync_all() or select_and_sync()
  │
  ├─ For each registered target (opencode, claude_code):
  │   │
  │   ├─ check() → is tool installed? (executable check)
  │   │
  │   └─ sync() → calls target-specific module:
  │       │
  │       ├─ OpenCode: ai.opencode.write_config()
  │       │   └─ ConfigResolver.resolve() + Providers + Keys → JSON output
  │       │
  │       └─ Claude Code: ai.claude_code.write_settings()
  │           └─ Providers + Keys + System Prompt → settings output
  │
  ├─ Results collected → notify success/failure per target
  │
  └─ (optional) export_keys() → .env file for shell sourcing
```

## Flow 10: Model Switching

```
User presses <leader>ks → Model Switch
  │
  ▼
model_switch.lua opens fzf-lua picker
  │
  ├─ Lists available models from current provider
  │   ├─ static_models from provider definition
  │   └─ (optionally) dynamically fetched via fetch_models.lua
  │       (requires API call to provider /models endpoint)
  │
  └─ User selects model → updates State
      │
      ▼
  state.lua State.set(provider, model)
      │
      ├─ Updates internal state
      ├─ Notifies subscribers (e.g., status bar)
      └─ Maintains backward compat: sets _G.AI_MODEL (deprecated)
```

## Flow 11: Config Resolution (Detailed)

```
ConfigResolver.resolve() called
  │
  ▼
Cache check: if < 5s old → return cached config
  │
  ▼
Layer 1: get_defaults()
  { model: "bailian_coding/qwen3.6-plus", permission: {...}, compaction: {...} }
  │
  ▼
Layer 2: read_template() → opencode.template.jsonc
  ├─ strip_jsonc_comments() (handles // and /* */ comments)
  └─ vim.json.decode()
  │
  ▼
Layer 3: read_project_config() → .opencode.json in CWD
  └─ vim.json.decode()
  │
  ▼
deep_merge(L1, L2) → deep_merge(result, L3)
  │
  ▼
resolve_refs() → replaces ${env:VAR}, ${provider:x:endpoint}, ${key:x}, ${file:path}, ${exec:cmd}
  │
  ▼
build_provider_config() → iterates Providers registry:
  ├─ For each provider with API key:
  │   ├─ Look up base_url in Keys module
  │   ├─ Build provider entry: { npm: "@ai-sdk/openai-compatible", name: "...", options: { baseURL, apiKey: "{file:...}" }, models: {...} }
  └─ Deep-merge into config.provider
  │
  ▼
Cache config (5s TTL)
  │
  ▼
Return { config, auth_config }
```
