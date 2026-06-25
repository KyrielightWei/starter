-- luacheck 配置
-- 安装: luarocks install luacheck
-- 运行: luacheck lua/ local-plugins/

-- Neovim 全局变量
globals = {
  "vim",
}

-- 忽略模式
ignore = {
  "432", -- 隐式 self 参数
}

-- 每行最大长度
max_line_length = 120

-- 允许使用的编码
encoding = "UTF-8"

-- 代码质量等级
std = "lua51"

-- 排除的目录和文件
exclude_files = {
  "lazy-lock.json",
  ".git/",
  "node_modules/",
}
