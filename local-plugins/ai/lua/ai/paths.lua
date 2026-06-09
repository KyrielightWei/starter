-- lua/ai/paths.lua
-- 统一路径解析模块
--
-- 集中管理所有模板和配置文件的路径解析，替代各模块中分散的
-- stdpath("config") 调用。通过 setup(opts) 接受 template_dir 配置。

local M = {}

local config = {
  template_dir = nil, -- 延迟初始化
}

-- 获取 template_dir（延迟初始化，避免模块加载时 stdpath 不可用）
local function get_template_dir()
  if not config.template_dir then
    config.template_dir = vim.fn.stdpath("config")
  end
  return config.template_dir
end

-- 路径拼接
local function path_join(...)
  return table.concat({ ... }, "/"):gsub("//+", "/")
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

-- 路径拼接（供其他模块复用）
M.join = path_join

-- 初始化路径模块
-- @param opts table: { template_dir = string? }
function M.setup(opts)
  opts = opts or {}
  if opts.template_dir then
    config.template_dir = opts.template_dir
  end
end

-- 返回配置的 template_dir
-- @return string
function M.config_dir()
  return get_template_dir()
end

-- 版本化 settings 模板路径
-- 例如: <template_dir>/templates/pi/default.template.jsonc
-- @param tool string: 工具名称 (pi, opencode, claude_code)
-- @param version string?: 版本名称，默认 "default"
-- @return string
function M.settings_template(tool, version)
  version = version or "default"
  return path_join(get_template_dir(), "templates", tool, version .. ".template.jsonc")
end

-- Legacy 模板路径（根目录下的单文件模板）
-- 例如: <template_dir>/opencode.template.jsonc
-- @param tool string: 工具名称
-- @return string
function M.legacy_template(tool)
  return path_join(get_template_dir(), tool .. ".template.jsonc")
end

-- 仓库资源文件路径（pi/ 目录下的模板和资源）
-- 例如: <template_dir>/pi/AGENTS.template.md
-- @param rel string: 相对于 template_dir 的路径
-- @return string
function M.resource(rel)
  return path_join(get_template_dir(), rel)
end

-- ccstatusline 模板路径
-- @return string
function M.ccstatusline_template()
  return path_join(get_template_dir(), "ccstatusline.template.jsonc")
end

-- 模板目录路径
-- @param tool string?: 工具名称，不传则返回 templates/ 根目录
-- @return string
function M.templates_dir(tool)
  if tool then
    return path_join(get_template_dir(), "templates", tool)
  end
  return path_join(get_template_dir(), "templates")
end

return M
