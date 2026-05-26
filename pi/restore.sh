#!/bin/bash
# 从模板恢复 Pi 配置

set -e

# ═════════════════════════════════════════════════════════════════════════
# 配置
# ═════════════════════════════════════════════════════════════════════════

PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ═════════════════════════════════════════════════════════════════════════
# 创建目录结构
# ═════════════════════════════════════════════════════════════════════════

echo "📁 创建目录结构..."

mkdir -p "$PI_DIR"/{themes,extensions,skills,prompts,sessions}
mkdir -p "$PI_DIR"/skills/{openspec,brainstorming,systematic-debugging,test-driven-development,using-git-worktrees,verification-before-completion}

# ═════════════════════════════════════════════════════════════════════════
# 复制核心配置
# ═════════════════════════════════════════════════════════════════════════

echo "⚙️ 复制核心配置..."

cp "$SCRIPT_DIR/settings.template.jsonc" "$PI_DIR/settings.json"
cp "$SCRIPT_DIR/models.template.jsonc" "$PI_DIR/models.json"
cp "$SCRIPT_DIR/keybindings.template.jsonc" "$PI_DIR/keybindings.json"
cp "$SCRIPT_DIR/theme.template.json" "$PI_DIR/themes/kanagawa.json"
cp "$SCRIPT_DIR/AGENTS.template.md" "$PI_DIR/AGENTS.md"

# ═════════════════════════════════════════════════════════════════════════
# 复制扩展
# ═════════════════════════════════════════════════════════════════════════

echo "🔌 复制扩展..."

for f in "$SCRIPT_DIR"/extensions/*.template.ts; do
  if [ -f "$f" ]; then
    name=$(basename "$f" .template.ts)
    cp "$f" "$PI_DIR/extensions/$name.ts"
    echo "  ✓ $name.ts"
  fi
done

# ═════════════════════════════════════════════════════════════════════════
# 复制技能
# ═════════════════════════════════════════════════════════════════════════

echo "🎯 复制技能..."

for dir in "$SCRIPT_DIR"/skills/*/; do
  if [ -d "$dir" ]; then
    name=$(basename "$dir")
    mkdir -p "$PI_DIR/skills/$name"
    if [ -f "$dir/SKILL.md" ]; then
      cp "$dir/SKILL.md" "$PI_DIR/skills/$name/SKILL.md"
      echo "  ✓ $name"
    fi
  fi
done

# ═════════════════════════════════════════════════════════════════════════
# 复制 Prompts
# ═════════════════════════════════════════════════════════════════════════

echo "📝 复制 Prompt 模板..."

for f in "$SCRIPT_DIR"/prompts/*.template.md; do
  if [ -f "$f" ]; then
    name=$(basename "$f" .template.md)
    cp "$f" "$PI_DIR/prompts/$name.md"
    echo "  ✓ $name.md"
  fi
done

# ═════════════════════════════════════════════════════════════════════════
# 完成
# ═════════════════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "✓ Pi 配置已恢复到: $PI_DIR"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
echo "验证配置:"
echo "  pi              # 启动 Pi"
echo "  /settings       # 查看设置"
echo "  /model          # 查看模型"
echo "  /hotkeys        # 查看快捷键"
echo "  /statusbar      # 切换状态栏"
echo ""
echo "设置 API Key:"
echo "  export OPENAI_API_KEY='your-key'"
echo ""