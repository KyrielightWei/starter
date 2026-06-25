# OpenCode 美化指南

## 🎨 美化内容

本次为 OpenCode 添加了以下美化功能：

### 1. 自定义主题 - lytmode

基于现代深色设计语言，创建了自定义的 `lytmode` 主题，特点包括：

- **主色调**：优雅的蓝紫色系 (#7C3AED)
- **辅助色**：清新的青绿色 (#06B6D4)
- **强调色**：温暖的琥珀色 (#F59E0B)
- **背景**：深邃的 Slate 色系 (#0F172A, #1E293B)
- **文本**：高对比度的浅色文本 (#F1F5F9)
- **状态色**：
  - ✅ 成功：翠绿 (#10B981)
  - ⚠️ 警告：琥珀 (#F59E0B)
  - ❌ 错误：鲜红 (#EF4444)
  - ℹ️ 信息：亮蓝 (#3B82F6)

### 2. TUI 配置优化

生成了 `tui.json` 配置文件，启用了：
- 显示模型信息
- 显示 token 计数
- 显示头部栏

### 3. 模板配置增强

更新了 `opencode.template.jsonc`：
- 添加了权限配置（编辑和 bash 执行前询问）
- 完善了文件忽略列表
- 优化了上下文压缩配置

## 📋 可用命令

| 命令 | 功能 |
|------|------|
| `:OpenCodeGenerateConfig` | 生成完整配置（包含 TUI 和主题） |
| `:OpenCodeGenerateTUI` | 仅生成 TUI 配置和主题 |
| `:OpenCodePreviewTUI` | 预览 TUI 配置 |
| `:OpenCodePreviewTheme` | 预览 lytmode 主题 |
| `:OpenCodeEditTheme` | 编辑主题文件 |

## ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| `<leader>kT` | 生成 TUI 主题配置 |
| `<leader>kP` | 预览主题配置 |

## 🚀 使用方法

### 方法一：自动生成（推荐）

```vim
:OpenCodeGenerateConfig
```

这会自动生成：
- `~/.config/opencode/opencode.json` - 主配置
- `~/.config/opencode/tui.json` - TUI 配置
- `~/.config/opencode/themes/lytmode.json` - 自定义主题
- `~/.config/opencode/instructions.md` - 系统提示

### 方法二：手动生成主题

```vim
:OpenCodeGenerateTUI
```

### 方法三：自定义主题

```vim
:OpenCodeEditTheme
```

然后编辑 `~/.config/opencode/themes/lytmode.json` 文件。

## 🎯 主题配置文件结构

```json
{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    // 定义可复用的颜色
  },
  "theme": {
    // UI 元素的颜色配置
  }
}
```

### 主要配置项

- `primary` - 主要强调色
- `secondary` - 次要强调色
- `accent` - 特殊强调色
- `background` - 主背景
- `backgroundPanel` - 面板背景
- `text` - 主要文本颜色
- `textMuted` - 次要文本颜色
- `border` - 边框颜色
- `diffAdded/Removed` - Diff 颜色
- `syntax*` - 代码语法高亮

## 🔧 高级定制

### 创建自己的主题

1. 复制现有主题：
```bash
cp ~/.config/opencode/themes/lytmode.json ~/.config/opencode/themes/my-theme.json
```

2. 编辑主题文件：
```vim
:OpenCodeEditTheme
```

3. 在 `tui.json` 中切换主题：
```json
{
  "theme": "my-theme"
}
```

### 使用内置主题

OpenCode 还内置了以下主题：
- `system` - 自适应终端颜色
- `tokyonight` - 东京之夜
- `everforest` - 永恒森林
- `ayu` -  Ayu 深色
- `catppuccin` - 卡布奇诺
- `catppuccin-macchiato` - 卡布奇诺玛奇朵
- `gruvbox` - Gruvbox
- `kanagawa` - 神奈川
- `nord` - 北欧
- `matrix` - 黑客帝国（绿黑）
- `one-dark` - Atom One Dark

在 OpenCode TUI 中使用 `/theme` 命令快速切换。

## 💡 提示

1. **终端要求**：确保终端支持 **truecolor**（24 位颜色）
   ```bash
   echo $COLORTERM  # 应输出 "truecolor" 或 "24bit"
   ```

2. **推荐终端**：
   - WezTerm
   - Alacritty
   - Ghostty
   - Kitty
   - iTerm2 (macOS)

3. **主题热重载**：修改主题后，重启 OpenCode 即可看到效果。

4. **项目级主题**：在项目根目录创建 `.opencode/themes/` 可以为特定项目使用不同主题。

## 📸 效果预览

主题使用现代深色设计，适合长时间编码：
- 低亮度背景减少眼睛疲劳
- 高对比度文本确保可读性
- 柔和的强调色引导视觉焦点
- 完善的 Diff 配色让代码审查更清晰

---

享受美化后的 OpenCode 体验！🎉
