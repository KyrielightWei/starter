#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# Pi Dev 配置一键安装
#
# 用法: ./scripts/install-pi-dev.sh
#
# 把项目 pi/ 模板装到 ~/.pi/agent/ 并安装 community packages。
# 已存在的同名文件会备份为 *.bak.<timestamp>。
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PI_DIR="$HOME/.pi/agent"
MCP_DIR="$HOME/.config/mcp"
TS=$(date +%s)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Pi Dev 配置一键安装                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "项目目录: $PROJECT_ROOT"
echo "目标目录: $PI_DIR"
echo ""

# ───────────────────────────────────────────────────────────────────────
# Helper: backup + copy（已存在的文件备份后再覆盖）
# ───────────────────────────────────────────────────────────────────────

backup_copy() {
  local src="$1"
  local dst="$2"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst" 2>/dev/null; then
    mv "$dst" "${dst}.bak.${TS}"
    echo "  ⤴  备份 $(basename "$dst") → $(basename "$dst").bak.${TS}"
  fi
  cp "$src" "$dst"
  echo "  ✓ $(basename "$dst")"
}

# ───────────────────────────────────────────────────────────────────────
# Helper: JSONC → JSON（Pi SettingsManager 只接受纯 JSON，不支持注释/尾随逗号）
# 仓库里模板保留 JSONC 给人读；写到 ~/.pi/agent/ 时去注释+去尾随逗号
# ───────────────────────────────────────────────────────────────────────

jsonc_to_json() {
  local src="$1"
  local dst="$2"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst" 2>/dev/null; then
    mv "$dst" "${dst}.bak.${TS}"
    echo "  ⤴  备份 $(basename "$dst") → $(basename "$dst").bak.${TS}"
  fi
  node -e "
    const fs = require('fs');
    const txt = fs.readFileSync('$src', 'utf8');
    // 简单 strip：块注释 / 行注释 / 尾随逗号（足够本模板用）
    const cleaned = txt
      .replace(/\\/\\*[\\s\\S]*?\\*\\//g, '')
      .replace(/(^|[^:])\\/\\/.*\$/gm, '\$1')
      .replace(/,\\s*([}\\]])/g, '\$1');
    // 验证是合法 JSON，再写出（pretty print）
    const obj = JSON.parse(cleaned);
    fs.writeFileSync('$dst', JSON.stringify(obj, null, 2) + '\n');
  " 2>&1 || { echo "  ✗ $(basename "$dst") JSON 校验失败"; return 1; }
  echo "  ✓ $(basename "$dst") (JSONC stripped)"
}

# ───────────────────────────────────────────────────────────────────────
# 1. 创建目录结构
# ───────────────────────────────────────────────────────────────────────

echo "📁 创建目录结构..."
mkdir -p "$PI_DIR/themes" "$PI_DIR/extensions" "$PI_DIR/skills" "$PI_DIR/prompts"
mkdir -p "$MCP_DIR"

# ───────────────────────────────────────────────────────────────────────
# 2. 主配置 / models / keybindings / 主题 / AGENTS
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "📋 主配置 (JSONC → 纯 JSON 写入)..."
jsonc_to_json "$PROJECT_ROOT/pi.template.jsonc"             "$PI_DIR/settings.json"
jsonc_to_json "$PROJECT_ROOT/pi/models.template.jsonc"      "$PI_DIR/models.json"
jsonc_to_json "$PROJECT_ROOT/pi/keybindings.template.jsonc" "$PI_DIR/keybindings.json"
jsonc_to_json "$PROJECT_ROOT/pi/theme.template.jsonc"       "$PI_DIR/themes/kanagawa.json"
backup_copy   "$PROJECT_ROOT/pi/AGENTS.template.md"         "$PI_DIR/AGENTS.md"

# ───────────────────────────────────────────────────────────────────────
# 3. Extensions（自研 + Pi 官方安全扩展）
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "🔌 Extensions..."
for tpl in "$PROJECT_ROOT/pi/extensions/"*.template.ts; do
  [ -f "$tpl" ] || continue
  base=$(basename "$tpl" .template.ts)
  backup_copy "$tpl" "$PI_DIR/extensions/${base}.ts"
done

# ───────────────────────────────────────────────────────────────────────
# 4. Skills（项目独有 + 由 packages 提供的不重复装）
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "📚 Skills（项目独有，superpowers/anthropics 等由 packages 提供）..."

