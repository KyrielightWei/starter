# AGENTS.md - Guide for AI Coding Agents

This document provides essential information for AI coding agents working in this LazyVim/Neovim configuration repository.

## Project Overview

This is a **LazyVim Neovim configuration** written in **Lua**. It's a modular configuration system with an AI integration layer.

### Project Structure
```
.
├── init.lua                  # Entry point
├── lua/
│   ├── config/               # Core configuration
│   │   ├── lazy.lua         # Plugin manager setup
│   │   ├── options.lua      # Neovim options
│   │   ├── keymaps.lua      # Global keymaps
│   │   └── autocmds.lua     # Autocommands
│   ├── plugins/              # Plugin specifications
│   │   └── *.lua            # Individual plugin configs
│   └── ai/                   # AI integration module
│       ├── init.lua         # Main entry, backend registration
│       ├── state.lua        # State manager (get/set/subscribe)
│       ├── providers.lua    # Provider registry (OpenAI, DeepSeek, etc.)
│       ├── keys.lua         # API key management
│       ├── util.lua         # Utility functions
│       ├── health.lua       # Health check module (:checkhealth ai)
│       ├── adapter_template.lua  # Adapter development guide
│       ├── avante/          # Avante backend implementation
│       │   ├── config.lua   # Configuration builder
│       │   └── methods.lua  # Backend methods (chat, edit, etc.)
│       └── *_adapter.lua    # Other backend adapters
├── tests/                    # Test suite
│   ├── init.lua             # Test entry point
│   ├── minimal_init.lua     # Minimal Neovim config for testing
│   └── ai/                  # AI module tests
│       ├── state_spec.lua   # State manager tests
│       ├── providers_spec.lua # Providers tests
│       ├── util_spec.lua    # Utility tests
│       └── init_spec.lua    # Integration tests
└── prompts/                  # Workflow documentation
```

---

## Build/Lint/Test Commands

### Formatting
```bash
# Format all Lua files with stylua
stylua lua/

# Format specific file
stylua lua/ai/init.lua

# Check formatting without modifying
stylua --check lua/
```

### Linting
```bash
# Using luacheck (if installed)
luacheck lua/

# Using selene (if installed)
selene lua/
```

### Testing
```bash
# Run all tests with plenary.nvim
nvim --headless -c "PlenaryBustedDirectory tests/" -c "q"

# Run specific test file
nvim --headless -c "PlenaryBustedFile tests/ai/state_spec.lua" -c "q"

# Run tests with minimal config
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/" -c "q"

# Quick syntax check
nvim --headless -c "lua print('OK')" -c "q"
```

### Health Check
```bash
# Run AI module health check
nvim -c "checkhealth ai" -c "q"

# Or programmatically
nvim --headless -c "lua require('ai').setup()" -c "checkhealth ai" -c "q" 2>&1
```

### Validation
```bash
# Verify Lua syntax
nvim -c "lua print('OK')" -c "q"

# Check if plugins load correctly
nvim --headless "+Lazy! sync" +qa

# Verify AI module loads
nvim --headless -c "lua require('ai').setup()" -c "q" 2>&1
```

---

## AI Module Architecture

### State Management
The AI module uses a centralized state manager (`lua/ai/state.lua`) instead of global variables.

```lua
local State = require("ai.state")

-- Get current state
local state = State.get()  -- Returns { provider, model }

-- Set state
State.set("openai", "gpt-4")

-- Subscribe to state changes
State.subscribe(function(new_state)
  print("State changed to:", new_state.provider, new_state.model)
end)
```

**Backward Compatibility**: `_G.AI_MODEL` still works but shows a deprecation warning.

### Backend Adapter Pattern
Each backend adapter must implement these methods:
- `chat()` - Open chat window
- `chat_new()` - Create new chat session
- `edit()` - Edit selected code
- `ask()` - Quick ask
- `model_switch()` - Switch model
- `key_manager()` - Manage API keys
- `sessions()` - Manage sessions
- `toggle()` - Toggle panel
- `diff()` - View diff
- `suggestion_next/prev/accept()` - Handle suggestions

See `lua/ai/adapter_template.lua` for a complete guide.

---

## Code Style Guidelines

### Formatting Rules (from stylua.toml)
- **Indentation**: 2 spaces (not tabs)
- **Column width**: 120 characters
- **Quote style**: Prefer double quotes for strings

### Imports and Requires
```lua
-- Group requires at the top of the file
local Providers = require("ai.providers")
local Keys = require("ai.keys")
local State = require("ai.state")
local Util = require("ai.util")

-- Use pcall for optional dependencies
local ok, module = pcall(require, "optional_module")
if not ok then
  vim.notify("Module not found", vim.log.levels.WARN)
  return
end
```

### Module Pattern
```lua
-- File header comment
-- lua/ai/module_name.lua
-- Brief description

local M = {}

-- Private functions use local
local function private_helper()
  -- implementation
end

-- Public functions attach to M
function M.public_function()
  -- implementation
end

return M
```

### Section Separators
```lua
----------------------------------------------------------------------
-- Section Title
-- @param name type: description (optional)
----------------------------------------------------------------------
```

### Function Definitions
```lua
-- Public function
function M.setup(opts)
  opts = opts or {}
  -- implementation
end

-- Private function
local function build_config()
  -- implementation
end
```

### Error Handling
```lua
-- Use pcall for safe operations
local ok, result = pcall(require, "module")
if not ok then
  vim.notify("Error: " .. result, vim.log.levels.ERROR)
  return
end

-- Use vim.notify for user feedback
vim.notify("Success message", vim.log.levels.INFO)
vim.notify("Warning message", vim.log.levels.WARN)
vim.notify("Error message", vim.log.levels.ERROR)

-- Use pcall for unsafe operations
pcall(vim.cmd, "AvanteToggle")
```

