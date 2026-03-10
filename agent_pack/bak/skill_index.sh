#!/bin/bash
# skill_index.sh
# 用途：扫描 skills/ 目录，生成 copilot/skill_index.md
# 该文件作为 GitHub Copilot 的 skill 索引，让 Copilot 能够感知并调用所有可用 skill
# 何时运行：执行 skill_integration.sh 或 tool_integration.sh 之后
set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$PKG/skills"
OUT_DIR="$PKG/copilot"
OUT="$OUT_DIR/skill_index.md"

mkdir -p "$OUT_DIR"

echo "📋 Generating skill index ..."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  辅助函数：从 SKILL.md 的 YAML frontmatter 中提取字段值
#  用法：extract_front <field> <file>
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
extract_front() {
  local field="$1" file="$2"
  python3 - "$field" "$file" <<'PYEOF'
import sys, re

field, path = sys.argv[1], sys.argv[2]
try:
    text = open(path).read()
    # 提取 --- ... --- frontmatter 块
    m = re.match(r'^---\s*\n(.*?)\n---', text, re.DOTALL)
    if not m:
        sys.exit(0)
    for line in m.group(1).splitlines():
        # 支持 key: value（value 可能跨行缩进，这里只取首行）
        kv = re.match(r'^(\w[\w-]*):\s*(.*)', line)
        if kv and kv.group(1) == field:
            print(kv.group(2).strip())
            sys.exit(0)
except Exception:
    pass
PYEOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  扫描 skills/，收集所有 skill
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
declare -a SKILL_NAMES=()
declare -A SKILL_DESC=()
declare -A SKILL_FILE=()

for entry in "$SKILLS_DIR"/*/; do
  [[ -d "$entry" ]] || continue
  skill_file="$entry/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  dir_name=$(basename "$entry")
  name=$(extract_front "name" "$skill_file")
  [[ -z "$name" ]] && name="$dir_name"

  desc=$(extract_front "description" "$skill_file")
  [[ -z "$desc" ]] && desc="*(no description)*"

  SKILL_NAMES+=("$name")
  SKILL_DESC["$name"]="$desc"
  SKILL_FILE["$name"]="$skill_file"
done

# 排序
IFS=$'\n' SKILL_NAMES=($(printf '%s\n' "${SKILL_NAMES[@]}" | sort))
unset IFS

count=${#SKILL_NAMES[@]}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  写入 copilot/skill_index.md
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
cat <<HEADER
# Skill Index

> **Auto-generated** by \`skill_index.sh\` — do not edit manually.
> Last updated: $(date '+%Y-%m-%d %H:%M')
>
> This file lists all available skills. When a user's request matches a skill's
> description, load the full skill content from the path shown and follow its
> instructions precisely.

**$count skill(s) available.**

---

## Quick Reference

| Skill | Description |
|-------|-------------|
HEADER

for name in "${SKILL_NAMES[@]}"; do
  desc="${SKILL_DESC[$name]}"
  # 截断超长描述用于表格
  short_desc="${desc:0:120}"
  [[ "${#desc}" -gt 120 ]] && short_desc="${short_desc}…"
  echo "| \`$name\` | $short_desc |"
done

cat <<DIVIDER

---

## Full Skill Descriptions

DIVIDER

for name in "${SKILL_NAMES[@]}"; do
  skill_file="${SKILL_FILE[$name]}"
  desc="${SKILL_DESC[$name]}"

  # 计算相对路径（相对于 copilot/ 目录）
  rel_path=$(python3 -c "
import os, sys
out_dir = sys.argv[1]
skill = sys.argv[2]
print(os.path.relpath(skill, out_dir))
" "$OUT_DIR" "$skill_file")

  cat <<ENTRY
### \`$name\`

**When to use:** $desc

**Full instructions:** [\`$rel_path\`]($rel_path)

---
ENTRY
done

} > "$OUT"

echo "✅ Generated: $OUT ($count skills)"
echo "   Skills included:"
for name in "${SKILL_NAMES[@]}"; do
  echo "     · $name"
done
