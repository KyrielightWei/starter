# Diffview.nvim 配置指南

> 多文件 Git Diff 视图，用于 AI 代码审查工作流

## 功能特性

- **多文件并排 Diff**：左侧文件树，右侧左右分屏对比
- **自定义 Git 路径**：支持独立的新版 Git（解决系统 Git 版本过低问题）
- **Git Worktree 支持**：自动检测并配置 worktree
- **Git 版本检测**：启动时检测 Git 版本，低于 2.31 时弹出选择界面
- **本地配置持久化**：自定义 Git 路径保存在本地，仅当前机器生效

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `<leader>gv` | 打开 Diffview |
| `<leader>gV` | 关闭 Diffview |
| `<leader>gf` | 文件历史 |
| `<leader>gF` | 当前文件历史 |

## 命令

| 命令 | 说明 |
|------|------|
| `:DiffviewSetGit` | 设置自定义 Git 可执行文件路径 |
| `:DiffviewGitInfo` | 查看当前 Git 配置信息 |

## 基本导航

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 打开 Diffview | `<leader>gv` | 查看所有改动文件 |
| 关闭 Diffview | `<leader>gV` 或 `q` | 退出 diff 视图 |
| 下一个 Hunk | `Tab` 或 `]c` 或 `]h` | 跳到下一个修改块 |
| 上一个 Hunk | `S-Tab` 或 `[c` 或 `[h` | 跳到上一个修改块 |
| 打开文件 | `Enter` | 在右侧打开选中文件 |
| 显示帮助 | `?` | 快捷键速查 |

---

## 文件级操作（左侧文件树）

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| Stage 文件 | `s` | 暂存整个文件 |
| Unstage 文件 | `u` | 取消暂存 |
| 放弃文件修改 | `X` | 还原到原始状态 |
| 刷新 | `r` | 刷新 diff |

---

## Hunk 级操作（右侧代码区）

### Vim 原生 Diff 命令

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| **Diff Put** | `dp` | 把当前块的修改"推"到另一侧（采纳修改） |
| **Diff Obtain** | `do` | 从另一侧"拉"修改到当前侧 |

### Gitsigns 操作（LazyVim 内置）

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| Stage Hunk | `<leader>ghs` | 只暂存当前 hunk |
| Reset Hunk | `<leader>ghr` | 还原当前 hunk |
| Preview Hunk | `<leader>ghp` | 预览 hunk |

---

## 常见审查流程

### 场景 1：完全采纳 AI 生成的文件

```
1. <leader>gv 打开 Diffview
2. 在文件树中用 j/k 选中文件
3. 按 s 暂存整个文件
4. 继续下一个文件
```

### 场景 2：只采纳部分修改

```
1. Enter 打开文件进入 diff 视图
2. Tab 跳转到第一个 hunk
3. 审查后：
   - 满意 → dp 推送到左侧（采纳）
   - 不满意 → 跳过，继续 Tab 到下一个
4. 或者用 <leader>ghs 只暂存满意的 hunk
```

### 场景 3：手动微调 AI 代码

```
1. 在右侧（AI 修改侧）进入插入模式 i
2. 手动编辑代码
3. Esc 退出插入模式
4. dp 把修改后的代码推过去
```

### 场景 4：对比后决定放弃

```
1. Tab 逐个查看 hunk
2. 发现 AI 在胡说 → 按 X 放弃整个文件
3. 或 <leader>ghr 还原某个 hunk
```

---

## 完成审查后

```vim
" 关闭 Diffview
<leader>gV

" 提交已暂存的改动
:!git commit -m "message"

" 放弃未暂存的改动
:!git checkout -- .
```

---

## 记忆要点

1. **左侧 = 原始代码**（Git Index）
2. **右侧 = 修改后代码**（Working Tree）
3. **`dp` = push**（从当前推到另一侧）
4. **`do` = obtain**（从另一侧拉到当前）

---

## 配置文件

- **插件配置**：`lua/plugins/git.lua`
- **本地 Git 路径配置**：`~/.local/state/nvim/diffview_local.lua`

## Git 版本要求

- **最低版本**：Git 2.31.0
- **原因**：diffview.nvim 使用 `git rev-parse --path-format=absolute` 命令

如果系统 Git 版本过低，可以：

1. 下载独立的新版 Git 二进制文件
2. 运行 `:DiffviewSetGit` 设置路径
3. 或在启动时根据提示选择/输入自定义路径