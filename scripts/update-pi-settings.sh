#!/bin/bash
# DEPRECATED — 不再需要执行
#
# 历史用途：往 ~/.pi/agent/settings.json 写入
#   - enableSkillCommands = true
#   - enabledSkills = [brainstorming, writing-plans, ...]
#
# 现状：
#   - 当前 Pi 版本（0.75.x）不再依赖这两个字段
#   - 模板 pi.template.jsonc 和实际 settings.json 都没有这些字段
#   - 列表里的 brainstorming/writing-plans/... 由 superpowers 包提供，自动暴露为 /skill:name
#
# 如何配置 skill：
#   1. 安装包：pi install git:github.com/obra/superpowers
#   2. 直接使用：在 Pi 内运行 /skill:systematic-debugging 等
#
# 如果你确实要保留这段配置，请直接编辑 pi/pi.template.jsonc 加进去，
# 然后用 restore.sh 写到 ~/.pi/agent/settings.json。
#
# 保留此脚本仅用于历史归档，下面的逻辑已被禁用。

set -e

echo "⚠️  此脚本已废弃 (DEPRECATED)"
echo ""
echo "原因：当前 Pi (0.75.x) 不再使用 enableSkillCommands / enabledSkills 字段。"
echo "Skill 现在通过安装包（如 superpowers）自动暴露为 /skill:name。"
echo ""
echo "如需修改 settings.json，请编辑 pi/pi.template.jsonc 然后运行 pi/restore.sh。"
exit 0

# ════════════════════════════════════════════════════════════════════════
# 以下为历史脚本（已禁用）
# ════════════════════════════════════════════════════════════════════════
#
# PI_SETTINGS=~/.pi/agent/settings.json
# if ! command -v jq &> /dev/null; then
#     echo "ERROR: jq is required"
#     exit 1
# fi
# jq '.enableSkillCommands = true' "$PI_SETTINGS" > "${PI_SETTINGS}.tmp" && mv "${PI_SETTINGS}.tmp" "$PI_SETTINGS"
# if ! jq -e '.enabledSkills' "$PI_SETTINGS" > /dev/null 2>&1; then
#     jq '.enabledSkills = [
#         "brainstorming", "openspec", "test-driven-development",
#         "systematic-debugging", "verification-before-completion",
#         "writing-plans", "executing-plans", "using-git-worktrees",
#         "finishing-a-development-branch", "dispatching-parallel-agents",
#         "subagent-driven-development", "requesting-code-review",
#         "receiving-code-review", "writing-skills", "using-superpowers"
#     ]' "$PI_SETTINGS" > "${PI_SETTINGS}.tmp" && mv "${PI_SETTINGS}.tmp" "$PI_SETTINGS"
# fi
