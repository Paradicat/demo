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
# 若 submodule 内部含有 skills/ 子目录（如 Agent123123123/skills 仓库），则从该层取 skill；
# 否则将 submodule 本身作为单个 skill 整体链接进来。
count=0
for submodule_dir in "$PKG/third_party_skills/"/*/; do
  [[ -d "$submodule_dir" ]] || continue
  if [[ -d "${submodule_dir}skills" ]]; then
    # submodule 内部还有一层 skills/ 目录，例如 third_party_skills/skills/skills/<name>/
    for skill_dir in "${submodule_dir}skills"/*/; do
      [[ -d "$skill_dir" ]] || continue
      skill_name=$(basename "$skill_dir")
      # 计算从 skills/ 到目标的相对路径
      rel_path="../third_party_skills/$(basename "$submodule_dir")/skills/$skill_name"
      ln -sfn "$rel_path" "$PKG/skills/$skill_name"
      echo "  + $skill_name  (from $(basename "$submodule_dir")/skills/)"
      ((++count))
    done
  else
    # submodule 本身就是一个 skill
    skill_name=$(basename "$submodule_dir")
    ln -sfn "../third_party_skills/$skill_name" "$PKG/skills/$skill_name"
    echo "  + $skill_name"
    ((++count))
  fi
done

echo "✅ $count third-party skill(s) integrated."
echo "   Run deploy.sh on each machine to activate."
