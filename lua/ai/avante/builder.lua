-- lua/ai/avante/builder.lua
-- Avante 构建管理器
-- 提供优雅的构建提示和进度显示

local M = {}

----------------------------------------------------------------------
-- 平台检测
----------------------------------------------------------------------
local PLATFORM_EXTS = {
  Linux = "so",
  Darwin = "dylib",
  Windows = "dll",
}

local function get_platform_ext()
  local os_name = vim.uv.os_uname().sysname
  return PLATFORM_EXTS[os_name] or "so"
end

----------------------------------------------------------------------
-- get_binary_files(): 获取所有编译产物（跨平台）
----------------------------------------------------------------------
local function get_binary_files(build_dir)
  local files = {}
  for _, ext in pairs(PLATFORM_EXTS) do
    local matches = vim.fn.glob(build_dir .. "/*." .. ext, false, true)
    vim.list_extend(files, matches)
  end
  return files
end

-- 构建状态
local build_status = {
  checked = false,
  needs_build = false,
  building = false,
  prompt_shown = false,
}

----------------------------------------------------------------------
-- check_built(): 检查 avante 是否已构建
----------------------------------------------------------------------
function M.check_built()
  local avante_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
  local templates_path = avante_path .. "/avante_templates"

  -- 检查模板目录
  if vim.fn.isdirectory(templates_path) == 1 then
    return true
  end

  -- 检查编译产物（跨平台）
  local build_dir = avante_path .. "/build"
  if vim.fn.isdirectory(build_dir) == 1 then
    local files = get_binary_files(build_dir)
    return #files > 0
  end

  return false
end

----------------------------------------------------------------------
-- build_async(): 异步构建
----------------------------------------------------------------------
function M.build_async(callback)
  if build_status.building then
    vim.notify("⏳ Avante 正在构建中，请稍候...", vim.log.levels.INFO)
    return
  end
  
  build_status.building = true
  
  local avante_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
  local build_cmd = "cd " .. avante_path .. " && make"
  
  -- 创建进度 buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "avante-build-log")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "╔══════════════════════════════════════════════════════════════╗",
    "║            Avante.nvim 构建日志                              ║",
    "╚══════════════════════════════════════════════════════════════╝",
    "",
    "⏳ 正在构建... 这可能需要 2-5 分钟",
    "",
  })
  
  -- 在浮动窗口显示
  local width = 70
  local height = 20
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Avante Build ",
    title_pos = "center",
  })
  
  vim.notify("🚀 开始构建 Avante...", vim.log.levels.INFO)
  
  -- 使用 vim.fn.jobstart 异步执行
  local line_count = 6
  local job_id = vim.fn.jobstart(build_cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            line_count = line_count + 1
            pcall(vim.api.nvim_buf_set_lines, buf, line_count - 1, line_count, false, { line })
            -- 自动滚动到底部
            pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" and (line:find("error") or line:find("Error") or line:find("warning")) then
            line_count = line_count + 1
            pcall(vim.api.nvim_buf_set_lines, buf, line_count - 1, line_count, false, { "⚠️ " .. line })
          end
        end
      end
    end,
    on_exit = function(_, code)
      build_status.building = false
      
      vim.schedule(function()
        if code == 0 then
          pcall(vim.api.nvim_buf_set_lines, buf, line_count, line_count + 1, false, {
            "",
            "══════════════════════════════════════════════════════════════",
            "✅ 构建成功！",
            "══════════════════════════════════════════════════════════════",
          })
          vim.notify("✅ Avante 构建成功！", vim.log.levels.INFO)
          build_status.needs_build = false
          
          -- 3秒后关闭窗口
          vim.defer_fn(function()
            pcall(vim.api.nvim_win_close, win, true)
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end, 3000)
          
          if callback then callback(true) end
        else
          pcall(vim.api.nvim_buf_set_lines, buf, line_count, line_count + 1, false, {
            "",
            "══════════════════════════════════════════════════════════════",
            "❌ 构建失败，退出码: " .. code,
            "══════════════════════════════════════════════════════════════",
            "",
            "请检查上方日志，或手动运行：",
            "  cd ~/.local/share/nvim/lazy/avante.nvim",
            "  LUA_VERSION=luajit bash ./build.sh",
          })
          vim.notify("❌ Avante 构建失败", vim.log.levels.ERROR)
          if callback then callback(false) end
        end
      end)
    end,
  })
  
  if job_id <= 0 then
    build_status.building = false
    pcall(vim.api.nvim_win_close, win, true)
    vim.notify("❌ 无法启动构建进程", vim.log.levels.ERROR)
  end
