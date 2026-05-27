#!/bin/bash
# 优化现有 Pi 配置 - 补充缺失项，保留现有扩展

set -e

PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════════════════════════════"
echo "Pi 配置优化 - 补充缺失项"
echo "════════════════════════════════════════════════════════════════════════"

# ───────────────────────────────────────────────────────────────────────
# 1. 补充 keybindings (不存在则创建)
# ───────────────────────────────────────────────────────────────────────

if [ ! -f "$PI_DIR/keybindings.json" ]; then
  echo "📌 创建 keybindings.json..."
  cp "$SCRIPT_DIR/keybindings.template.jsonc" "$PI_DIR/keybindings.json"
else
  echo "📌 keybindings.json 已存在，跳过"
fi

# ───────────────────────────────────────────────────────────────────────
# 2. 创建 prompts 目录并复制模板
# ───────────────────────────────────────────────────────────────────────

if [ ! -d "$PI_DIR/prompts" ]; then
  echo "📝 创建 prompts 目录..."
  mkdir -p "$PI_DIR/prompts"
  
  for f in "$SCRIPT_DIR"/prompts/*.template.md; do
    if [ -f "$f" ]; then
      name=$(basename "$f" .template.md)
      cp "$f" "$PI_DIR/prompts/$name.md"
      echo "  ✓ $name.md"
    fi
  done
else
  echo "📝 prompts 目录已存在，检查缺失项..."
  
  for f in "$SCRIPT_DIR"/prompts/*.template.md; do
    if [ -f "$f" ]; then
      name=$(basename "$f" .template.md)
      if [ ! -f "$PI_DIR/prompts/$name.md" ]; then
        cp "$f" "$PI_DIR/prompts/$name.md"
        echo "  + $name.md (新增)"
      fi
    fi
  done
fi

# ───────────────────────────────────────────────────────────────────────
# 3. 更新 settings.json - 补充缺失配置
# ───────────────────────────────────────────────────────────────────────

echo "⚙️ 检查 settings.json..."

# 检查是否缺少 compaction 配置
if ! grep -q "compaction" "$PI_DIR/settings.json"; then
  echo "  添加 compaction 配置..."
  # 使用 node 合并 JSON
  node -e "
    const fs = require('fs');
    const settings = JSON.parse(fs.readFileSync('$PI_DIR/settings.json'));
    settings.compaction = { enabled: true, reserveTokens: 16384, keepRecentTokens: 20000 };
    settings.retry = { enabled: true, maxRetries: 3, baseDelayMs: 2000, provider: { timeoutMs: 3600000, maxRetryDelayMs: 60000 } };
    settings.branchSummary = { reserveTokens: 16384, skipPrompt: false };
    settings.steeringMode = 'one-at-a-time';
    settings.followUpMode = 'one-at-a-time';
    settings.transport = 'sse';
    fs.writeFileSync('$PI_DIR/settings.json', JSON.stringify(settings, null, 2));
  "
else
  echo "  compaction 配置已存在，跳过"
fi

# ───────────────────────────────────────────────────────────────────────
# 4. 补充 models.json cost 信息
# ───────────────────────────────────────────────────────────────────────

echo "📦 检查 models.json cost 信息..."

if ! grep -q '"cost"' "$PI_DIR/models.json"; then
  echo "  添加 cost 信息..."
  node -e "
    const fs = require('fs');
    const models = JSON.parse(fs.readFileSync('$PI_DIR/models.json'));
    for (const provider of Object.values(models.providers)) {
      if (provider.models) {
        for (const model of provider.models) {
          model.cost = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
        }
      }
    }
    fs.writeFileSync('$PI_DIR/models.json', JSON.stringify(models, null, 2));
  "
else
  echo "  cost 信息已存在，跳过"
fi

# ───────────────────────────────────────────────────────────────────────
# 完成
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "✓ Pi 配置优化完成"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
echo "已补充:"
echo "  - keybindings.json (快捷键配置)"
echo "  - prompts/*.md (7 个 prompt 模板)"
echo "  - settings.json (compaction/retry/branchSummary 配置)"
echo "  - models.json (cost 信息)"
echo ""
echo "保留:"
echo "  - superpowers 包 (14 个高级技能)"
echo "  - 现有扩展 (handoff, subagent, plan-mode 等)"
echo ""
echo "验证:"
echo "  pi"
echo "  /settings    # 查看新配置"
echo "  /hotkeys     # 查看快捷键"
echo "  /review      # 测试 prompt 模板"
echo ""