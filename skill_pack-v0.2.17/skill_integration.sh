#!/bin/bash
# skill_integration.sh
# 用途：将 third_party_skills/ 下所有 skill 软链接进 skills/
# 何时运行：在项目维护时，添加/更新/删除 third_party_skills/ 后执行
set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔗 Integrating third-party skills into skills/ ..."

mkdir -p "$PKG/skills"
mkdir -p "$PKG/third_party_skills"

# 删除 skills/ 下已有的软链接条目（避免残留过期链接）
for link in "$PKG/skills"/*/; do
  if [[ -L "${link%/}" ]]; then
    rm "${link%/}"
  fi
done

# 遍历 third_party_skills/ 下每个 submodule
# 规则（按优先级）：
#   1. 若 submodule 内有 skills/ 子目录 → 从 skills/<name>/ 逐个链接
#   2. 若 submodule 顶层有 SKILL.md    → submodule 本身是单个 skill，整体链接
#   3. 否则                            → submodule 是平铺 skill 集合，逐个链接其子目录
count=0
for submodule_dir in "$PKG/third_party_skills/"/*/; do
  [[ -d "$submodule_dir" ]] || continue
  submodule_name=$(basename "$submodule_dir")
  if [[ -d "${submodule_dir}skills" ]]; then
    # Case 1: submodule 内部还有一层 skills/ 目录，例如 third_party_skills/skills/skills/<name>/
    for skill_dir in "${submodule_dir}skills"/*/; do
      [[ -d "$skill_dir" ]] || continue
      skill_name=$(basename "$skill_dir")
      rel_path="../third_party_skills/$submodule_name/skills/$skill_name"
      ln -sfn "$rel_path" "$PKG/skills/$skill_name"
      echo "  + $skill_name  (from $submodule_name/skills/)"
      ((++count))
    done
  elif [[ -f "${submodule_dir}SKILL.md" ]]; then
    # Case 2: submodule 本身就是一个 skill
    ln -sfn "../third_party_skills/$submodule_name" "$PKG/skills/$submodule_name"
    echo "  + $submodule_name  (from $submodule_name/)"
    ((++count))
  else
    # Case 3: submodule 是平铺 skill 集合，每个含 SKILL.md 的子目录即为一个 skill
    for skill_dir in "${submodule_dir}"*/; do
      [[ -d "$skill_dir" ]] || continue
      [[ -f "${skill_dir}SKILL.md" ]] || continue
      skill_name=$(basename "$skill_dir")
      rel_path="../third_party_skills/$submodule_name/$skill_name"
      ln -sfn "$rel_path" "$PKG/skills/$skill_name"
      echo "  + $skill_name  (from $submodule_name/)"
      ((++count))
    done
  fi
done

echo "✅ $count third-party skill(s) integrated."
echo "   Run deploy.sh on each machine to activate."