end

----------------------------------------------------------------------
-- prompt_build(): 弹出对话框询问是否构建
----------------------------------------------------------------------
function M.prompt_build(callback)
  -- 避免重复弹出
  if build_status.prompt_shown then
    if callback then callback(false) end
    return
  end
  
  build_status.prompt_shown = true
  
  vim.ui.select(
    { "🚀 立即构建（推荐）", "⏭️  跳过构建" },
    {
      prompt = "\n┌─────────────────────────────────────────────────────────┐\n" ..
               "│  Avante.nvim 需要构建才能正常使用                        │\n" ..
               "│  构建大约需要 2-5 分钟，完成后即可使用所有功能            │\n" ..
               "└─────────────────────────────────────────────────────────┘\n",
      format_item = function(item) return item end,
    },
    function(choice, idx)
      if idx == 1 then
        M.build_async(callback)
      else
        build_status.needs_build = true
        vim.notify(
          "ℹ️ 已跳过构建。AI 聊天功能将不可用。\n" ..
          "稍后可运行 :AvanteBuild 来构建。",
          vim.log.levels.WARN
        )
        if callback then callback(false) end
      end
    end
  )
end

----------------------------------------------------------------------
-- wrap_function(): 包装需要构建的功能
----------------------------------------------------------------------
function M.wrap_function(fn, fn_name)
  return function()
    -- 如果正在构建，提示等待
    if build_status.building then
      vim.notify("⏳ Avante 正在构建中，请稍候...", vim.log.levels.INFO)
      return
    end
    
    -- 如果未构建且未询问过，弹出选择
    if not M.check_built() and not build_status.checked then
      build_status.checked = true
      M.prompt_build(function(built)
        if built then
          fn()
        end
      end)
      return
    end
    
    -- 如果已标记需要构建但未构建
    if not M.check_built() then
      M.prompt_build(function(built)
        if built then
          fn()
        end
      end)
      return
    end
    
    -- 已构建，执行函数
    local ok, err = pcall(fn)
    if not ok then
      if tostring(err):find("NEED_BUILD") or tostring(err):find("avante_templates") then
        M.prompt_build(function(built)
          if built then fn() end
        end)
      else
        vim.notify("❌ " .. fn_name .. " 失败: " .. tostring(err), vim.log.levels.ERROR)
      end
    end
  end
end

----------------------------------------------------------------------
-- get_status(): 获取构建状态
----------------------------------------------------------------------
function M.get_status()
  return {
    built = M.check_built(),
    building = build_status.building,
    needs_build = build_status.needs_build,
  }
end

----------------------------------------------------------------------
-- get_binaries(): 获取编译产物列表（跨平台）
-- @return table: 二进制文件路径列表
----------------------------------------------------------------------
function M.get_binaries()
  local avante_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
  local build_dir = avante_path .. "/build"
  if vim.fn.isdirectory(build_dir) == 1 then
    return get_binary_files(build_dir)
  end
  return {}
end

----------------------------------------------------------------------
-- get_platform_ext(): 获取当前平台的二进制扩展名
----------------------------------------------------------------------
M.get_platform_ext = get_platform_ext

----------------------------------------------------------------------
-- 用户命令
----------------------------------------------------------------------
vim.api.nvim_create_user_command("AvanteBuild", function()
  M.build_async()
end, { desc = "Build Avante.nvim" })

vim.api.nvim_create_user_command("AvanteBuildStatus", function()
  local status = M.get_status()
  local msg = string.format(
    "Avante 构建状态:\n  已构建: %s\n  正在构建: %s\n  需要构建: %s",
    status.built and "✅" or "❌",
    status.building and "⏳" or "否",
    status.needs_build and "是" or "否"
  )
  vim.notify(msg, vim.log.levels.INFO)
end, { desc = "Show Avante build status" })

return M
