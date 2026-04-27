# Provider Manager 使用指南

> Provider Manager 提供统一的界面管理 AI Provider 和 Model

---

## 快速开始

### 打开 Provider Manager

```vim
:AIProviderManager
```

或使用快捷键：`<leader>kp`

---

## 界面说明

```
╔══════════════════════════════════════════════════════════════╗
║  Provider Manager                                     [?] Help ║
╠══════════════════════════════════════════════════════════════╣
║  Provider          Model              Status     Default     ║
║  ─────────────────────────────────────────────────────────── ║
║  > bailian_coding  qwen3.6-plus       ✓ OK       ○           ║
║    deepseek        deepseek-chat      ✓ OK       ●           ║
║    openai          gpt-4o-mini        ✓ OK       ○           ║
║    qwen            qwen-2.5-chat      ○ Timeout  ○           ║
║    ollama          qwen2.5-coder      ○ N/A      ○           ║
╠══════════════════════════════════════════════════════════════╣
║  [Enter] Models │ [c] Check │ [d] Default │ [e] Edit │ [?] Help ║
╚══════════════════════════════════════════════════════════════╝
```

### 状态图标

| 图标 | 含义 |
|------|------|
| ✓ | Provider 可用，API key 有效 |
| ○ | Provider 不可用或未检测 |
| ⏳ | 正在检测中 |
| ✗ | 检测失败 |

### 默认标记

| 标记 | 含义 |
|------|------|
| ● | 当前默认 Provider |
| ○ | 非默认 Provider |

---

## 快捷键说明

### Provider Picker

| 快捷键 | 功能 | 说明 |
|--------|------|------|
| `Enter` | Models | 打开该 Provider 的模型列表 |
| `c` | Check | 检测当前 Provider 可用性 |
| `d` | Default | 设为默认 Provider |
| `e` | Edit | 编辑 Provider 配置（providers.lua） |
| `r` | Refresh | 刷新状态 |
| `?` | Help | 显示帮助 |
| `q` / `Esc` | Quit | 关闭面板 |

### Model Picker（进入后）

| 快捷键 | 功能 | 说明 |
|--------|------|------|
| `Enter` | Set Default | 设为该 Provider 的默认模型 |
| `C-e` | Edit Static Models | 编辑静态模型列表 |
| `C-/` | Help | 显示帮助 |

---

## 检测功能

### 检测当前 Provider

```vim
:AICheckProvider
```

或 `<leader>kP`

不带参数时检测当前使用的 Provider 和 Model。

### 检测指定 Provider

```vim
:AICheckProvider deepseek
:AICheckProvider openai gpt-4o
```

### 检测所有 Provider

```vim
:AICheckAllProviders
```

或 `<leader>kA`

### 清除检测缓存

```vim
:AIClearDetectionCache
```

---

## 配置文件

### Provider 注册表

位置：`lua/ai/providers.lua`

```lua
-- 注册新 Provider
Providers.register("my_provider", {
  api_key_name = "MY_PROVIDER_API_KEY",
  base_endpoint = "https://api.my-provider.com/v1",
  model = "my-model-default",
  static_models = {
    "my-model-small",
    "my-model-large",
  },
})
```

### API Keys 配置

位置：`~/.local/state/nvim/ai_keys.lua`

```lua
return {
  my_provider = {
    default = {
      api_key = "sk-xxx",
      base_url = "",
      model = "my-model-large",  -- 覆盖默认模型
    },
  },
  profile = "default",
}
```

---

## 工作流程示例

### 切换 Provider

1. `<leader>kp` 打开 Provider Manager
2. 选择目标 Provider，按 `Enter` 进入模型列表
3. 选择模型，按 `Enter` 设为默认
4. 配置自动同步到 OpenCode / Claude Code

### 检测新 Provider

1. 在 `providers.lua` 中注册新 Provider
2. 在 `ai_keys.lua` 中添加 API key
3. `<leader>kA` 检测所有 Provider
4. 查看检测结果，确认可用

### 添加新模型

1. `<leader>kp` 打开 Provider Manager
2. 选择 Provider，按 `Enter`
3. 按 `C-e` 编辑静态模型列表
4. 添加新模型 ID，保存

---

## 常见问题

### Q: 检测显示 Timeout

可能原因：
- API endpoint 不可达
- API key 无效或过期
- 网络连接问题

解决方案：
1. 检查 `ai_keys.lua` 中的 API key
2. 检查 `base_url` 是否正确
3. 使用 `curl` 手动测试 endpoint

### Q: 模型切换后 Claude Code 未生效

Provider Manager 在切换后会自动触发同步。
如未生效，可手动同步：

```vim
:AISyncAll
```

### Q: 如何添加自定义 Provider

1. 编辑 `lua/ai/providers.lua`，添加 `Providers.register()`
2. 在 `ai_keys.lua` 中添加对应的 API key
3. 重启 Neovim 或执行 `:AIProviderManager`

---

## 相关文档

- [AI 快捷键参考](AI_KEYMAPS.md)
- [Commit Picker 使用指南](COMMIT_PICKER_GUIDE.md)