# 清理已废的本地 skill 副本（这些 skill 由 packages 提供，本地副本会顶掉 package 版本）
# Pi 递归扫描 skills 目录，所以必须真删而非改名 .bak（.bak 目录里的 SKILL.md 仍会被识别）
for orphan in brainstorming; do
  if [ -d "$PI_DIR/skills/$orphan" ]; then
    rm -rf "$PI_DIR/skills/$orphan"
    echo "  ✗ 删除 skills/$orphan (改由 superpowers package 提供)"
  fi
  # 清理之前 .bak 误留（Pi 会扫到）
  for bak in "$PI_DIR/skills/${orphan}.bak."*; do
    [ -e "$bak" ] || continue
    rm -rf "$bak"
    echo "  ✗ 清理遗留 $(basename "$bak")"
  done
done

for skill_dir in "$PROJECT_ROOT/pi/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  mkdir -p "$PI_DIR/skills/$name"
  if [ -f "$skill_dir/SKILL.md" ]; then
    backup_copy "$skill_dir/SKILL.md" "$PI_DIR/skills/$name/SKILL.md"
  fi
  # 把 skill 目录内其他文件（references/scripts/assets）也复制
  for f in "$skill_dir"*; do
    [ -f "$f" ] && [ "$(basename "$f")" != "SKILL.md" ] && cp "$f" "$PI_DIR/skills/$name/"
  done
done

# ───────────────────────────────────────────────────────────────────────
# 5. Prompts
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "📝 Prompts..."
for tpl in "$PROJECT_ROOT/pi/prompts/"*.template.md; do
  [ -f "$tpl" ] || continue
  base=$(basename "$tpl" .template.md)
  backup_copy "$tpl" "$PI_DIR/prompts/${base}.md"
done

# ───────────────────────────────────────────────────────────────────────
# 6. MCP 配置（共享给 Cursor / Claude / Codex / Pi）
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "🌐 MCP 配置 (JSONC → 纯 JSON)..."
if [ -f "$MCP_DIR/mcp.json" ]; then
  # 已存在：检查是否为合法 JSON；若是 JSONC（带注释/尾随逗号）则原地 strip
  if node -e "JSON.parse(require('fs').readFileSync('$MCP_DIR/mcp.json','utf8'))" 2>/dev/null; then
    echo "  ✓ $MCP_DIR/mcp.json 已存在且为纯 JSON - 保留"
  else
    echo "  ⚠️  $MCP_DIR/mcp.json 检测到 JSONC（注释/尾随逗号），就地 strip..."
    cp "$MCP_DIR/mcp.json" "$MCP_DIR/mcp.json.bak.${TS}"
    if node -e "
      const fs = require('fs');
      const txt = fs.readFileSync('$MCP_DIR/mcp.json', 'utf8');
      const cleaned = txt
        .replace(/\\/\\*[\\s\\S]*?\\*\\//g, '')
        .replace(/(^|[^:])\\/\\/.*\$/gm, '\$1')
        .replace(/,\\s*([}\\]])/g, '\$1');
      const obj = JSON.parse(cleaned);
      fs.writeFileSync('$MCP_DIR/mcp.json', JSON.stringify(obj, null, 2) + '\n');
    " 2>&1; then
      echo "  ✓ $MCP_DIR/mcp.json (原 JSONC 已转纯 JSON；备份 .bak.${TS})"
    else
      echo "  ✗ strip 失败，保留原文件（手动 diff: pi/mcp.template.jsonc）"
    fi
  fi
else
  jsonc_to_json "$PROJECT_ROOT/pi/mcp.template.jsonc" "$MCP_DIR/mcp.json"
  echo "  ℹ️  装到 $MCP_DIR/mcp.json（user-global，跨工具共享）"
fi

# ───────────────────────────────────────────────────────────────────────
# 7. 装 community packages
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "📦 Community packages（如果已装则更新）..."

install_pi_pkg() {
  local pkg="$1"
  local label="$2"
  if pi list 2>/dev/null | grep -q "$pkg"; then
    echo "  ✓ $label 已装 - 跳过（pi update 可升级）"
  else
    echo "  ⏳ 安装 $label..."
    if pi install "$pkg"; then
      echo "  ✓ $label"
    else
      echo "  ✗ $label 安装失败（手动: pi install $pkg）"
    fi
  fi
}

install_local_pi_pkg() {
  local pkg_dir="$1"
  local package_name="$2"
  local label="$3"
  if pi list 2>/dev/null | grep -q "$package_name"; then
    echo "  ✓ $label 已装 - 跳过"
  else
    echo "  ⏳ 安装 $label..."
    if pi install "$pkg_dir"; then
      echo "  ✓ $label"
    else
      echo "  ✗ $label 安装失败（手动: pi install $pkg_dir）"
    fi
  fi
}

