-- ~/.config/nvim/lua/plugins/avante.lua
-- 修补版：确保 AIModelSwitch 的选择会真正注入并生效（model 写回与 apply 注入）
return {
  {
    "yetone/avante.nvim",
    version = false,
    event = "VeryLazy",
    build = vim.fn.has("win32") ~= 0
      and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "ibhagwan/fzf-lua",
      "hrsh7th/nvim-cmp",
      "nvim-tree/nvim-web-devicons",
    },

    opts = {
      provider = "deepseek",
      providers = {
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          model = "deepseek-chat",
          timeout = 30000,
        },
        openai = {
          __inherited_from = "openai",
          api_key_name = "OPENAI_API_KEY",
          endpoint = "https://api.openai.com",
          model = "gpt-4o-mini",
          timeout = 30000,
        },
        qwen = {
          __inherited_from = "openai",
          api_key_name = "QWEN_API_KEY",
          endpoint = "https://{QWEN_BASE_ENDPOINT}",
          model = "qwen-2.5-chat",
          timeout = 30000,
        },
        minimax = {
          __inherited_from = "openai",
          api_key_name = "MINIMAX_API_KEY",
          endpoint = "https://{MINIMAX_BASE_ENDPOINT}",
          model = "minimax-latest",
          timeout = 30000,
        },
        kimi = {
          __inherited_from = "openai",
          api_key_name = "KIMI_API_KEY",
          endpoint = "https://{KIMI_BASE_ENDPOINT}",
          model = "kimi-k2-0711-preview",
          timeout = 30000,
        },
        glm = {
          __inherited_from = "openai",
          api_key_name = "GLM_API_KEY",
          endpoint = "https://{GLM_BASE_ENDPOINT}",
          model = "GLM-4.7",
          timeout = 30000,
        },
        bailian = {
          __inherited_from = "openai",
          api_key_name = "BAILIAN_API_KEY",
          endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1",
          model = "bailian-chat-v1",
          timeout = 30000,
        },
        dashscope = {
          __inherited_from = "openai",
          api_key_name = "DASHSCOPE_API_KEY",
          endpoint = "https://api.dashscope.com",
          model = "qwen2.5-coder",
          timeout = 30000,
        },
        moonshot = {
          __inherited_from = "openai",
          api_key_name = "MOONSHOT_API_KEY",
          endpoint = "https://api.moonshot.ai",
          model = "moonshot-v1",
          timeout = 30000,
        },
        ollama = {
          __inherited_from = "openai",
          api_key_name = "OLLAMA_API_KEY",
          endpoint = "http://localhost:11434",
          model = "qwen2.5-coder:latest",
          timeout = 30000,
        },
      },

      chat = { persist = true },
      actions = { enabled = true },
      completion = { enabled = true, provider = "avante" },
    },

    config = function(_, opts)
      local ok, avante = pcall(require, "avante")
      if not ok then
        vim.notify("avante.nvim not found", vim.log.levels.ERROR)
        return
      end

      -- helpers for ai_keys
      local function keys_path() return vim.fn.stdpath("state") .. "/ai_keys.lua" end
      local function ensure_ai_keys()
        local path = keys_path()
        if vim.fn.filereadable(path) == 0 then
          local default = [[
return {
  profile = "default",
  deepseek = { default = "" },
  openai = { default = "" },
  qwen = { default = "" },
  minimax = { default = "" },
  kimi = { default = "" },
  glm = { default = "" },
  bailian = { default = "" },
  dashscope = { default = "" },
  moonshot = { default = "" },
  ollama = { default = "" },
}
]]
          vim.fn.writefile(vim.split(default, "\n"), path)
        end
        return dofile(path)
      end
      local function read_ai_keys()
        local path = keys_path()
        if vim.fn.filereadable(path) == 0 then return nil end
        return dofile(path)
      end
      local function write_ai_keys(tbl)
        local out = { "return {" }
        for k, v in pairs(tbl) do
          if k ~= "profile" then
            table.insert(out, string.format("  %s = {", k))
            for p, val in pairs(v) do
              table.insert(out, string.format("    %s = %q,", p, val))
            end
            table.insert(out, "  },")
          end
        end
        table.insert(out, string.format("  profile = %q,", tbl.profile))
        table.insert(out, "}")
        vim.fn.writefile(out, keys_path())
      end

      -- merge helper
      local function merge_table(a, b)
        a = a or {}
        for k, v in pairs(b or {}) do a[k] = v end
        return a
      end

      local function provider_has_key(provider, profile)
        local keys = read_ai_keys()
        if not keys then return false end
        profile = profile or keys.profile or "default"
        local provider_table = keys[provider] or {}
        local key = provider_table[profile] or provider_table["default"] or ""
        return key ~= ""
      end

      -- apply key and provider: ensure model is injected from _G.AI_MODEL or opts
      local function apply_ai_key_and_provider()
        local keys = read_ai_keys()
        if not keys then return false end

        local profile = keys.profile or "default"
        local provider = (_G.AI_MODEL and _G.AI_MODEL.provider) or opts.provider or "openai"
        local provider_table = keys[provider] or {}
        local key = provider_table[profile] or provider_table["default"] or ""

        local env_map = {
          openai = "OPENAI_API_KEY",
          deepseek = "DEEPSEEK_API_KEY",
          qwen = "QWEN_API_KEY",
          minimax = "MINIMAX_API_KEY",
          kimi = "KIMI_API_KEY",
          glm = "GLM_API_KEY",
          bailian = "BAILIAN_API_KEY",
          dashscope = "DASHSCOPE_API_KEY",
          moonshot = "MOONSHOT_API_KEY",
          ollama = "OLLAMA_API_KEY",
        }
        local env_var = env_map[provider] or "OPENAI_API_KEY"

        -- inject env
        vim.env[env_var] = key
        vim.env.OPENAI_API_KEY = key

        -- ensure model is taken from _G.AI_MODEL.model if present
        local final_model = (_G.AI_MODEL and _G.AI_MODEL.model) or (opts.providers[provider] and opts.providers[provider].model)

        local new_opts = vim.deepcopy(opts)
        new_opts.provider = provider
        new_opts.providers[provider] = merge_table(new_opts.providers[provider] or {}, { api_key = key, model = final_model })

        -- debug: uncomment if you need to inspect final provider config
        -- vim.schedule(function() vim.notify("Final provider config: "..vim.inspect(new_opts.providers[provider]), vim.log.levels.DEBUG) end)

        avante.setup(new_opts)
        _G.AI_MODEL = _G.AI_MODEL or {}
        _G.AI_MODEL.provider = provider
        _G.AI_MODEL.model = final_model
      end

      -- safe wrapper
      local function safe_avante_cmd(cmd)
        return function()
          apply_ai_key_and_provider()
          pcall(vim.cmd, cmd)
        end
      end

      -- keymaps
      vim.keymap.set("n", "<leader>kc", safe_avante_cmd("AvanteChat"), { desc = "AI Chat" })
      vim.keymap.set("v", "<leader>ke", safe_avante_cmd("AvanteEdit"), { desc = "AI Edit selection" })
      vim.keymap.set("n", "<leader>kq", safe_avante_cmd("AvanteAsk"), { desc = "AI Ask" })
      vim.keymap.set("n", "<leader>kn", safe_avante_cmd("AvanteChatNew"), { desc = "AI New Chat" })

      -- try_fetch_models (精简版，返回 models_table, tried, succ, fail)
      local function try_fetch_models(endpoint, api_key)
        if not endpoint or endpoint == "" then return nil, {}, {}, {} end
        local candidates = {
          endpoint .. "/v1/models",
          endpoint .. "/models",
          endpoint .. "/api/models",
          endpoint .. "/chat/models",
        }
        local headers = {}
        if api_key and api_key ~= "" then
          headers = { "Authorization: Bearer " .. api_key, "Content-Type: application/json" }
        else
          headers = { "Content-Type: application/json" }
        end

        local tried_urls, succeeded_urls, failed_urls = {}, {}, {}
        local collected = {}

        for _, url in ipairs(candidates) do
          table.insert(tried_urls, url)
          local cmd = string.format("curl -s -H %q -H %q %q", headers[1] or "", headers[2] or "", url)
          local fh = io.popen(cmd)
          if fh then
            local out = fh:read("*a")
            fh:close()
            if out and out:match("%S") then
              local ok, json = pcall(vim.fn.json_decode, out)
              if ok and type(json) == "table" then
                if json.data and type(json.data) == "table" then
                  for _, v in ipairs(json.data) do if v.id then table.insert(collected, v) end end
                elseif type(json[1]) == "table" and json[1].id then
                  for _, v in ipairs(json) do table.insert(collected, v) end
                else
                  for k, v in pairs(json) do if type(v) == "table" and v.id then table.insert(collected, v) end end
                end
                if #collected > 0 then table.insert(succeeded_urls, url) else table.insert(failed_urls, url) end
              else
                table.insert(failed_urls, url)
              end
            else
              table.insert(failed_urls, url)
            end
          else
            table.insert(failed_urls, url)
          end
        end

        -- 去重
        local seen, uniq = {}, {}
        for _, m in ipairs(collected) do
          local id = m.id or tostring(m)
          if not seen[id] then seen[id] = true; table.insert(uniq, m) end
        end
        return uniq, tried_urls, succeeded_urls, failed_urls
      end

      -- beautify model item
      local function beautify_model_item(m)
        local id = m.id or tostring(m)
        local owner = m.owned_by or m.owner or "unknown"
        local created = m.created or m.create_time or m.created_at
        local created_str = "unknown"
        if type(created) == "number" then
          created_str = os.date("%Y-%m-%d %H:%M:%S", created)
        elseif type(created) == "string" and tonumber(created) then
          created_str = os.date("%Y-%m-%d %H:%M:%S", tonumber(created))
        end
        return string.format("%s  —  %s  —  %s", id, created_str, owner), id
      end

      -- AIModelSwitch: 先选 provider，再动态拉取或回退静态候选
      vim.api.nvim_create_user_command("AIModelSwitch", function()
        local fzf_ok, fzf = pcall(require, "fzf-lua")
        if not fzf_ok then
          vim.notify("fzf-lua not installed", vim.log.levels.WARN)
          return
        end

        _G.AI_KEYS = ensure_ai_keys()
        local profile = _G.AI_KEYS.profile or "default"

        local providers = {}
        for name, _ in pairs(opts.providers or {}) do table.insert(providers, name) end

        local model_candidates = {
          deepseek = { "deepseek-chat", "deepseek-reasoner" },
          openai = { "gpt-4o-mini", "gpt-4o" },
          qwen = { "qwen-2.5-chat", "qwen-code" },
          minimax = { "minimax-latest" },
          kimi = { "kimi-k2-0711-preview" },
          glm = { "GLM-4.7" },
          bailian = { "bailian-chat-v1", "bailian-code-v1", "bailian-embed-v1" },
          dashscope = { "qwen2.5-coder" },
          moonshot = { "moonshot-v1" },
          ollama = { "qwen2.5-coder:latest" },
        }

        fzf.fzf_exec(providers, {
          prompt = "Providers> ",
          actions = {
            ["default"] = function(selected)
              local provider = selected[1]
              local provider_conf = opts.providers[provider] or {}
              local endpoint = provider_conf.endpoint
              local keys_tbl = read_ai_keys() or {}
              local key = ""
              if keys_tbl[provider] then
                local prof = keys_tbl.profile or "default"
                key = keys_tbl[provider][prof] or keys_tbl[provider].default or ""
              end
              if key == "" then key = vim.env[(provider:upper() .. "_API_KEY")] or "" end

              local models_raw, tried, succ, fail = try_fetch_models(endpoint, key)

              local succ_count = #succ
              local fail_count = #fail
              local model_count = models_raw and #models_raw or 0
              local notify_msg = string.format("Model fetch result: success_links=%d failed_links=%d models=%d", succ_count, fail_count, model_count)
              vim.notify(notify_msg, vim.log.levels.INFO)
              if succ_count > 0 then vim.notify("Succeeded: " .. table.concat(succ, ", "), vim.log.levels.DEBUG) end
              if fail_count > 0 then vim.notify("Failed: " .. table.concat(fail, ", "), vim.log.levels.WARN) end

              local models_for_display = {}
              local id_map = {}
              if model_count > 0 then
                for _, m in ipairs(models_raw) do
                  local label, id = beautify_model_item(m)
                  table.insert(models_for_display, label)
                  id_map[label] = id
                end
              else
                local static = model_candidates[provider] or {}
                for _, id in ipairs(static) do
                  local label = string.format("%s  —  %s  —  %s", id, "unknown", "unknown")
                  table.insert(models_for_display, label)
                  id_map[label] = id
                end
                if #models_for_display == 0 and provider_conf.model then
                  local id = provider_conf.model
                  local label = string.format("%s  —  %s  —  %s", id, "unknown", "unknown")
                  table.insert(models_for_display, label)
                  id_map[label] = id
                end
              end

              fzf.fzf_exec(models_for_display, {
                prompt = string.format("Models for %s> ", provider),
                actions = {
                  ["default"] = function(sel)
                    local label = sel[1]
                    local chosen_id = id_map[label]
                    if chosen_id then
                      -- **关键：同时写入全局与 opts，并立即应用**
                      _G.AI_MODEL = _G.AI_MODEL or {}
                      _G.AI_MODEL.provider = provider
                      _G.AI_MODEL.model = chosen_id

                      opts.providers[provider] = opts.providers[provider] or {}
                      opts.providers[provider].model = chosen_id

                      -- 可选：清理会话缓存（若你怀疑旧会话导致仍使用旧 model）
                      -- local sessions_dir = vim.fn.stdpath("data") .. "/avante/sessions"
                      -- if vim.fn.isdirectory(sessions_dir) == 1 then
                      --   for _, f in ipairs(vim.fn.globpath(sessions_dir, "*.json", false, true)) do os.remove(f) end
                      -- end

                      apply_ai_key_and_provider()
                      vim.notify(string.format("Switched to %s / %s", provider, chosen_id), vim.log.levels.INFO)
                    end
                  end,
                },
              })
            end,
          },
        })
      end, {})

      -- AIKeyManager (unchanged)
      vim.api.nvim_create_user_command("AIKeyManager", function()
        local fzf_ok, fzf = pcall(require, "fzf-lua")
        if not fzf_ok then
          vim.notify("fzf-lua not installed", vim.log.levels.WARN)
          return
        end

        _G.AI_KEYS = ensure_ai_keys()

        local items = {}
        for provider, profiles in pairs(_G.AI_KEYS) do
          if provider ~= "profile" then
            for profile, key in pairs(profiles) do
              local has = (key ~= "" and "***" or "(empty)")
              table.insert(items, string.format("%-12s │ %-10s │ %s", provider, profile, has))
            end
          end
        end

        fzf.fzf_exec(items, {
          prompt = "AI Keys> ",
          actions = {
            ["default"] = function() vim.cmd("edit " .. keys_path()) end,
            ["ctrl-s"] = function(selected)
              local provider, profile = selected[1]:match("^(%S+)%s+│%s+(%S+)")
              local tbl = read_ai_keys()
              tbl.profile = profile
              write_ai_keys(tbl)
              apply_ai_key_and_provider()
            end,
          },
        })
      end, {})

      -- Sessions manager (unchanged)
      vim.api.nvim_create_user_command("AIChatSessions", function()
        local fzf_ok, fzf = pcall(require, "fzf-lua")
        if not fzf_ok then
          vim.notify("fzf-lua not installed", vim.log.levels.WARN)
          return
        end

        local dir = vim.fn.stdpath("data") .. "/avante/sessions"
        if vim.fn.isdirectory(dir) == 0 then
          vim.notify("No sessions directory", vim.log.levels.INFO)
          return
        end

        local sessions = vim.fn.glob(dir .. "/*.json", false, true)
        if #sessions == 0 then
          vim.notify("No sessions found", vim.log.levels.INFO)
          return
        end

        local items = {}
        for _, path in ipairs(sessions) do
          local name = vim.fn.fnamemodify(path, ":t:r")
          local time = os.date("%Y-%m-%d %H:%M", vim.fn.getftime(path))
          table.insert(items, string.format("%-30s │ %s │ %s", name, time, path))
        end

        fzf.fzf_exec(items, {
          prompt = "Sessions> ",
          actions = {
            ["default"] = function(selected)
              local path = selected[1]:match("│%s*(.+)$")
              require("avante").load_session(path)
            end,
            ["ctrl-d"] = function(selected)
              local path = selected[1]:match("│%s*(.+)$")
              os.remove(path)
            end,
          },
        })
      end, {})

      -- keymaps for commands
      vim.keymap.set("n", "<leader>km", "<cmd>AIModelSwitch<cr>", { desc = "AI Model Switch" })
      vim.keymap.set("n", "<leader>kk", "<cmd>AIKeyManager<cr>", { desc = "AI Key Manager" })
      vim.keymap.set("n", "<leader>kh", "<cmd>AIChatSessions<cr>", { desc = "AI Chat Sessions" })

      -- apply on startup
      pcall(apply_ai_key_and_provider)
    end,
  },
}

