# AI 快捷键完整参考

> 所有 AI 相关功能统一使用 `<leader>k` 前缀

---

## 快捷键分类

### 🤖 AI 核心交互

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>kc` | n | AI Chat | 打开 AI 聊天面板 |
| `<leader>kn` | n | AI New Chat | 创建新聊天会话 |
| `<leader>ke` | v | AI Edit Selection | 编辑选中的代码（需先 visual select） |
| `<leader>kq` | n | AI Quick Ask | 快速提问（inline） |
| `<leader>ks` | n | Model Switch | 切换 AI 模型 |
| `<leader>kK` | n | Key Manager | 管理 API Keys |
| `<leader>kS` | n | Chat Sessions | 管理聊天历史 |
| `<leader>kt` | n | Toggle Panel | 切换 AI 面板显示/隐藏 |

### 🔧 Provider Manager

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>kp` | n | Provider Manager | 打开 Provider 管理面板 |
| `<leader>kP` | n | Check Provider | 检测当前 Provider 可用性 |
| `<leader>kA` | n | Check All | 检测所有 Provider 可用性 |

### 📊 Commit Picker & Diff

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>kC` | n | Commit Picker | 打开 Commit 选择器 |
| `<leader>kf` | n | Next Commit | 下一个 commit（需先打开 picker） |
| `<leader>kb` | n | Prev Commit | 上一个 commit |
| `<leader>kd` | n | Diff Viewer | 打开 Diffview |

### ⚙️ 配置与同步

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>kY` | n | Copy Context | 复制当前文件上下文到剪贴板 |
| `<leader>k=` | n | Sync All | 同步配置到 OpenCode/Claude Code |
| `<leader>kT` | n | Generate TUI | 生成 OpenCode TUI 主题 |
| `<leader>k$` | n | Preview Theme | 预览 OpenCode 主题 |

### ✨ AI Suggestion（插入模式）

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<M-]>` | i | Next Suggestion | 下一个 AI 建议 |
| `<M-[>` | i | Prev Suggestion | 上一个 AI 建议 |
| `<M-\>` | i | Accept Suggestion | 接受当前建议 |

---

## 用户命令

### AI 核心命令

| 命令 | 说明 |
|------|------|
| `:AIChat` | 打开 AI 聊天 |
| `:AIChatNew` | 创建新聊天 |
| `:AIEdit` | AI 编辑选中内容 |
| `:AIAsk` | 快速提问 |
| `:AIToggle` | 切换面板 |
| `:AIDiff` | 查看 Diff |

### Provider Manager 命令

| 命令 | 说明 |
|------|------|
| `:AIProviderManager` | 打开管理面板 |
| `:AICheckProvider [name] [model]` | 检测指定 provider |
| `:AICheckAllProviders` | 检测所有 providers |
| `:AIClearDetectionCache` | 清除检测缓存 |

### Commit Picker 命令

| 命令 | 说明 |
|------|------|
| `:AICommitPicker` | 打开 Commit 选择器 |
| `:AICommitConfig` | 配置 Picker 参数 |

### 配置同步命令

| 命令 | 说明 |
|------|------|
| `:AISyncAll` | 同步所有配置 |
| `:AISyncConfig` | 选择性同步 |
| `:AIConfigForceSync` | 强制同步 |
| `:AIConfigWatcherToggle` | 切换配置监听 |
| `:AICopyContext` | 复制上下文 |

### ECC 框架命令

| 命令 | 说明 |
|------|------|
| `:ECCInstall` | 安装 ECC 框架 |
| `:ECCStatus` | 查看 ECC 状态 |

---

## 快捷键设计原则

```
<leader>k + 按键分类：

c/n/e/q/s/S/t  → AI 核心交互（聊天、编辑、模型切换）
p/P/A          → Provider Manager（管理、检测）
C/f/b/d        → Commit Picker & Diff（选择、导航、查看）
K/Y/T/$        → 配置同步工具（复制、同步、主题）
```

### 避免冲突

以下按键已被其他模块占用：

| 按键 | 占用模块 | 说明 |
|------|----------|------|
| `<leader>k` | which-key | 显示 AI 功能菜单 |
| `<leader>kj` | 保留 | 避免与 `<leader>j` 冲突 |
| `<leader>k` + 数字 | 保留 | 避免与 buffer 切换冲突 |

---

## 相关文档

- [Provider Manager 使用指南](PROVIDER_MANAGER_GUIDE.md)
- [Commit Picker 使用指南](COMMIT_PICKER_GUIDE.md)
- [Component Manager 使用指南](COMPONENT_MANAGER_GUIDE.md)