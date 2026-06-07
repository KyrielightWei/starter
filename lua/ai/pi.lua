-- lua/ai/pi.lua
-- Pi coding agent 集成：配置生成、资源同步、状态检查

local M = {}

local JsonUtil = require("ai.json_util")
local Providers = require("ai.providers")
local Keys = require("ai.keys")

local format_json = JsonUtil.format_json
local parse_jsonc_file = JsonUtil.parse_jsonc_file
local strip_jsonc_comments = JsonUtil.strip_jsonc_comments
local tbl_is_array = JsonUtil.tbl_is_array

local UNION_ARRAY_KEYS = {
  packages = true,
  skills = true,
  prompts = true,
  extensions = true,
  themes = true,
}

local DEFAULT_PI_EXECUTABLE = "pi"

local function expand(path)
  return vim.fn.expand(path)
end

local function default_repo_root()
  return vim.fn.stdpath("config")
end

local function get_repo_root(opts)
  return opts and opts.repo_root or default_repo_root()
end

local function get_config_dir(opts)
  return opts and opts.config_dir or vim.fn.stdpath("config")
end

local function get_pi_dir(opts)
  return opts and opts.pi_dir or expand("~/.pi/agent")
end

local function path_join(...)
  return table.concat({ ... }, "/"):gsub("//+", "/")
end

local function ensure_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

local function read_file(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  return table.concat(vim.fn.readfile(path), "\n")
end

local function write_text(path, content)
  ensure_dir(vim.fn.fnamemodify(path, ":h"))
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)
end

local function write_json(path, value)
  write_text(path, format_json(value) .. "\n")
end

local function read_json(path)
  local content = read_file(path)
  if not content then
    return nil, "not found"
  end

  local ok, parsed = pcall(vim.json.decode, content)
  if not ok then
    return nil, tostring(parsed)
  end
  return parsed, nil
end

local function now_suffix(opts)
  return tostring((opts and opts.now) or os.time())
end

local function backup_file(path, opts)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local backup_path = path .. ".bak." .. now_suffix(opts)
  vim.fn.writefile(vim.fn.readfile(path), backup_path)
  return backup_path
end

local function read_jsonc(path)
  local parsed, err = parse_jsonc_file(path)
  if parsed then
    return parsed
  end
  error(err or ("Failed to parse " .. path))
end

local function union_array(template_value, existing_value)
  local out = {}
  local seen = {}

  local function add_all(values)
    if type(values) ~= "table" then
      return
    end
    for _, value in ipairs(values) do
      local key = type(value) == "table" and vim.json.encode(value) or tostring(value)
      if not seen[key] then
        seen[key] = true
        table.insert(out, vim.deepcopy(value))
      end
    end
  end

  add_all(template_value)
  add_all(existing_value)
  return out
end

local function conservative_merge(template_value, existing_value, key)
  if existing_value == nil then
    return vim.deepcopy(template_value)
  end
  if template_value == nil then
    return vim.deepcopy(existing_value)
  end

  if UNION_ARRAY_KEYS[key] and tbl_is_array(template_value) and tbl_is_array(existing_value) then
    return union_array(template_value, existing_value)
  end

  if type(template_value) == "table" and type(existing_value) == "table" then
    if tbl_is_array(template_value) or tbl_is_array(existing_value) then
      return vim.deepcopy(existing_value)
    end

    local result = {}
    for k, v in pairs(template_value) do
      result[k] = conservative_merge(v, existing_value[k], k)
    end
    for k, v in pairs(existing_value) do
      if result[k] == nil then
        result[k] = vim.deepcopy(v)
      end
    end
    return result
  end

  return vim.deepcopy(existing_value)
end

local function read_existing_for_merge(path, opts)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local parsed, err = read_json(path)
  if parsed then
    return parsed
  end

  backup_file(path, opts)
  if not (opts and opts.silent) then
    vim.notify("Pi JSON 配置损坏，已备份: " .. path .. " (" .. tostring(err) .. ")", vim.log.levels.WARN)
  end
  return nil
end

