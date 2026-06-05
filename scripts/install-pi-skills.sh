#!/bin/bash
# Install Superpowers Skills to Pi coding agent
# Usage: ./scripts/install-pi-skills.sh

set -e
shopt -s nullglob

SUPERPOWERS_PATH=~/.pi/agent/git/github.com/obra/superpowers/skills
PI_SKILLS_PATH=~/.pi/agent/skills

copy_matches() {
    local dest="$1"
    shift
    if [ "$#" -gt 0 ]; then
        cp "$@" "$dest"
    fi
}

echo "=== Installing Superpowers Skills to Pi ==="

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

for skill in "${SKILLS[@]}"; do
    echo "Installing: $skill"
    
    # Create skill directory
    mkdir -p "$PI_SKILLS_PATH/$skill"
    
    # Copy SKILL.md
    if [ -f "$SUPERPOWERS_PATH/$skill/SKILL.md" ]; then
        cp "$SUPERPOWERS_PATH/$skill/SKILL.md" "$PI_SKILLS_PATH/$skill/SKILL.md"
    else
        echo "  WARNING: SKILL.md not found for $skill"
    fi
    
    # Copy auxiliary files if they exist
    # systematic-debugging has multiple helper files
    if [ "$skill" == "systematic-debugging" ]; then
        copy_matches "$PI_SKILLS_PATH/$skill/" \
            "$SUPERPOWERS_PATH/$skill"/*.md \
            "$SUPERPOWERS_PATH/$skill"/*.sh \
            "$SUPERPOWERS_PATH/$skill"/*.ts
    fi
    
    # test-driven-development has testing-anti-patterns
    if [ "$skill" == "test-driven-development" ]; then
        copy_matches "$PI_SKILLS_PATH/$skill/" "$SUPERPOWERS_PATH/$skill"/testing-anti-patterns.md
    fi
    
    # brainstorming has scripts (already exists, skip)
    if [ "$skill" == "brainstorming" ]; then
        continue
    fi
    
    # writing-skills has examples and helpers
    if [ "$skill" == "writing-skills" ]; then
        mkdir -p "$PI_SKILLS_PATH/$skill/examples"
        copy_matches "$PI_SKILLS_PATH/$skill/examples/" "$SUPERPOWERS_PATH/$skill"/examples/*.md
        copy_matches "$PI_SKILLS_PATH/$skill/" \
            "$SUPERPOWERS_PATH/$skill"/*.md \
            "$SUPERPOWERS_PATH/$skill"/*.js \
            "$SUPERPOWERS_PATH/$skill"/*.dot
    fi
    
    # subagent-driven-development has prompt templates
    if [ "$skill" == "subagent-driven-development" ]; then
        copy_matches "$PI_SKILLS_PATH/$skill/" "$SUPERPOWERS_PATH/$skill"/*.md
    fi
    
    # requesting-code-review has code-reviewer template
    if [ "$skill" == "requesting-code-review" ]; then
        copy_matches "$PI_SKILLS_PATH/$skill/" "$SUPERPOWERS_PATH/$skill"/*.md
    fi
    
    # writing-plans has plan-document-reviewer
    if [ "$skill" == "writing-plans" ]; then
        copy_matches "$PI_SKILLS_PATH/$skill/" "$SUPERPOWERS_PATH/$skill"/*.md
    fi
    
    # using-superpowers has references
    if [ "$skill" == "using-superpowers" ]; then
        mkdir -p "$PI_SKILLS_PATH/$skill/references"
        copy_matches "$PI_SKILLS_PATH/$skill/references/" "$SUPERPOWERS_PATH/$skill"/references/*.md
    fi
    
    echo "  ✓ Done"
done

echo ""
echo "=== Installed Skills ==="
ls -la "$PI_SKILLS_PATH/"

echo ""
echo "=== Next Steps ==="
echo "1. Restart Pi to load new skills"
echo "2. Use /skill:<name> to invoke a skill"
echo "3. Example: /skill:test-driven-development"
