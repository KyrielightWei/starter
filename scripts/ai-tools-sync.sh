#!/bin/bash
# ai-tools-sync.sh - 跨 Claude Code / OpenCode / Qoder CLI 的配置同步工具
#
# 功能：
# - Skills: Claude Code 格式 (YAML frontmatter + markdown) → 可直接用于 Qoder
# - Commands: Claude Code markdown → OpenCode XML 格式转换
# - Rules: 统一格式，分发到各工具

set -e

SOURCE_DIR="${HOME}/.ai-common"
CLAUDE_DIR="${HOME}/.claude"
OPENCODE_DIR="${HOME}/.config/opencode"
QODER_DIR="${HOME}/.qoder"

# 初始化统一源目录
init_source() {
  mkdir -p "$SOURCE_DIR/{skills,commands,rules,templates}"
  
  # 如果已有 Claude skills，复制到统一源
  if [ -d "$CLAUDE_DIR/skills" ] && [ ! -d "$SOURCE_DIR/skills/.git" ]; then
    echo "Copying existing Claude skills to unified source..."
    cp -r "$CLAUDE_DIR/skills" "$SOURCE_DIR/skills-backup"
    # 选择性迁移重要的 skills
  fi
}

# Skills 同步（Claude/Qoder 格式相同）
sync_skills() {
  echo "=== Syncing Skills ==="
  
  # Claude Code
  if [ -d "$CLAUDE_DIR" ]; then
    rm -rf "$CLAUDE_DIR/skills"
    ln -sf "$SOURCE_DIR/skills" "$CLAUDE_DIR/skills"
    echo "✓ Claude Code: linked to $SOURCE_DIR/skills"
  fi
  
  # Qoder CLI
  if [ -d "$QODER_DIR" ]; then
    rm -rf "$QODER_DIR/skills"
    ln -sf "$SOURCE_DIR/skills" "$QODER_DIR/skills"
    echo "✓ Qoder CLI: linked to $SOURCE_DIR/skills"
  fi
  
  # OpenCode 不支持 skills 目录结构，跳过
}

# Commands 同步（需要格式转换）
sync_commands() {
  echo "=== Syncing Commands ==="
  
  # Claude/Qoder 使用相同格式（简单 markdown）
  if [ -d "$CLAUDE_DIR" ]; then
    rm -rf "$CLAUDE_DIR/commands"
    ln -sf "$SOURCE_DIR/commands" "$CLAUDE_DIR/commands"
    echo "✓ Claude Code: linked commands"
  fi
  
  if [ -d "$QODER_DIR" ]; then
    rm -rf "$QODER_DIR/commands"
    ln -sf "$SOURCE_DIR/commands" "$QODER_DIR/commands"
    echo "✓ Qoder CLI: linked commands"
  fi
  
  # OpenCode 需要转换为 XML 格式
  if [ -d "$OPENCODE_DIR" ]; then
    convert_commands_to_opencode "$SOURCE_DIR/commands" "$OPENCODE_DIR/command"
    echo "✓ OpenCode: converted commands (XML format)"
  fi
}

# Claude markdown → OpenCode XML 转换
convert_commands_to_opencode() {
  local src_dir="$1"
  local dest_dir="$2"
  
  mkdir -p "$dest_dir"
  
  for cmd_file in "$src_dir"/*.md; do
    if [ -f "$cmd_file" ]; then
      local cmd_name=$(basename "$cmd_file" .md)
      local dest_file="$dest_dir/$cmd_name.md"
      
      # 简单转换：提取内容并包装为 OpenCode XML 格式
      # OpenCode 格式：<objective>, <process>, <examples>, <constraints>
      
      python3 -c "
import re
import sys

with open('$cmd_file', 'r') as f:
    content = f.read()

# 提取 YAML frontmatter
frontmatter = {}
if content.startswith('---'):
    parts = content.split('---', 2)
    if len(parts) >= 3:
        for line in parts[1].strip().split('\n'):
            if ':' in line:
                k, v = line.split(':', 1)
                frontmatter[k.strip()] = v.strip()
        content = parts[2].strip()

# 转换为 OpenCode XML 格式
output = ''
if 'description' in frontmatter:
    output += f'<description>{frontmatter[\"description\"]}</description>\n\n'

# 尝试提取各部分
sections = re.split(r'^## ', content)
objective = ''
process = ''
examples = ''

for section in sections:
    if not section:
        continue
    lines = section.strip().split('\n')
    title = lines[0] if lines else ''
    body = '\n'.join(lines[1:]) if len(lines) > 1 else ''
    
    if title.lower() in ['objective', 'goal', 'purpose']:
        objective = body
    elif title.lower() in ['process', 'steps', 'workflow']:
        process = body
    elif title.lower() in ['example', 'examples', 'usage']:
        examples = body

if objective:
    output += f'<objective>\n{objective}\n</objective>\n\n'
if process:
    output += f'<process>\n{process}\n</process>\n\n'
if examples:
    output += f'<examples>\n{examples}\n</examples>\n\n'

# 如果没有找到结构化内容，整个放入 process
if not objective and not process:
    output += f'<process>\n{content}\n</process>\n'

print(output)
" > "$dest_file"
      
      echo "  Converted: $cmd_name"
    fi
  done
}

# Rules 同步
sync_rules() {
  echo "=== Syncing Rules ==="
  
  # Claude Code 有完整的 rules 目录结构
  if [ -d "$CLAUDE_DIR" ]; then
    rm -rf "$CLAUDE_DIR/rules"
    ln -sf "$SOURCE_DIR/rules" "$CLAUDE_DIR/rules"
    echo "✓ Claude Code: linked rules"
  fi
  
  # Qoder/OpenCode 目前不支持独立的 rules 目录
}

# 主函数
main() {
  local action="${1:-sync}"
  
  case "$action" in
    init)
      init_source
      ;;
    sync)
      sync_skills
      sync_commands
      sync_rules
      ;;
    skills)
      sync_skills
      ;;
    commands)
      sync_commands
      ;;
    rules)
      sync_rules
      ;;
    status)
      echo "=== Current Status ==="
      echo "Source: $SOURCE_DIR"
      ls -la "$SOURCE_DIR" 2>/dev/null || echo "  (not initialized)"
      echo ""
      echo "Claude Code:"
      ls -la "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/rules" 2>/dev/null || echo "  (links may not exist)"
      echo ""
      echo "Qoder CLI:"
      ls -la "$QODER_DIR/skills" "$QODER_DIR/commands" 2>/dev/null || echo "  (links may not exist)"
      echo ""
      echo "OpenCode:"
      ls -la "$OPENCODE_DIR/command" 2>/dev/null || echo "  (command dir may not exist)"
      ;;
    *)
      echo "Usage: $0 {init|sync|skills|commands|rules|status}"
      exit 1
      ;;
  esac
}

main "$@"