local function write_merged_json(path, generated, opts)
  local existing = read_existing_for_merge(path, opts)
  local final = existing and conservative_merge(generated, existing) or generated
  write_json(path, final)
  return final
end

local function template_version_path(opts)
  local version = (opts and opts.version)
  if not version then
    local ok_state, State = pcall(require, "ai.state")
    version = ok_state and State.get_template_version("pi") or "default"
  end
  version = version or "default"

  return path_join(get_config_dir(opts), "templates/pi", version .. ".template.jsonc")
end

local function legacy_settings_template_path(opts)
  return path_join(get_repo_root(opts), "pi.template.jsonc")
end

local function resolve_settings_template_path(opts)
  local versioned = template_version_path(opts)
  if vim.fn.filereadable(versioned) == 1 then
    return versioned
  end
  return legacy_settings_template_path(opts)
end

local function repo_template_path(opts, rel)
  return path_join(get_repo_root(opts), rel)
end

local function pi_target_path(opts, rel)
  return path_join(get_pi_dir(opts), rel)
end

function M.generate_settings(opts)
  opts = opts or {}
  local path = resolve_settings_template_path(opts)
  return read_jsonc(path)
end

local function model_limit_for(provider_def, model_id)
  local info = provider_def.model_info and provider_def.model_info[model_id]
  local limit = info and info.limit or {}
  return {
    contextWindow = limit.context or 200000,
    maxTokens = limit.output or 8192,
  }
end

local function model_entry(provider_def, model_id)
  local limits = model_limit_for(provider_def, model_id)
  local entry = {
    id = model_id,
    name = model_id,
    contextWindow = limits.contextWindow,
    maxTokens = limits.maxTokens,
    cost = {
      input = 0,
      output = 0,
      cacheRead = 0,
      cacheWrite = 0,
    },
  }

  local info = provider_def.model_info and provider_def.model_info[model_id]
  if info and info.description then
    entry.description = info.description
  end

  return entry
end

local function provider_api_key_name(provider_def)
  return provider_def.api_key_name or "OPENAI_API_KEY"
end

function M.generate_models(opts)
  opts = opts or {}
  local base_path = repo_template_path(opts, "pi/models.template.jsonc")
  local models = vim.fn.filereadable(base_path) == 1 and read_jsonc(base_path) or { providers = {} }
  models.providers = models.providers or {}

  for _, provider_name in ipairs(Providers.list()) do
    local provider_def = Providers.get(provider_name)
    if provider_def and provider_def.endpoint then
      local endpoint = Keys.get_base_url(provider_name)
      local provider_models = vim.deepcopy(provider_def.static_models or {})
      if provider_def.model and not vim.tbl_contains(provider_models, provider_def.model) then
        table.insert(provider_models, provider_def.model)
      end

      local model_entries = {}
      for _, model_id in ipairs(provider_models) do
        table.insert(model_entries, model_entry(provider_def, model_id))
      end

      models.providers[provider_name] = {
        name = provider_name:gsub("_", " "):gsub("(%l)(%w*)", function(a, b)
          return string.upper(a) .. b
        end),
        baseUrl = endpoint,
        api = "openai-completions",
        apiKey = provider_api_key_name(provider_def),
        models = model_entries,
      }
    end
  end

  return models
end

local function simple_hash(content)
  if vim.fn.exists("*sha256") == 1 then
    return vim.fn.sha256(content)
  end

  local hash = 5381
  for i = 1, #content do
    hash = ((hash * 33) + content:byte(i)) % 4294967296
  end
  return string.format("%08x", hash)
end

local function manifest_path(opts)
  return pi_target_path(opts, ".starter-sync-manifest.json")
end

local function load_manifest(opts)
  local path = manifest_path(opts)
  local parsed = read_json(path)
  if type(parsed) == "table" then
    parsed.files = parsed.files or {}
    return parsed
  end
  return { version = 1, files = {} }
end

local function save_manifest(opts, manifest)
  write_json(manifest_path(opts), manifest)
end

local function add_mapping(mappings, source, relative)
  if vim.fn.filereadable(source) == 1 then
    table.insert(mappings, {
      source = source,
      relative = relative,
      target = nil,
    })
  end
