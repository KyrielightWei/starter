-- ============================================================================
-- Diffview Git 配置模块
-- 功能：
--   1. 自动检测 Git 版本，低于 2.31 时弹出警告
--   2. 支持自定义 git 可执行文件路径（本地保存）
--   3. 支持 Git Worktree
-- ============================================================================

-- 本地配置文件路径（仅当前机器生效）
local LOCAL_CONFIG_PATH = vim.fn.expand("~/.local/state/nvim/diffview_local.lua")

-- 最小 Git 版本要求
local MIN_GIT_MAJOR, MIN_GIT_MINOR = 2, 31

-- 本地配置缓存
local local_config = nil

---验证路径是否安全（防止命令注入）
---@param path string
---@return boolean
local function is_safe_path(path)
  -- 禁止 shell 元字符
  if path:match("[;&|`$%[%]%(%){}]") then
    return false
  end
  -- 禁止路径遍历
  if path:match("%.%.") then
    return false
  end
  return true
end

---加载本地配置
---@return table
local function load_local_config()
  if local_config ~= nil then
    return local_config
  end

  local config = { git_path = nil }
  local stat = vim.loop.fs_stat(LOCAL_CONFIG_PATH)
  if stat then
    local ok, data = pcall(dofile, LOCAL_CONFIG_PATH)
    if ok and type(data) == "table" then
      config = vim.tbl_deep_extend("force", config, data)
    end
  end
  local_config = config
  return config
end

