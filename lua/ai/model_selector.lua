-- lua/ai/model_selector.lua
-- Intelligent model selection for AI agents based on available models

local M = {}

----------------------------------------------------------------------
-- Model capability profiles
-- Each profile defines which capabilities a model is good at
----------------------------------------------------------------------
local model_profiles = {
  -- Bailian Coding models
  ["glm-5"] = {
    reasoning = 9,      -- Strong reasoning
    speed = 7,          -- Good speed
    coding = 9,         -- Excellent for code
    creativity = 7,     -- Good creativity
    context = 8,        -- Good context handling
    cost = 8,           -- Cost-effective
    tags = { "reasoning", "coding", "balanced" },
  },
  ["qwen3.5-plus"] = {
    reasoning = 8,
    speed = 8,
    coding = 8,
    creativity = 7,
    context = 7,
    cost = 8,
    tags = { "balanced", "fast" },
  },
  ["kimi-k2.5"] = {
    reasoning = 8,
    speed = 6,
    coding = 7,
    creativity = 9,     -- Excellent for creative tasks
    context = 10,       -- Very long context
    cost = 6,
    tags = { "creative", "long-context" },
  },
  ["MiniMax-M2.5"] = {
    reasoning = 7,
    speed = 9,          -- Very fast
    coding = 6,
    creativity = 6,
    context = 6,
    cost = 9,           -- Very cost-effective
    tags = { "fast", "cheap" },
  },

  -- DeepSeek models
  ["deepseek-chat"] = {
    reasoning = 8,
    speed = 7,
    coding = 8,
    creativity = 7,
    context = 7,
    cost = 8,
    tags = { "balanced" },
  },
  ["deepseek-reasoner"] = {
    reasoning = 10,     -- Best for reasoning
    speed = 5,
    coding = 7,
    creativity = 6,
    context = 6,
    cost = 6,
    tags = { "reasoning", "slow" },
  },

  -- OpenAI models
  ["gpt-4o"] = {
    reasoning = 9,
    speed = 7,
    coding = 9,
    creativity = 8,
    context = 8,
    cost = 5,
    tags = { "premium", "coding" },
  },
  ["gpt-4o-mini"] = {
    reasoning = 7,
    speed = 9,
    coding = 7,
    creativity = 6,
    context = 6,
    cost = 9,
    tags = { "fast", "cheap" },
  },
}

----------------------------------------------------------------------
-- Agent requirements
-- What each agent needs from a model
----------------------------------------------------------------------
local agent_requirements = {
  sisyphus = {
    priorities = { "coding", "reasoning", "speed" },
    min_reasoning = 7,
    min_coding = 7,
    description = "Main work agent - needs coding and reasoning",
  },
  oracle = {
    priorities = { "reasoning", "context" },
    min_reasoning = 8,
    description = "Read-only consultant - needs strong reasoning",
  },
  librarian = {
    priorities = { "speed", "reasoning" },
    min_speed = 7,
    description = "Code search agent - needs fast responses",
  },
  explore = {
    priorities = { "speed", "cost" },
    min_speed = 8,
    description = "Codebase exploration - needs speed and low cost",
  },
  ["multimodal-looker"] = {
    priorities = { "reasoning", "creativity" },
    min_reasoning = 7,
    description = "Image/document analysis",
  },
  prometheus = {
    priorities = { "reasoning", "context" },
    min_reasoning = 8,
    min_context = 7,
    description = "Plan builder - needs reasoning and context",
  },
  metis = {
    priorities = { "reasoning" },
    min_reasoning = 9,
    description = "Pre-planning consultant - needs strong reasoning",
  },
  momus = {
    priorities = { "reasoning" },
    min_reasoning = 9,
    description = "Reviewer - needs critical thinking",
  },
  atlas = {
    priorities = { "coding", "reasoning", "speed" },
    min_coding = 8,
    min_reasoning = 7,
    description = "Executor - needs coding and speed",
  },
}

