#!/bin/bash
# One-click setup: Install Superpowers Skills + Update Pi Settings
# Usage: ./scripts/setup-pi-superpowers.sh
#
# This script copies all superpowers skills to ~/.pi/agent/skills/
# and updates settings.json to enable skill commands.

set -e

SUPERPOWERS_PATH=~/.pi/agent/git/github.com/obra/superpowers/skills
PI_SKILLS_PATH=~/.pi/agent/skills
PI_SETTINGS=~/.pi/agent/settings.json

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Pi Superpowers Skills Installer                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
if [ ! -d "$SUPERPOWERS_PATH" ]; then
    echo "ERROR: Superpowers package not found at $SUPERPOWERS_PATH"
    echo "       Make sure superpowers is installed in Pi settings:"
    echo "       'packages': ['git:github.com/obra/superpowers']"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required. Install with:"
    echo "       apt-get install jq  # Debian/Ubuntu"
    echo "       brew install jq     # macOS"
    exit 1
fi

# Skills to install (excluding brainstorming which already exists)
SKILLS=(
    "test-driven-development"
    "systematic-debugging"
    "verification-before-completion"
    "writing-plans"
    "executing-plans"
    "using-git-worktrees"
    "finishing-a-development-branch"
    "dispatching-parallel-agents"
    "subagent-driven-development"
    "requesting-code-review"
    "receiving-code-review"
    "writing-skills"
    "using-superpowers"
)

echo "Step 1: Installing Skills..."
echo ""

for skill in "${SKILLS[@]}"; do
    echo "  → $skill"
    mkdir -p "$PI_SKILLS_PATH/$skill"
    
    # Copy SKILL.md (required)
    if [ -f "$SUPERPOWERS_PATH/$skill/SKILL.md" ]; then
        cp "$SUPERPOWERS_PATH/$skill/SKILL.md" "$PI_SKILLS_PATH/$skill/SKILL.md"
    else
        echo "    WARNING: SKILL.md not found"
        continue
    fi
    
    # Copy auxiliary files based on skill type
    case "$skill" in
        "systematic-debugging")
            cp "$SUPERPOWERS_PATH/$skill/"*.md "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            cp "$SUPERPOWERS_PATH/$skill/"*.sh "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            cp "$SUPERPOWERS_PATH/$skill/"*.ts "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            ;;
        "test-driven-development")
            cp "$SUPERPOWERS_PATH/$skill/testing-anti-patterns.md" "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            ;;
        "writing-skills")
            mkdir -p "$PI_SKILLS_PATH/$skill/examples"
            cp "$SUPERPOWERS_PATH/$skill/examples/"*.md "$PI_SKILLS_PATH/$skill/examples/" 2>/dev/null || true
            cp "$SUPERPOWERS_PATH/$skill/"*.md "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            cp "$SUPERPOWERS_PATH/$skill/"*.js "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            cp "$SUPERPOWERS_PATH/$skill/"*.dot "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            ;;
        "subagent-driven-development"|"requesting-code-review"|"writing-plans")
            cp "$SUPERPOWERS_PATH/$skill/"*.md "$PI_SKILLS_PATH/$skill/" 2>/dev/null || true
            ;;
        "using-superpowers")
            mkdir -p "$PI_SKILLS_PATH/$skill/references"
            cp "$SUPERPOWERS_PATH/$skill/references/"*.md "$PI_SKILLS_PATH/$skill/references/" 2>/dev/null || true
            ;;
    esac
    
    echo "    ✓ Installed"
done

echo ""
echo "Step 2: Updating settings.json..."
echo ""

# Ensure enableSkillCommands is true
jq '.enableSkillCommands = true' "$PI_SETTINGS" > "${PI_SETTINGS}.tmp" && mv "${PI_SETTINGS}.tmp" "$PI_SETTINGS"
echo "  ✓ enableSkillCommands = true"

# Add enabledSkills reference (optional metadata)
if ! jq -e '.enabledSkills' "$PI_SETTINGS" > /dev/null 2>&1; then
    jq '.enabledSkills = ["brainstorming", "openspec", "test-driven-development", "systematic-debugging", "verification-before-completion", "writing-plans", "executing-plans", "using-git-worktrees", "finishing-a-development-branch", "dispatching-parallel-agents", "subagent-driven-development", "requesting-code-review", "receiving-code-review", "writing-skills", "using-superpowers"]' "$PI_SETTINGS" > "${PI_SETTINGS}.tmp" && mv "${PI_SETTINGS}.tmp" "$PI_SETTINGS"
    echo "  ✓ enabledSkills array added"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Installed Skills:"
ls -1 "$PI_SKILLS_PATH/"
echo ""
echo "Total: $(ls -1 "$PI_SKILLS_PATH/" | wc -l) skills"
echo ""
echo "Next Steps:"
echo "  1. Restart Pi: pi"
echo "  2. Verify: /skills or /help"
echo "  3. Use: /skill:test-driven-development"
echo ""