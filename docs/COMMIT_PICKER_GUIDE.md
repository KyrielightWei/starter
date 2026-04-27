# Commit Picker & Diff 使用指南

> Commit Picker 用于查看和导航 Git 提交历史，配合 Diffview 进行代码审查

---

## 快速开始

### 打开 Commit Picker

```vim
:AICommitPicker
```

或使用快捷键：`<leader>kC`

---

## 界面说明

```
╔══════════════════════════════════════════════════════════════╗
║  Commit Picker                                  [?] Help      ║
╠══════════════════════════════════════════════════════════════╣
║  SHA       Author     Date        Subject                     ║
║  ─────────────────────────────────────────────────────────── ║
║  > 5b947a6  you        2026-04-27  fix: resolve review issues ║
║    8523ba8  you        2026-04-26  Merge remote branch        ║
║    4b0ef63  you        2026-04-26  fix: apply review findings ║
║    528533c  you        2026-04-25  feat: commit picker        ║
║    ─────────────────────────────────────────────────────────── ║
║    ● Base: 7f25b0d (GSD v1.0)                                ║
╠══════════════════════════════════════════════════════════════╣
║  [Enter] Diff │ [s] Select │ [b] Set Base │ [c] Config │ [?]  ║
╚══════════════════════════════════════════════════════════════╝
```

### 标记说明

| 标记 | 含义 |
|------|------|
| `>` | 当前选中 |
| `●` | Base commit（比较基准） |
| `s` | 已选中（用于多选比较） |

---

## 快捷键说明

### Commit Picker

| 快捷键 | 功能 | 说明 |
|--------|------|------|
| `Enter` | Open Diff | 打开选中 commit 的 diff |
| `s` | Select | 选中/取消选中（用于多选比较） |
| `b` | Set Base | 设为比较基准 |
| `c` | Config | 打开配置面板 |
| `r` | Refresh | 刷新 commit 列表 |
| `?` | Help | 显示帮助 |
| `q` / `Esc` | Quit | 关闭面板 |

### Diff 导航（在 Diffview 中）

| 快捷键 | 功能 | 说明 |
|--------|------|------|
| `<leader>kf` | Next Commit | 下一个 commit |
| `<leader>kb` | Prev Commit | 上一个 commit |
| `<leader>kd` | Diff Viewer | 打开 Diffview（工作区变更） |

### Diffview 内部导航

| 快捷键 | 功能 |
|--------|------|
| `Tab` / `]h` | 下一个 Hunk |
| `S-Tab` / `[h` | 上一个 Hunk |
| `]f` | 下一个文件 |
| `[f` | 上一个文件 |
| `do` | Diff Obtain（拉取变更） |
| `dp` | Diff Put（推送变更） |
| `q` | 关闭 Diffview |
| `?` | 显示帮助 |

---

## 工作流程

### 单 Commit 查看

1. `<leader>kC` 打开 Commit Picker
2. 选择 commit，按 `Enter`
3. Diffview 打开，显示 commit vs parent 的变更
4. 使用 `Tab/S-Tab` 导航 Hunk
5. `<leader>kf`/`<leader>kb` 导航到其他 commit

### 多 Commit 比较

1. `<leader>kC` 打开 Commit Picker
2. 按 `s` 选中第一个 commit
3. 按 `s` 选中第二个 commit
4. 按 `Enter` 打开 diff
5. 显示两个 commit 之间的差异

### 设置 Base Commit

用于 GSD 多 commit 工作流审查：

1. `<leader>kC` 打开 Commit Picker
2. 找到起始 commit，按 `b` 设为 Base
3. Picker 自动显示 Base 之后的所有 commit
4. 导航审查所有变更

---

## 配置选项

打开配置面板：`:AICommitConfig` 或在 Picker 中按 `c`

### 配置项

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `mode` | `"unpushed"` | commit 来源模式 |
| `count` | `20` | 显示的 commit 数量 |
| `base_commit` | `"HEAD"` | Base commit SHA |

### 模式说明

| 模式 | 说明 |
|------|------|
| `unpushed` | 未推送的 commit |
| `all` | 所有 commit |
| `range` | 指定范围 |
| `since_base` | Base 之后的所有 commit |

---

## Diffview 增强

### 增强命令

本配置提供增强版 Diffview 命令，支持 Git Worktree：

| 命令 | 说明 |
|------|------|
| `:DiffviewOpenEnhanced` | 打开 Diffview（自动检测 worktree） |
| `:DiffviewFileHistoryEnhanced` | 查看文件历史 |
| `:DiffviewSetGit` | 设置自定义 git 路径 |
| `:DiffviewGitInfo` | 显示 git 配置信息 |

### Git 版本要求

Diffview 需要 Git >= 2.31。

如版本不足，会弹出选择对话框，可选择：
- 使用其他 git 可执行文件
- 输入自定义路径
- 跳过（可能无法正常工作）

---

## 完整工作流示例

### GSD 多 Commit 审查

```vim
" 1. 打开 Picker
<leader>kC

" 2. 设置 Base commit（起始点）
b

" 3. 查看第一个 commit
Enter

" 4. 导航到下一个 commit
<leader>kf

" 5. 继续导航
<leader>kf
<leader>kf
...

" 6. 完成审查，关闭 Diffview
q
```

### PR Review

```vim
" 1. 查看所有未推送 commit
<leader>kC

" 2. 选中起始和结束 commit
s（选中起始）
s（选中结束）

" 3. 打开 diff
Enter

" 4. 查看 PR 整体变更
```

---

## 常见问题

### Q: Diffview 显示 "git version too old"

解决方案：
1. 更新系统 Git 到 >= 2.31
2. 或执行 `:DiffviewSetGit` 指定其他 git 路径

### Q: 导航快捷键不工作

需要先通过 Commit Picker 打开 Diffview：
- `<leader>kC` → Enter 打开 diff
- 然后 `<leader>kf`/`<leader>kb` 才能工作

### Q: Worktree 中 Diffview 无法打开

使用增强命令：`:DiffviewOpenEnhanced`

自动检测 `.git` 文件并解析 worktree 路径。

---

## 相关文档

- [AI 快捷键参考](AI_KEYMAPS.md)
- [Provider Manager 使用指南](PROVIDER_MANAGER_GUIDE.md)
- [Diffview 配置](diffview.md)