-- lua/plugins/skill_studio.lua
-- Skill Studio - loaded as local module

vim.defer_fn(function()
  local ok, SkillStudio = pcall(require, "ai.skill_studio")
  if ok then
    SkillStudio.setup()
  end
end, 100)