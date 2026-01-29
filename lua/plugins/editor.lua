-- Helper function to get project root directory
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
    -- If no root marker found, use current working directory
    return vim.loop.cwd()
  else
    return vim.fs.dirname(match)
  end
end

return {
  {
    "ibhagwan/fzf-lua",
    keys = {
      { "<leader>so", "<cmd>FzfLua treesitter<CR>", desc = "treesitter" },
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      {
        "<leader>sg",
        function()
          local project_root = get_project_root()
          require("telescope.builtin").live_grep({
            cwd = project_root,
            search_dirs = { project_root },
          })
        end,
        desc = "Search in project (grep)",
      },
    },
  },
}
