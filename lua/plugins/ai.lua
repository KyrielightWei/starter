-- lua/plugins/ai.lua
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",  -- 必须添加！用于编译 Rust 二进制文件
    config = function()
      require("ai").setup()
    end,
  },
}