if command -v pi >/dev/null 2>&1; then
  install_local_pi_pkg "$PROJECT_ROOT/pi/packages/loop-guard" "starter-pi-loop-guard" "Loop Guard (重复工具/输出熔断)"
  install_pi_pkg "git:github.com/obra/superpowers"     "Superpowers"
  install_pi_pkg "npm:pi-mcp-adapter"                  "pi-mcp-adapter (MCP support)"
  install_pi_pkg "git:github.com/anthropics/skills"    "Anthropic Skills"
  install_pi_pkg "git:github.com/badlogic/pi-skills"   "Pi Skills (badlogic)"
else
  echo "  ⚠️  pi 命令未找到 - 跳过包安装"
  echo "     手动安装: pi install npm:pi-mcp-adapter ..."
fi

# ───────────────────────────────────────────────────────────────────────
# 7b. Pi 官方多文件 example extensions（plan-mode / subagent / sandbox）
# 这三个不通过 pi install 走（subagent/plan-mode 没有 package.json），
# 直接从 Pi 包内置 examples 拷贝/链接到 ~/.pi/agent/。
# ───────────────────────────────────────────────────────────────────────

echo ""
echo "🧩 Pi 官方多文件 extensions..."

PI_PKG_DIR=$(npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent
PI_EXAMPLES="$PI_PKG_DIR/examples/extensions"

if [ -d "$PI_EXAMPLES" ]; then
  # plan-mode: 单 extension 目录（index.ts + utils.ts），整体拷贝
  if [ -d "$PI_EXAMPLES/plan-mode" ]; then
    mkdir -p "$PI_DIR/extensions/plan-mode"
    cp -f "$PI_EXAMPLES/plan-mode/index.ts" "$PI_DIR/extensions/plan-mode/"
    cp -f "$PI_EXAMPLES/plan-mode/utils.ts" "$PI_DIR/extensions/plan-mode/"
    echo "  ✓ plan-mode (/plan, Ctrl+Alt+P toggle read-only mode)"
  fi

  # subagent: extension + agents/*.md + prompts/*.md
  # 用 ln -sf 跟随 Pi 包升级（路径稳定）
  if [ -d "$PI_EXAMPLES/subagent" ]; then
    mkdir -p "$PI_DIR/extensions/subagent" "$PI_DIR/agents"
    ln -sf "$PI_EXAMPLES/subagent/index.ts"  "$PI_DIR/extensions/subagent/index.ts"
    ln -sf "$PI_EXAMPLES/subagent/agents.ts" "$PI_DIR/extensions/subagent/agents.ts"

    # 链接 agent 定义（scout / planner / reviewer / worker）
    for f in "$PI_EXAMPLES/subagent/agents/"*.md; do
      [ -f "$f" ] || continue
      ln -sf "$f" "$PI_DIR/agents/$(basename "$f")"
    done

    # 链接 workflow prompt（implement / scout-and-plan / implement-and-review）
    for f in "$PI_EXAMPLES/subagent/prompts/"*.md; do
      [ -f "$f" ] || continue
      ln -sf "$f" "$PI_DIR/prompts/$(basename "$f")"
    done

    echo "  ✓ subagent (delegate to scout/planner/reviewer/worker)"
  fi

  # sandbox: 有 package.json + npm 依赖 (@anthropic-ai/sandbox-runtime)
  # Pi 0.75.5 的 `pi install <local-path>` 不会自动跑 npm install，
  # 所以这里手动 cp 到用户目录再 npm install。
  # bubblewrap (Linux) 或 sandbox-exec (macOS) 必须先装。
  if [ -d "$PI_EXAMPLES/sandbox" ]; then
    if ! command -v bwrap >/dev/null 2>&1 && ! command -v sandbox-exec >/dev/null 2>&1; then
      echo "  ⊘ sandbox 跳过 - 需要 bubblewrap (Linux: apt/yum install bubblewrap)"
    else
      local_sandbox="$PI_DIR/extensions/sandbox"
      mkdir -p "$local_sandbox"
      cp -f "$PI_EXAMPLES/sandbox/index.ts"        "$local_sandbox/"
      cp -f "$PI_EXAMPLES/sandbox/package.json"    "$local_sandbox/"
      [ -f "$PI_EXAMPLES/sandbox/package-lock.json" ] && \
        cp -f "$PI_EXAMPLES/sandbox/package-lock.json" "$local_sandbox/"

      if [ ! -d "$local_sandbox/node_modules" ]; then
        echo "  ⏳ 安装 sandbox npm 依赖 (@anthropic-ai/sandbox-runtime)..."
        (cd "$local_sandbox" && npm install --silent 2>&1 | tail -3)
      fi

      if [ -d "$local_sandbox/node_modules/@anthropic-ai/sandbox-runtime" ]; then
        echo "  ✓ sandbox (OS-level bash sandbox)"
        echo "    ℹ️  配置 ~/.pi/agent/extensions/sandbox/sandbox.json 或 .pi/sandbox.json"
        echo "    ℹ️  如要禁用: echo '{\"enabled\":false}' > $local_sandbox/sandbox.json"
      else
        echo "  ✗ sandbox npm 依赖安装失败 - 跳过"
        rm -rf "$local_sandbox"
      fi
    fi
  fi
else
  echo "  ⚠️  Pi examples 目录未找到 ($PI_EXAMPLES)"
  echo "     手动 npm root -g 找到 pi-coding-agent 包，再 cp/ln examples/extensions/{plan-mode,subagent,sandbox}"
fi

# ───────────────────────────────────────────────────────────────────────
# 8. 完成提示
# ───────────────────────────────────────────────────────────────────────

cat <<EOF

══════════════════════════════════════════════════════════════
✅ Pi 配置安装完成
══════════════════════════════════════════════════════════════

已安装到 $PI_DIR :
  ├── settings.json
  ├── models.json
  ├── keybindings.json
  ├── AGENTS.md          (全局工作流约定 ~200 行)
  ├── themes/
  │   └── kanagawa.json
  ├── extensions/        (自研扩展 + 多文件扩展)
  │   ├── statusbar.ts           (三行自定义状态栏)
  │   ├── todo.ts                (TODO 管理)
  │   ├── git-checkpoint.ts      (每 turn 自动 stash)
  │   ├── dirty-repo-guard.ts    (脏工作区禁切 session)
  │   ├── notify.ts              (agent 等输入时终端通知)
  │   ├── handoff.ts             (lossless 跨 session 转移)
  │   ├── working-indicator.ts   (工作进度)
  │   ├── claude-rules.ts        (.claude/rules 加载)
  │   ├── plan-mode/             (/plan 切 read-only 调研模式)
  │   └── subagent/              (delegate to scout/planner/reviewer/worker)
  ├── agents/                  (subagent 用的角色定义, symlink 到 Pi examples)
  ├── skills/
  │   └── openspec/SKILL.md    (其余 skill 由 packages 提供)
  └── prompts/                 (review/refactor/test/commit/pr/debug/security/docs/explain/perf + subagent workflows)

MCP 配置: $MCP_DIR/mcp.json
  - context7 / filesystem / git / github / fetch / memory / playwright / chrome-devtools

Community packages（pi list 查看）:
  - starter-pi-loop-guard      - 重复工具调用/失败/输出熔断（本地 package）
  - obra/superpowers           - 14 个工程方法论 skill
  - pi-mcp-adapter             - MCP 支持
  - anthropics/skills          - 文档处理 (docx/pdf/pptx/xlsx)
  - badlogic/pi-skills         - web search / 浏览器 / Google API

下一步:
  1. 配 API key:
       export BAILIAN_CODING_API_KEY="..."
       export GITHUB_PERSONAL_ACCESS_TOKEN="..."   # GitHub MCP
       export DATABASE_URL="..."                   # Postgres MCP (可选)

  2. 启动 pi 并验证:
       pi
       /settings           - 设置面板
       /model              - 切模型
       /hotkeys            - 全部快捷键
       /mcp                - MCP 服务器状态
       /mcp setup          - MCP 首次安装向导（从 cursor/claude/codex 导入）
       /skill:brainstorming - 需求探索（superpowers 提供）
       /skill:test-driven-development
       /skill:openspec     - SDD 工作流（项目独有）
       /review             - 代码审查
       /debug              - 系统化调试
       /security           - 安全审查
       /commit             - 生成 commit message
       /plan               - 进入 read-only 调研模式
       /implement <task>   - subagent workflow: scout → planner → worker

  3. 项目级配置:
       在仓库根创建 AGENTS.md 写项目特化约定
       项目级 MCP server 放 .mcp.json
       项目级 Pi override 放 .pi/settings.json / .pi/mcp.json

  4. 出问题:
       :checkhealth ai     - 在 nvim 内
       /mcp reconnect      - 重连所有 MCP
       cat $PI_DIR/AGENTS.md - 看全局约定

EOF