end

local function add_template_files(mappings, glob_pattern, source_prefix, target_prefix, source_suffix, target_suffix)
  local files = vim.fn.glob(glob_pattern, false, true) or {}
  table.sort(files)
  for _, source in ipairs(files) do
    local rel = source:sub(#source_prefix + 2)
    if rel:sub(-#source_suffix) == source_suffix then
      local stem = rel:sub(1, #rel - #source_suffix)
      table.insert(mappings, {
        source = source,
        relative = path_join(target_prefix, stem .. target_suffix),
      })
    end
  end
end

local function collect_skill_files(mappings, skill_root, relative_root)
  local files = vim.fn.glob(skill_root .. "/**/*", false, true) or {}
  table.sort(files)
  for _, source in ipairs(files) do
    if vim.fn.filereadable(source) == 1 then
      local rel = source:sub(#skill_root + 2)
      table.insert(mappings, {
        source = source,
        relative = path_join(relative_root, rel),
      })
    end
  end
end

function M.collect_resource_mappings(opts)
  opts = opts or {}
  local repo_root = get_repo_root(opts)
  local mappings = {}

  add_mapping(mappings, path_join(repo_root, "pi/AGENTS.template.md"), "AGENTS.md")
  add_template_files(
    mappings,
    path_join(repo_root, "pi/extensions/*.template.ts"),
    path_join(repo_root, "pi/extensions"),
    "extensions",
    ".template.ts",
    ".ts"
  )
  add_template_files(
    mappings,
    path_join(repo_root, "pi/extensions/*/*.template.ts"),
    path_join(repo_root, "pi/extensions"),
    "extensions",
    ".template.ts",
    ".ts"
  )
  add_template_files(
    mappings,
    path_join(repo_root, "pi/prompts/*.template.md"),
    path_join(repo_root, "pi/prompts"),
    "prompts",
    ".template.md",
    ".md"
  )

  collect_skill_files(mappings, path_join(repo_root, "pi/skills/openspec"), "skills/openspec")

  for _, item in ipairs(mappings) do
    item.target = pi_target_path(opts, item.relative)
  end

  return mappings
end

local function sync_resource(item, manifest, opts)
  local source_content = read_file(item.source)
  if not source_content then
    return { skipped = true, reason = "missing source" }
  end

  local source_hash = simple_hash(source_content)
  local previous = manifest.files[item.relative]
  local target_content = read_file(item.target)

  if target_content then
    local target_hash = simple_hash(target_content)
    if previous and previous.hash and target_hash ~= previous.hash and target_hash ~= source_hash then
      backup_file(item.target, opts)
    end
    if target_hash == source_hash then
      manifest.files[item.relative] = {
        source = item.source,
        hash = source_hash,
        synced_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }
      return { unchanged = true }
    end
  end

  write_text(item.target, source_content)
  manifest.files[item.relative] = {
    source = item.source,
    hash = source_hash,
    synced_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  return { written = true }
end

local function sync_resources(opts)
  local manifest = load_manifest(opts)
  local summary = { written = 0, unchanged = 0, skipped = 0 }

  for _, item in ipairs(M.collect_resource_mappings(opts)) do
    local result = sync_resource(item, manifest, opts)
    if result.written then
      summary.written = summary.written + 1
    elseif result.unchanged then
      summary.unchanged = summary.unchanged + 1
    else
      summary.skipped = summary.skipped + 1
    end
  end

  save_manifest(opts, manifest)
  return summary
end

local function write_theme(opts)
  local template_path = repo_template_path(opts, "pi/theme.template.jsonc")
  if vim.fn.filereadable(template_path) == 0 then
    return nil
  end

  local theme = read_jsonc(template_path)
  local name = theme.name or "theme"
  local target = pi_target_path(opts, "themes/" .. name .. ".json")
  write_merged_json(target, theme, opts)
  return target
end

function M.write_config(opts)
  opts = opts or {}
  ensure_dir(get_pi_dir(opts))
  ensure_dir(pi_target_path(opts, "themes"))
  ensure_dir(pi_target_path(opts, "extensions"))
  ensure_dir(pi_target_path(opts, "prompts"))
  ensure_dir(pi_target_path(opts, "skills"))

  local settings = M.generate_settings(opts)
  local models = M.generate_models(opts)
  local keybindings = read_jsonc(repo_template_path(opts, "pi/keybindings.template.jsonc"))

  write_merged_json(pi_target_path(opts, "settings.json"), settings, opts)
  write_merged_json(pi_target_path(opts, "models.json"), models, opts)
  write_merged_json(pi_target_path(opts, "keybindings.json"), keybindings, opts)
  write_theme(opts)
  local resource_summary = sync_resources(opts)

  if not opts.silent then
    vim.notify(
      string.format(
        "✅ Pi config synced to %s\nResources: %d written, %d unchanged",
        get_pi_dir(opts),
        resource_summary.written,
        resource_summary.unchanged
      ),
      vim.log.levels.INFO
    )
  end

  return true
end

local function required_packages(opts)
  local settings = M.generate_settings(opts)
  return settings.packages or {}
end

local function installed_packages(opts)
  local exe = (opts and opts.pi_executable) or DEFAULT_PI_EXECUTABLE
  if vim.fn.executable(exe) ~= 1 then
    return {}
  end

  local output = vim.fn.system(exe .. " list 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local installed = {}
  for line in output:gmatch("[^\n]+") do
    for _, pkg in ipairs(required_packages(opts)) do
      if line:find(pkg, 1, true) then
        installed[pkg] = true
      end
    end
  end
  return installed
end

local function missing_packages(opts)
  local installed = installed_packages(opts)
  local missing = {}
  for _, pkg in ipairs(required_packages(opts)) do
    if not installed[pkg] then
      table.insert(missing, pkg)
    end
  end
  return missing
end

function M.check_installation(opts)
  opts = opts or {}
  local exe = opts.pi_executable or DEFAULT_PI_EXECUTABLE
  if vim.fn.executable(exe) == 1 then
    return true, "Pi CLI is installed"
  end
  return false, "Pi CLI is not installed"
end

function M.get_status(opts)
  opts = opts or {}
  local installed, message = M.check_installation(opts)
  local settings_path = pi_target_path(opts, "settings.json")
  local manifest = load_manifest(opts)

  return {
    installed = installed,
    message = message,
    config_exists = vim.fn.filereadable(settings_path) == 1,
    config_path = settings_path,
    pi_dir = get_pi_dir(opts),
    manifest_path = manifest_path(opts),
    managed_files = vim.tbl_count(manifest.files or {}),
    missing_packages = missing_packages(opts),
    install_hints = vim.tbl_map(function(pkg)
      return "pi install " .. pkg
    end, missing_packages(opts)),
  }
end

function M.preview_config(opts)
  opts = opts or {}
  local preview = {
    settings = M.generate_settings(opts),
    models = M.generate_models(opts),
    resources = vim.tbl_map(function(item)
      return item.relative
    end, M.collect_resource_mappings(opts)),
    missing_packages = missing_packages(opts),
  }

  local lines = vim.split(format_json(preview), "\n")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "json", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_buf_set_name(buf, "Pi Config Preview")
  vim.api.nvim_win_set_buf(0, buf)
  return preview
end

function M.edit_template(opts)
  opts = opts or {}
  local path = resolve_settings_template_path(opts)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

function M.show_status(opts)
  local status = M.get_status(opts)
  local lines = {
    "Pi:",
    "  CLI: " .. (status.installed and "installed" or "missing"),
    "  Config: " .. (status.config_exists and status.config_path or "missing"),
    "  Managed files: " .. tostring(status.managed_files),
  }
  if #status.missing_packages > 0 then
    table.insert(lines, "  Missing packages:")
    for _, pkg in ipairs(status.missing_packages) do
      table.insert(lines, "    - " .. pkg)
    end
  end
  vim.notify(table.concat(lines, "\n"), status.installed and vim.log.levels.INFO or vim.log.levels.WARN)
end

return M
