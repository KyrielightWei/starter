# Terminal 终端管理配置指南

> 统一的终端管理方案，支持多终端、标签、选择器

## 快捷键

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>tt` | n | Terminal Selector | 打开终端选择器 |
| `<leader>ta` | n | Toggle All Terminals | 显示/隐藏所有终端 |
| `<leader>tl` | n | Send Line to Terminal | 发送当前行到终端 |
| `<leader>tL` | v | Send Selection to Terminal | 发送选中内容到终端 |

### 终端内导航

| 快捷键 | 模式 | 功能 |
|--------|------|------|
| `<C-h>` | t | 跳转到左侧窗口 |
| `<C-j>` | t | 跳转到下方窗口 |
| `<C-k>` | t | 跳转到上方窗口 |
| `<C-l>` | t | 跳转到右侧窗口 |
| `<C-q>` | t | 进入 Normal 模式 |
| `<C-\><C-q>` | t | 关闭终端 |
| `i` | n | 进入终端插入模式 |

---

## 用户命令

| 命令 | 说明 |
|------|------|
| `:TermSelect` | 打开终端选择器 |
| `:TermNew [direction]` | 创建新终端（float/horizontal/vertical） |
| `:TermKillAll` | 关闭所有托管终端 |

### 创建终端示例

```vim
:TermNew           " 创建浮动终端
:TermNew float     " 创建浮动终端
:TermNew horizontal " 创建水平分屏终端
:TermNew vertical   " 创建垂直分屏终端
```

---

## 终端选择器

按 `<leader>tt` 打开选择器，显示：

- 所有已打开的终端列表
- 终端标签和索引
- 当前激活的终端

选择后：
- 按 `Enter` 跳转到该终端
- 按 `d` 删除终端
- 按 `r` 重命名标签

---

## 状态栏显示

终端状态下，状态栏显示：

```
[1/3] opencode │ [claude] │ aider
```

- 当前终端用 `[]` 包围
- 显示终端数量和索引
- 显示操作提示

---

## AI CLI 集成

终端模块预配置了以下 AI CLI：

| CLI | 命令 |
|-----|------|
| OpenCode | `opencode` |
| Claude Code | `claude` |
| Aider | `aider` |

通过终端选择器可以快速切换。

---

## 配置选项

终端默认配置：

```lua
{
  direction = "float",      -- 默认方向
  shade_terminals = true,   -- 阴影效果
  start_in_insert = true,   -- 启动时进入插入模式
  persist_size = true,      -- 记住窗口大小
  close_on_exit = true,     -- 退出时关闭
  float_opts = {
    border = "curved",      -- 边框样式
  },
}
```

---

## 使用技巧

### 1. 多终端工作流

```
1. <leader>tt 打开选择器
2. 选择或创建新终端
3. 运行 AI CLI（如 claude）
4. <leader>ta 隐藏所有终端
5. 再次 <leader>ta 恢复
```

### 2. 发送代码到终端

```vim
" 发送当前行
<leader>tl

" 发送选中代码（可视模式）
<leader>tL
```

### 3. 终端窗口导航

在终端插入模式下：
- `<C-q>` 进入 Normal 模式
- 然后 `h/j/k/l` 或 `<C-h/j/k/l>` 切换窗口