----------------------------------------------------------------------
-- Category requirements
----------------------------------------------------------------------
local category_requirements = {
  ["visual-engineering"] = {
    priorities = { "creativity", "reasoning" },
    min_creativity = 7,
    description = "Frontend, UI/UX, design",
  },
  ultrabrain = {
    priorities = { "reasoning" },
    min_reasoning = 9,
    description = "Hard logic tasks",
  },
  quick = {
    priorities = { "speed", "cost" },
    min_speed = 8,
    description = "Trivial tasks",
  },
  ["unspecified-low"] = {
    priorities = { "speed", "cost" },
    min_speed = 7,
    description = "Low effort tasks",
  },
  ["unspecified-high"] = {
    priorities = { "reasoning", "coding" },
    min_reasoning = 7,
    description = "High effort tasks",
  },
  writing = {
    priorities = { "creativity", "context" },
    min_creativity = 7,
    description = "Documentation, prose",
  },
}

----------------------------------------------------------------------
-- Score a model for a requirement
----------------------------------------------------------------------
local function score_model(model_name, requirement)
  local profile = model_profiles[model_name]
  if not profile then
    return 0
  end

  local score = 0
  local priorities = requirement.priorities or {}

  -- Weight by priorities
  for i, prio in ipairs(priorities) do
    local weight = 10 - i  -- First priority gets 10, second gets 9, etc.
    score = score + (profile[prio] or 5) * weight
  end

  -- Check minimum requirements
  for key, min_val in pairs(requirement) do
    if key:match("^min_") then
      local attr = key:gsub("^min_", "")
      if profile[attr] and profile[attr] < min_val then
        score = score * 0.5  -- Penalty for not meeting minimum
      end
    end
  end

  return score
end

----------------------------------------------------------------------
-- Get available models from provider config
----------------------------------------------------------------------
function M.get_available_models(provider_config)
  local models = {}

  for provider_name, provider_def in pairs(provider_config or {}) do
    if provider_def.models then
      for model_name, model_def in pairs(provider_def.models) do
        table.insert(models, {
          name = model_name,
          provider = provider_name,
          id = model_name,
        })
      end
    end
  end

  return models
end

----------------------------------------------------------------------
-- Select best model for an agent
----------------------------------------------------------------------
function M.select_for_agent(agent_name, available_models)
  local requirement = agent_requirements[agent_name]
  if not requirement then
    -- Default to balanced model
    return available_models[1] and available_models[1].name
  end

  local best_model = nil
  local best_score = -1

  for _, model in ipairs(available_models) do
    local score = score_model(model.name, requirement)
    if score > best_score then
      best_score = score
      best_model = model.name
    end
  end

  return best_model
end

----------------------------------------------------------------------
-- Select best model for a category
----------------------------------------------------------------------
function M.select_for_category(category_name, available_models)
  local requirement = category_requirements[category_name]
  if not requirement then
    return available_models[1] and available_models[1].name
  end

  local best_model = nil
  local best_score = -1

  for _, model in ipairs(available_models) do
    local score = score_model(model.name, requirement)
    if score > best_score then
      best_score = score
      best_model = model.name
    end
  end

  return best_model
end

----------------------------------------------------------------------
-- Generate optimal OMO config
----------------------------------------------------------------------
function M.generate_omo_config(available_models, default_provider)
  -- If available_models is a string (provider name), get models from config
  if type(available_models) == "string" then
    local Resolver = require("ai.config_resolver")
    local providers = Resolver.build_provider_config()
    available_models = M.get_available_models(providers)
  end

  -- Fallback to default if no models
  if not available_models or #available_models == 0 then
    return {
      agents = {},
      categories = {},
    }
  end

  local config = {
    agents = {},
    categories = {},
  }

  -- Select models for each agent
  for agent_name, _ in pairs(agent_requirements) do
    local model = M.select_for_agent(agent_name, available_models)
    if model then
      config.agents[agent_name] = { model = model }
    end
  end

  -- Select models for each category
  for category_name, _ in pairs(category_requirements) do
    local model = M.select_for_category(category_name, available_models)
    if model then
      config.categories[category_name] = { model = model }
    end
  end

  return config
end

----------------------------------------------------------------------
-- Get model recommendations with explanations
----------------------------------------------------------------------
function M.get_recommendations(available_models)
  local recommendations = {
    agents = {},
    categories = {},
  }

  for agent_name, req in pairs(agent_requirements) do
    local model = M.select_for_agent(agent_name, available_models)
    recommendations.agents[agent_name] = {
      model = model,
      reason = req.description,
      priorities = req.priorities,
    }
  end

  for category_name, req in pairs(category_requirements) do
    local model = M.select_for_category(category_name, available_models)
    recommendations.categories[category_name] = {
      model = model,
      reason = req.description,
      priorities = req.priorities,
    }
  end

  return recommendations
end

return M
