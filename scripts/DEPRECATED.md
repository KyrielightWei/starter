# scripts/ DEPRECATED

| 脚本 | 状态 | 说明 |
|---|---|---|
| `install-pi-dev.sh` | ✅ **现役** | Pi 一键安装：模板 + community packages + MCP 配置 |
| `ai-tools-sync.sh` | ✅ 现役 | 同步 OpenCode / Claude Code 配置（不涉及 Pi） |
| `preview_config.lua` | ✅ 现役 | nvim 内预览配置 |
| `install-pi-skills.sh` | 🟡 已废弃 | 老版手动拷贝 superpowers skill；新版让 `pi install` 接管。功能被 `install-pi-dev.sh` 覆盖。 |
| `setup-pi-superpowers.sh` | 🟡 已废弃 | 同上；且向 settings 写入了 Pi 不识别的 `enabledSkills` 字段 |
| `update-pi-settings.sh` | 🟡 已废弃 | 同上 |

## 迁移指引

旧脚本依赖 superpowers 已被 `pi install` 拉到 `~/.pi/agent/git/github.com/obra/superpowers/` 这个事实，再手动 cp 单个 skill 到 `~/.pi/agent/skills/`。

新方案直接走 Pi 原生 package 体系：
- 在 `pi.template.jsonc` 的 `packages` 字段声明依赖
- 在 `settings.json` 的 `skills` 字段声明跨工具复用路径
- 由 `pi install` / `pi update` 维护包版本
- skill 调用走 `/skill:name`，由 Pi 自己 resolve

旧脚本写入的 `enabledSkills` 字段是无效的（[Pi settings 文档](file:///usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/settings.md)只有 `enableSkillCommands` boolean）。如果你的 `~/.pi/agent/settings.json` 里有这个字段，可以安全删除。

## 安全删除旧脚本（可选）

```bash
# 确认新脚本能跑后再清理
rm scripts/install-pi-skills.sh scripts/setup-pi-superpowers.sh scripts/update-pi-settings.sh
```

或保留作为历史备份，不主动维护即可。
