-- lua/ai/avante/config.lua
-- Avante configuration builder

local Providers = require("ai.providers")
local Keys = require("ai.keys")

local M = {}

----------------------------------------------------------------------
-- build_opts(): 构建 Avante 配置
----------------------------------------------------------------------
function M.build()
  local providers_tbl = {}

  for name, def in pairs(Providers) do
    if type(def) == "table" and def.endpoint then
      -- 使用 Keys.get_base_url() 优先读取用户在 ai_keys.lua 中配置的 base_url
      local endpoint = Keys.get_base_url(name)

      providers_tbl[name] = {
        __inherited_from = def.inherited or "openai",
        api_key_name = def.api_key_name,
        endpoint = endpoint,
        model = def.model,
        timeout = def.timeout or 30000,
        static_models = def.static_models,
      }
    end
  end

  local ok, system_prompt = pcall(require, "ai.system_prompt")
  local system_prompt_value = ok and system_prompt.for_tool("avante") or ""

  return {
    provider = Providers.default_provider,
    providers = providers_tbl,
    chat = { persist = true },
    actions = { enabled = true },
    completion = { enabled = true, provider = "avante" },
    system_prompt = system_prompt_value,
    -- 窗口配置
    windows = {
      position = "right",
      width = 35,
      height = 0.8,
      fillchars = "eob: ",
      wrap = true,
      sidebar_header = {
        enabled = true,
        align = "center",
        rounded = true,
      },
      input = {
        prefix = "> ",
        height = 8,
      },
      ask = {
        floating = true,
        border = "rounded",
        start_insert = true,
        width = 0.5,
        height = 0.35,
        relative = "editor",
        row = 0.32,
        col = 0.25,
        style = "minimal",
        win_options = {
          winblend = 5,
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
      },
      edit = {
        border = "rounded",
        start_insert = true,
        width = 0.6,
        height = 0.5,
        relative = "editor",
        row = 0.25,
        col = 0.2,
      },
      chat = {
        floating = false,
        border = "rounded",
        width = 0.5,
        height = 0.7,
        relative = "editor",
        row = 0.15,
        col = 0.25,
      },
      spinner = {
        editing = {
          "⡀",
          "⠄",
          "⠂",
          "⠁",
          "⠈",
          "⠐",
          "⠠",
          "⢀",
          "⣀",
          "⢄",
          "⢂",
          "⢁",
          "⢈",
          "⢐",
          "⢠",
          "⣠",
          "⢤",
          "⢢",
          "⢡",
          "⢨",
          "⢰",
          "⣰",
          "⢴",
          "⢲",
          "⢱",
          "⢸",
          "⣸",
          "⢼",
          "⢺",
          "⢹",
          "⣹",
          "⢽",
          "⢻",
          "⣻",
          "⢿",
          "⣿",
        },
        generating = { "✨", "🌟", "💫", "⭐", "☄️", "🌠" },
        thinking = { "🤔", "🧠", "💭", "💡" },
      },
    },
    behaviour = {
      auto_focus_sidebar = true,
      auto_set_keymaps = true,
      auto_set_highlight_group = true,
      enable_token_counting = true,
      auto_apply_diff_after_generation = false,
      minimize_diff = true,
      auto_focus_on_diff_view = true,
    },
    diff = {
      autojump = true,
      override_timeoutlen = 500,
    },
    highlights = {
      diff = {
        current = "DiffAdd",
        incoming = "DiffChange",
      },
    },
    selection = {
      enabled = true,
      hint_display = "delayed",
    },
  }
end

return M
