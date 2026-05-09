-- lua/ai/model_switch.lua
-- Model Switch（独立模块，可复用到任何 AI 插件）
-- 自动读取 providers.lua / fetch_models.lua / util.lua

local Providers = require("ai.providers")
local Fetch = require("ai.fetch_models")
local Util = require("ai.util")
local Status = require("ai.provider_manager.status")

local M = {}

----------------------------------------------------------------------
-- select(): 弹出 FZF 选择 provider + model
-- 返回 { provider = "...", model = "..." }
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
        -- Step 2: 动态拉取模型
        ----------------------------------------------------------------
        local models_raw, _, _, _ = Fetch.fetch(provider)

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
        fzf.fzf_exec(models_for_display, {
          prompt = string.format("Models for %s> ", provider),
          actions = {
            ["default"] = function(sel)
              local label = sel[1]
              local model = id_map[label]
              if not model then
                return
              end

              ----------------------------------------------------------------
              -- 返回最终选择结果
              ----------------------------------------------------------------
              -- PMGR-07: Auto-detect availability in background before callback
              Status.trigger_async_check(provider, model, function(result)
                if not result then
                  return
                end

                -- C-01/C-10: vim.notify wrapped in vim.schedule for async callback safety
                vim.schedule(function()
                  if result.status == "auth_failed" then
                    -- 认证失败 - ERROR 级别，明确提示用户修复
                    vim.notify(
                      string.format(
                        "❌ [AI] Provider '%s' API key 无效或未注册！\n错误: %s\n请使用 :AIKeys 编辑 API key",
                        provider,
                        result.error_msg or "认证失败"
                      ),
                      vim.log.levels.ERROR,
                      { title = "AI Provider Auth Failed", replace = true }
                    )
                  elseif result.status == "unavailable" then
                    -- 模型不可用 - WARN 级别
                    local msg = string.format("⚠️  [AI] %s / %s 状态: %s", provider, model, result.status)
                    if result.error_msg then
                      msg = msg .. " — " .. result.error_msg
                    end
                    vim.notify(msg, vim.log.levels.WARN, { title = "AI Provider", replace = true })
                  elseif result.status == "timeout" then
                    -- 连接超时 - WARN 级别
                    vim.notify(
                      string.format("⚠️  [AI] Provider '%s' 连接超时，请检查网络", provider),
                      vim.log.levels.WARN,
                      { title = "AI Provider Timeout", replace = true }
                    )
                  end
                end)
              end)

              -- 自动设置全局默认 provider + model
              local Registry = require("ai.provider_manager.registry")
              Registry.set_global_default(provider, model)

              if callback then
                callback({
                  provider = provider,
                  model = model,
                })
              end
            end,
          },
        })
      end,
    },
  })
end

return M