### Naming Conventions
```lua
-- Variables: snake_case
local my_variable = "value"
local config_table = {}

-- Functions: snake_case
function M.get_config() end
local function process_data() end

-- Constants: UPPER_CASE
local DEFAULT_TIMEOUT = 30000
local MAX_RETRIES = 3

-- Module tables: PascalCase when used as classes
local Providers = require("ai.providers")
local ModelSwitch = require("ai.model_switch")
local State = require("ai.state")

-- Boolean variables: use is_/has_ prefix
local is_configured = false
local has_plugins = true
```

### Table Definitions
```lua
-- Multi-line tables with trailing commas
local config = {
  provider = "openai",
  model = "gpt-4",
  timeout = 30000,
  options = {
    temperature = 0.7,
    max_tokens = 2048,
  },
}

-- Inline for simple cases
local colors = { "red", "green", "blue" }
```

### Plugin Configuration Pattern
```lua
-- lua/plugins/plugin_name.lua
return {
  {
    "author/plugin-name",
    event = "VeryLazy",  -- or keys = {}, cmd = {}
    opts = {
      -- plugin options
    },
    config = function(_, opts)
      require("plugin").setup(opts)
    end,
  },
}
```

### Keymaps Definition
```lua
-- Define in tables and iterate
local keys = {
  { "<leader>kc", mode = "n", fn = call("chat"), desc = "AI Chat" },
  { "<leader>ke", mode = "v", fn = call("edit"), desc = "AI Edit" },
}

function M.setup_keys()
  for _, key in ipairs(keys) do
    vim.keymap.set(key.mode, key[1], key.fn, { desc = key.desc })
  end
end
```

### User Commands
```lua
local commands = {
  { "AIChat", call("chat"), desc = "Open AI Chat" },
  { "AIEdit", call("edit"), desc = "AI Edit Selection", range = true },
}

function M.setup_commands()
  for _, cmd in ipairs(commands) do
    local opts = { desc = cmd.desc }
    if cmd.range then opts.range = true end
    vim.api.nvim_create_user_command(cmd[1], cmd[2], opts)
  end
end
```

### String Formatting
```lua
-- Use string.format for complex strings
local msg = string.format("Switched to %s / %s", provider, model)

-- Use gsub for substitutions
local endpoint = endpoint:gsub("{(%w+_BASE_ENDPOINT)}", "")
```

### Vim API Usage
```lua
-- Get current buffer name
local bufname = vim.api.nvim_buf_get_name(0)

-- Get current working directory
local cwd = vim.loop.cwd()  -- or vim.uv.cwd() in newer versions

-- Check if file exists
if vim.fn.filereadable(path) == 1 then
  -- file exists
end

-- Write file
vim.fn.writefile(lines, path)

-- Defer execution
vim.defer_fn(function()
  -- delayed code
end, 100)
```

---

## Best Practices

1. **Lazy Loading**: Use `event = "VeryLazy"` or `keys = {}` for plugins
2. **Safe Requires**: Always use `pcall` for optional modules
3. **User Feedback**: Use `vim.notify` with appropriate log levels
4. **Configuration**: Use `opts = {}` pattern for plugin options
5. **Documentation**: Add file header comments explaining module purpose
6. **Error Recovery**: Provide fallbacks when dependencies are missing
7. **State Management**: Use `require("ai.state")` instead of `_G.AI_MODEL`
8. **Testing**: Write tests for new modules in `tests/ai/`

---

## Workflow Patterns

### Adding a New Provider
1. Edit `lua/ai/providers.lua`
2. Call `M.register("provider_name", { ... })`
3. No other changes needed

### Adding a New Backend Adapter
1. Read `lua/ai/adapter_template.lua` for the complete guide
2. Create `lua/ai/xxx_adapter.lua`
3. Implement required methods: `chat`, `edit`, `ask`, etc.
4. Return implementation from `M.setup()`
5. Update `lua/ai/init.lua` if changing default backend

### Adding a New Plugin
1. Create `lua/plugins/plugin_name.lua`
2. Return plugin spec table
3. Use appropriate lazy-loading event

### Writing Tests
1. Create test file in `tests/ai/xxx_spec.lua`
2. Use plenary.nvim test framework (`describe`, `it`, `assert`)
3. Run with: `nvim --headless -c "PlenaryBustedFile tests/ai/xxx_spec.lua" -c "q"`

---

## Avante.nvim 构建管理

### 自动构建提示

当首次使用 AI 功能时，如果 Avante.nvim 未构建，会弹出选择对话框：

```
┌─────────────────────────────────────────────────────────┐
│  Avante.nvim 需要构建才能正常使用                        │
│  构建大约需要 2-5 分钟，完成后即可使用所有功能            │
└─────────────────────────────────────────────────────────┘

选择：
  🚀 立即构建（推荐）
  ⏭️  跳过构建
```

### 构建进度显示

选择"立即构建"后，会在浮动窗口显示构建日志：

```
╔══════════════════════════════════════════════════════════════╗
║            Avante.nvim 构建日志                              ║
╚══════════════════════════════════════════════════════════════╝

⏳ 正在构建... 这可能需要 2-5 分钟
[build output...]
══════════════════════════════════════════════════════════════
✅ 构建成功！
══════════════════════════════════════════════════════════════
```

### 手动命令

```vim
" 手动触发构建
:AvanteBuild

" 查看构建状态
:AvanteBuildStatus
```

### 优雅降级

如果选择"跳过构建"：
- AI 聊天功能不可用（会再次提示构建）
- Key 管理等非核心功能仍可用
- 下次使用时会再次询问