---保存本地配置
---@param config table
local function save_local_config(config)
  local_config = config
  local dir = vim.fn.fnamemodify(LOCAL_CONFIG_PATH, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  local file = io.open(LOCAL_CONFIG_PATH, "w")
  if file then
    file:write("return " .. vim.inspect(config))
    file:close()
  end
end

---解析 Git 版本号
---@param git_path string
---@return number|nil major, number|nil minor, number|nil patch
local function parse_git_version(git_path)
  -- 安全检查：防止命令注入
  if not is_safe_path(git_path) then
    return nil, nil, nil
  end

  local handle = io.popen(vim.fn.shellescape(git_path) .. " --version 2>/dev/null")
  if not handle then
    return nil, nil, nil
  end
  local output = handle:read("*a")
  handle:close()

  -- git version 2.17.0 或 git version 2.47.1
  local major, minor, patch = output:match("git version (%d+)%.(%d+)%.(%d+)")
  if major then
    return tonumber(major), tonumber(minor), tonumber(patch)
  end
  return nil, nil, nil
end

---检查 Git 版本是否满足要求
---@param git_path string
---@return boolean
local function check_git_version(git_path)
  local major, minor = parse_git_version(git_path)
  if not major or not minor then
    return false
  end
  if major > MIN_GIT_MAJOR then
    return true
  end
  if major == MIN_GIT_MAJOR and minor >= MIN_GIT_MINOR then
    return true
  end
  return false
end

---搜索系统中的 git 可执行文件
---@return string[]
local function find_git_executables()
  local candidates = {}

  -- 常见路径
  local common_paths = {
    vim.fn.expand("~/.local/bin/git"),
    "/usr/local/bin/git",
    "/usr/bin/git",
    "/opt/homebrew/bin/git",
    "/usr/local/git/bin/git",
  }

  -- 检查常见路径
  for _, path in ipairs(common_paths) do
    if vim.fn.filereadable(path) == 1 and vim.fn.executable(path) == 1 then
      table.insert(candidates, path)
    end
  end

  -- 从 PATH 搜索
  local path_env = os.getenv("PATH") or ""
  for _, dir in ipairs(vim.split(path_env, ":")) do
    local git_path = dir .. "/git"
    if vim.fn.filereadable(git_path) == 1 then
      -- 避免重复
      if not vim.tbl_contains(candidates, git_path) then
        table.insert(candidates, git_path)
      end
    end
  end

  return candidates
end

---构建 Git 选择选项
---@param valid_candidates string[]
---@return string[] options, table[] actions
local function build_git_options(valid_candidates)
  local options = {}
  local actions = {}

  -- 已找到的合规 git
  for _, path in ipairs(valid_candidates) do
    local v_major, v_minor, v_patch = parse_git_version(path)
    local version_str = v_major and string.format("%d.%d.%d", v_major, v_minor, v_patch or 0) or "未知"
    table.insert(options, string.format("使用 %s (版本 %s)", path, version_str))
    table.insert(actions, { type = "select", path = path })
  end

  -- 自定义路径选项
  table.insert(options, "输入自定义 git 路径...")
  table.insert(actions, { type = "custom" })

  -- 跳过选项
  table.insert(options, "跳过（使用系统默认，可能无法正常工作）")
  table.insert(actions, { type = "skip" })

  return options, actions
end

---应用 Git 路径配置
---@param git_path string
local function apply_git_path(git_path)
  save_local_config({ git_path = git_path })
  vim.notify("已设置 Git 路径: " .. git_path, vim.log.levels.INFO, { title = "Diffview" })
  -- 重新加载 diffview 配置
  pcall(function()
    local dv_config = require("diffview.config")
    dv_config._config.git_cmd = { git_path }
  end)
end

---处理自定义 Git 路径输入
local function handle_custom_git_input()
  local config = load_local_config()
  vim.ui.input({
    prompt = "输入 git 可执行文件路径: ",
    completion = "file",
    default = config.git_path or vim.fn.expand("~/.local/bin/git"),
  }, function(input)
    if not input or input == "" then
      return
    end

    input = vim.fn.expand(input)

    -- 安全检查
    if not is_safe_path(input) then
      vim.notify("错误: 路径包含非法字符: " .. input, vim.log.levels.ERROR, { title = "Diffview" })
      return
    end

    if vim.fn.filereadable(input) == 1 and vim.fn.executable(input) == 1 then
      if check_git_version(input) then
        apply_git_path(input)
      else
        vim.notify("警告: " .. input .. " 版本仍不满足要求", vim.log.levels.WARN, { title = "Diffview" })
        save_local_config({ git_path = input })
      end
    else
      vim.notify("错误: 文件不存在或不可执行: " .. input, vim.log.levels.ERROR, { title = "Diffview" })
    end
  end)
end

---处理 Git 选择结果
---@param idx number
---@param actions table[]
local function handle_git_selection(idx, actions)
  if not idx then
    return
  end

  local action = actions[idx]
  if not action then
    return
  end

  if action.type == "select" then
    apply_git_path(action.path)
  elseif action.type == "custom" then
    handle_custom_git_input()
  elseif action.type == "skip" then
    save_local_config({ git_path = "git" })
    vim.notify("使用系统默认 Git", vim.log.levels.WARN, { title = "Diffview" })
  end
end

---显示 Git 版本警告和选项
---@param system_git string
local function show_git_version_warning(system_git)
  local major, minor, patch = parse_git_version(system_git)
  local current_version = major and minor and string.format("%d.%d.%d", major, minor, patch or 0) or "未知"

  local candidates = find_git_executables()
  local valid_candidates = {}
  for _, path in ipairs(candidates) do
    if check_git_version(path) then
      table.insert(valid_candidates, path)
    end
  end

  local options, actions = build_git_options(valid_candidates)

  vim.ui.select(options, {
    prompt = string.format(
      "Diffview 需要 Git >= %d.%d\n当前系统 Git 版本: %s\n请选择一个 Git 可执行文件:",
      MIN_GIT_MAJOR,
      MIN_GIT_MINOR,
      current_version
    ),
  }, function(_, idx)
    handle_git_selection(idx, actions)
  end)
end

---获取 Git 命令（包含 worktree 支持）
---@return string[]
local function get_git_cmd()
  local cwd = vim.loop.cwd()
  local git_file = cwd .. "/.git"
  local stat = vim.loop.fs_stat(git_file)

  -- 获取 git 可执行文件路径
  local config = load_local_config()
  local git_bin = config.git_path or "git"

  -- 如果 .git 是文件而非目录，说明是 worktree
  if stat and stat.type == "file" then
    local content = vim.fn.readfile(git_file)[1] or ""
    local git_dir = content:match("gitdir:%s*(.+)")
    if git_dir then
      git_dir = vim.fn.expand(git_dir)
      return { git_bin, "--git-dir=" .. git_dir, "--work-tree=" .. cwd }
    end
  end

  return { git_bin }
end

---检查并初始化 Git 配置
---@return boolean 是否可以使用
local function check_and_init_git()
  local config = load_local_config()

  -- 如果已有自定义路径，验证是否有效
  if config.git_path and config.git_path ~= "git" then
    if vim.fn.filereadable(config.git_path) == 1 and check_git_version(config.git_path) then
      return true
    end
  end

  -- 检查系统默认 git
  local system_git = "git"
  if check_git_version(system_git) then
    return true
  end

  -- 版本不满足，显示警告
  show_git_version_warning(system_git)
  return false
end

---动态更新 Diffview 的 git_cmd 配置
local function update_diffview_git_cmd()
  local git_cmd = get_git_cmd()
  local ok, dv_config = pcall(require, "diffview.config")
  if ok and dv_config._config then
    dv_config._config.git_cmd = git_cmd
  end

  -- 重置 GitAdapter 的 bootstrap 状态，让它重新检测 git
  local ok2, git_adapter = pcall(require, "diffview.vcs.adapters.git.init")
  if ok2 and git_adapter and git_adapter.bootstrap then
    git_adapter.bootstrap.done = false
    git_adapter.bootstrap.ok = false
  end
end

---重新配置 Git 路径命令
vim.api.nvim_create_user_command("DiffviewSetGit", function()
  local config = load_local_config()
  vim.ui.input({
    prompt = "输入 git 可执行文件路径: ",
    completion = "file",
    default = config.git_path or vim.fn.expand("~/.local/bin/git"),
  }, function(input)
    if not input or input == "" then
      return
    end

    input = vim.fn.expand(input)

    -- 安全检查
    if not is_safe_path(input) then
      vim.notify("错误: 路径包含非法字符: " .. input, vim.log.levels.ERROR, { title = "Diffview" })
      return
    end

    if vim.fn.filereadable(input) == 1 and vim.fn.executable(input) == 1 then
      local major, minor, patch = parse_git_version(input)
      save_local_config({ git_path = input })
      local version_str = major and string.format("%d.%d.%d", major, minor, patch or 0) or "未知"
      vim.notify("已设置 Git 路径: " .. input .. " (版本 " .. version_str .. ")", vim.log.levels.INFO, {
        title = "Diffview",
      })
      update_diffview_git_cmd()
    else
      vim.notify("错误: 文件不存在或不可执行: " .. input, vim.log.levels.ERROR, { title = "Diffview" })
    end
  end)
end, { desc = "Set custom git executable for Diffview" })

---显示当前 Git 配置
vim.api.nvim_create_user_command("DiffviewGitInfo", function()
  local config = load_local_config()
  local git_bin = config.git_path or "git"
  local major, minor, patch = parse_git_version(git_bin)
  local version_str = major and string.format("%d.%d.%d", major, minor, patch or 0) or "未知"
  local meets_requirement = check_git_version(git_bin)

  local info = string.format(
    [[
Diffview Git 配置信息:
  当前 Git: %s
  版本: %s
  要求版本: >= %d.%d
  状态: %s
  本地配置文件: %s
]],
    git_bin,
    version_str,
    MIN_GIT_MAJOR,
    MIN_GIT_MINOR,
    meets_requirement and "满足要求" or "不满足要求",
    LOCAL_CONFIG_PATH
  )
  print(info)
end, { desc = "Show Diffview git configuration" })

-- 创建增强版 DiffviewOpen 命令（在打开前动态设置 git_cmd）
vim.api.nvim_create_user_command("DiffviewOpenEnhanced", function(opts)
  update_diffview_git_cmd()
  vim.cmd("DiffviewOpen " .. (opts.args or ""))
end, { nargs = "*", desc = "DiffviewOpen with dynamic git_cmd" })

-- 创建增强版 DiffviewFileHistory 命令
vim.api.nvim_create_user_command("DiffviewFileHistoryEnhanced", function(opts)
  update_diffview_git_cmd()
  vim.cmd("DiffviewFileHistory " .. (opts.args or ""))
end, { nargs = "*", desc = "DiffviewFileHistory with dynamic git_cmd" })

-- ============================================================================
-- 插件配置
-- ============================================================================
return {
  {
    "tpope/vim-fugitive",
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewRefresh" },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpenEnhanced<cr>", desc = "Diffview Open" },
      { "<leader>gV", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
      { "<leader>gf", "<cmd>DiffviewFileHistoryEnhanced<cr>", desc = "File History" },
      { "<leader>gF", "<cmd>DiffviewFileHistoryEnhanced %<cr>", desc = "Current File History" },
    },
    opts = function()
      vim.defer_fn(function()
        check_and_init_git()
      end, 100)

      return {
        git_cmd = get_git_cmd(),
        view = {
          default = { layout = "diff2_horizontal" },
          merge_tool = { layout = "diff3_horizontal" },
          file_history = { layout = "diff2_horizontal" },
        },
        file_panel = {
          listing_style = "tree",
          tree_options = { flatten_dirs = true },
          win_config = { position = "left", width = 35 },
        },
        file_history_panel = {
          log_options = {
            git = {
              single_file = { diff_merges = "combined" },
              multi_file = { diff_merges = "first-parent" },
            },
          },
          win_config = { position = "bottom", height = 16 },
        },
        default_args = {
          DiffviewOpen = { "--untracked-files=no" },
          DiffviewFileHistory = {},
        },
        hooks = {
          diffview_buf_read = function(bufnr)
            -- 禁用 LSP 以避免启动多个 ccls 索引
            -- Diffview 会创建两个 buffer (a/b)，每个都会触发 LSP
            vim.b[bufnr].lsp_enabled = false
            vim.diagnostic.enable(false, { bufnr = bufnr })

            local opts = { buffer = bufnr, silent = true, noremap = true }

            vim.keymap.set("n", "<Tab>", "]c", vim.tbl_extend("force", opts, { desc = "Next Hunk" }))
            vim.keymap.set("n", "<S-Tab>", "[c", vim.tbl_extend("force", opts, { desc = "Prev Hunk" }))
            vim.keymap.set("n", "]h", "]c", vim.tbl_extend("force", opts, { desc = "Next Hunk" }))
            vim.keymap.set("n", "[h", "[c", vim.tbl_extend("force", opts, { desc = "Prev Hunk" }))

            vim.keymap.set("n", "?", function()
              local help_text = [[
Diffview 快捷键速查:

导航:
  Tab / ]h     下一个 Hunk
  S-Tab / [h   上一个 Hunk
  j/k          文件列表上下移动
  <cr>         打开选中文件

Diff 操作 (Vim 原生):
  dp           Diff Put (推送到另一侧)
  do           Diff Obtain (拉取到当前)

Git 操作 (需要 gitsigns):
  <leader>ghs  Stage Hunk (暂存当前块)
  <leader>ghr  Reset Hunk (还原当前块)

文件树操作:
  s            Stage 文件
  u            Unstage 文件
  X            Restore 文件 (放弃修改)

其他:
  <leader>gV   关闭 Diffview
]]
              vim.notify(help_text, vim.log.levels.INFO, { title = "Diffview Help" })
            end, opts)
          end,
        },
      }
    end,
  },
}
