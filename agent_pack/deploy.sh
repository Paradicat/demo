#!/bin/bash
# deploy.sh
# 用途：在 ~/.claude/ 和 ~/.config/opencode/ 下创建指向本包的软链接
# 何时运行：用户首次部署或更换机器后执行
set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploying agent config from $PKG ..."

# ── 建目标目录（若不存在）────────────────────────────────────────────────
mkdir -p ~/.claude ~/.config/opencode

# ── Claude Code ───────────────────────────────────────────────────────────
ln -sfn "$PKG/GLOBAL.md"              ~/.claude/CLAUDE.md
ln -sfn "$PKG/skills"                 ~/.claude/skills
ln -sfn "$PKG/agents"                 ~/.claude/agents
echo "✅ Claude Code: ~/.claude/ linked"

# ── OpenCode ──────────────────────────────────────────────────────────────
ln -sfn "$PKG/GLOBAL.md"              ~/.config/opencode/AGENTS.md
ln -sfn "$PKG/skills"                 ~/.config/opencode/skills
ln -sfn "$PKG/opencode/opencode.json" ~/.config/opencode/opencode.json
ln -sfn "$PKG/agents"                 ~/.config/opencode/agents
echo "✅ OpenCode: ~/.config/opencode/ linked"

# ── Copilot ───────────────────────────────────────────────────────────────
echo "✅ Copilot: reads ~/.claude/skills/ automatically (no extra config needed)"

echo ""
echo "🎉 Done! PKG=$PKG"
echo "   To add a skill:           mkdir -p $PKG/skills/<name> && vim $PKG/skills/<name>/SKILL.md"
echo "   To update instructions:   vim $PKG/GLOBAL.md"
echo "   To add a 3rd-party skill: git submodule add <url> third_party_skills/<name> && ./skill_integration.sh"
