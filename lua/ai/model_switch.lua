-- lua/ai/model_switch.lua
-- Model Switch（独立模块，可复用到任何 AI 插件）
-- 自动读取 providers.lua / fetch_models.lua / util.lua
-- 使用异步 API 获取模型列表，不阻塞 UI
-- 支持选择作用范围：全局、OpenCode、Claude Code

local Providers = require("ai.providers")
local Fetch = require("ai.fetch_models")
local Util = require("ai.util")
local Status = require("ai.provider_manager.status")
local Registry = require("ai.provider_manager.registry")

local M = {}

----------------------------------------------------------------------
-- Helper: Ask for scope after model selection
----------------------------------------------------------------------
local function ask_scope_and_set(provider, model, callback)
  vim.ui.select({
    "全局默认 (所有工具)",
    "仅 OpenCode",
    "仅 Claude Code",
    "OpenCode + Claude Code",
  }, {
    prompt = "\n设置作用范围:\n",
  }, function(choice, idx)
    if not choice then
      return
    end

    if idx == 1 then
      Registry.set_global_default(provider, model)
    elseif idx == 2 then
      Registry.set_tool_default("opencode", provider, model)
    elseif idx == 3 then
      Registry.set_tool_default("claude_code", provider, model)
    elseif idx == 4 then
      Registry.set_tool_default("opencode", provider, model)
      Registry.set_tool_default("claude_code", provider, model)
    end

    if callback then
      callback({ scope = idx, provider = provider, model = model })
    end
  end)
end

----------------------------------------------------------------------
-- select(callback): 弹出 FZF 选择 provider + model + scope
----------------------------------------------------------------------
function M.select(callback)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not installed", vim.log.levels.ERROR)
    return
  end

  --------------------------------------------------------------------
  -- Step 1: provider 列表（自动从 providers.lua 读取）
  --------------------------------------------------------------------
  local providers = Providers.list()

  fzf.fzf_exec(providers, {
    prompt = "Providers> ",
    actions = {
      ["default"] = function(selected)
        local provider = selected[1]
        local def = Providers.get(provider)
        if not def then
          return
        end

        ----------------------------------------------------------------
        -- Step 2: 异步拉取模型（不阻塞 UI）
        ----------------------------------------------------------------
        -- 显示加载提示
        local loading_id = "model_fetch_" .. provider
        vim.notify(
          string.format("⏳ 正在获取 %s 模型列表...", provider),
          vim.log.levels.INFO,
          { title = "Model Switch", replace = loading_id }
        )

        Fetch.fetch_async(provider, function(models_raw)
          vim.schedule(function()
            -- 清除加载提示
            vim.notify("", vim.log.levels.INFO, { title = "Model Switch", replace = loading_id })

            local models_for_display = {}
            local id_map = {}

            if models_raw and #models_raw > 0 then
              -- 动态模型成功
              for _, m in ipairs(models_raw) do
                local label, id = Util.beautify_model_item(m)
                table.insert(models_for_display, label)
                id_map[label] = id
              end
            else
              -- 动态拉取失败 → fallback 到 static_models
              local static = def.static_models or {}
              for _, id in ipairs(static) do
                local label = string.format("%s  —  %s  —  %s", id, "unknown", "unknown")
                table.insert(models_for_display, label)
                id_map[label] = id
              end

              -- 如果 static_models 也为空 → fallback 到默认 model
              if #models_for_display == 0 and def.model then
                local id = def.model
                local label = string.format("%s  —  %s  —  %s", id, "unknown", "unknown")
                table.insert(models_for_display, label)
                id_map[label] = id
              end
            end

            ----------------------------------------------------------------
            -- Step 3: 选择模型
            ----------------------------------------------------------------
            if #models_for_display == 0 then
              vim.notify(string.format("⚠️ %s 没有可用的模型", provider), vim.log.levels.WARN)
              return
            end

            fzf.fzf_exec(models_for_display, {
              prompt = string.format("Models for %s> ", provider),
              actions = {
                ["default"] = function(sel)
                  local label = sel[1]
                  local model = id_map[label]
                  if not model then
                    return
                  end

                  -- Ask for scope and set accordingly
                  ask_scope_and_set(provider, model, callback)
                end,
              },
            })
          end)
        end)
      end,
    },
  })
end

return M
