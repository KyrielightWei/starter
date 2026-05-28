-- Helper function to get project root directory
-- 比 LazyVim 默认 root 检测多识别 C/C++ 构建文件
local function get_project_root()
  local start_dir = ""
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" then
    start_dir = vim.fs.dirname(bufname)
  else
    start_dir = vim.loop.cwd()
  end

  local root_markers = {
    ".git",
    "Makefile",
    "configure.ac",
    "configure.in",
    "config.h.in",
    "meson.build",
    "meson_options.txt",
    "build.ninja",
    "compile_commands.json",
    "compile_flags.txt",
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "go.mod",
  }

  local match = vim.fs.find(root_markers, { path = start_dir, upward = true })[1]
  if not match then
    return vim.loop.cwd()
  else
    return vim.fs.dirname(match)
  end
end

return {
  {
    "ibhagwan/fzf-lua",
    keys = {
      { "<leader>so", "<cmd>FzfLua treesitter<CR>", desc = "Treesitter symbols" },
      {
        "<leader>sg",
        function()
          require("fzf-lua").live_grep({ cwd = get_project_root() })
        end,
        desc = "Search in project (grep)",
      },
    },
  },
}
