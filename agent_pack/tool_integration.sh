#!/bin/bash
# tool_integration.sh
# 用途：下载指定 GitHub 项目的 release 压缩包，解压后将二进制放入 tool/，skill 放入 skills/
# 何时运行：首次部署、更新工具版本、或新增工具条目后执行
set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$PKG/work"
TOOL="$PKG/tool"
SKILLS="$PKG/skills"

mkdir -p "$WORK" "$TOOL" "$SKILLS"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GitHub Token（用于访问私有 repo 的 release）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [[ -z "${GH_TOKEN:-}" ]]; then
  read -rsp "🔑 GitHub Personal Access Token: " GH_TOKEN
  echo
fi

if [[ -z "$GH_TOKEN" ]]; then
  echo "❌ No token provided. Exiting."
  exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  工具注册表
#  每个条目定义：
#    REPO       - GitHub 仓库 (owner/repo)
#    TAG        - release tag
#    ASSET      - release 中的压缩包文件名
#    BINS       - 解压后需要复制到 tool/ 的二进制（相对于解压根目录，空格分隔）
#    SKILL_DIR  - 解压后的 skill 目录（相对于解压根目录），为空则跳过
#    SKILL_NAME - 放入 skills/ 时使用的目录名（重命名）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

declare -A TOOLS

# ── wave_reader ───────────────────────────────────────────────
TOOLS[wave_reader.REPO]="Agent123123123/wave_reader"
TOOLS[wave_reader.TAG]="v0.1.2"
TOOLS[wave_reader.ASSET]="wave_reader-linux-x86_64.tar.gz"
TOOLS[wave_reader.BINS]="wave_reader"
TOOLS[wave_reader.SKILL_DIR]="wave-reader"
TOOLS[wave_reader.SKILL_NAME]="wave-reader"

# ── cov_reader ────────────────────────────────────────────────
TOOLS[cov_reader.REPO]="Agent123123123/cov_reader"
TOOLS[cov_reader.TAG]="v0.1.0"
TOOLS[cov_reader.ASSET]="cov_reader-linux-x86_64.tar.gz"
TOOLS[cov_reader.BINS]="cov_reader"
TOOLS[cov_reader.SKILL_DIR]="cov-reader"
TOOLS[cov_reader.SKILL_NAME]="cov-reader"

# ── svlinter ───────────────────────────────────────────────────
TOOLS[svlinter.REPO]="YuunqiLiu/svlinter"
TOOLS[svlinter.TAG]="v0.1.0"
TOOLS[svlinter.ASSET]="svlinter-linux-x86_64.tar.gz"
TOOLS[svlinter.BINS]="svlinter"
TOOLS[svlinter.SKILL_DIR]="svlinter"
TOOLS[svlinter.SKILL_NAME]="svlinter"

# ── terminal_manager ──────────────────────────────────────────
TOOLS[terminal_manager.REPO]="Agent123123123/terminal-manager-mcp"
TOOLS[terminal_manager.TAG]="v0.1.5"
TOOLS[terminal_manager.ASSET]="terminal_manager-linux-x86_64.tar.gz"
TOOLS[terminal_manager.BINS]="terminal_manager"
TOOLS[terminal_manager.SKILL_DIR]="terminal-manager"
TOOLS[terminal_manager.SKILL_NAME]="terminal-manager"

# ── fast_elaborator ───────────────────────────────────────────
TOOLS[fast_elaborator.REPO]="Agent123123123/fast_elaborator"
TOOLS[fast_elaborator.TAG]="v0.1.5"
TOOLS[fast_elaborator.ASSET]="fast_elab-linux-x86_64.tar.gz"
TOOLS[fast_elaborator.BINS]="fast_elab"
TOOLS[fast_elaborator.SKILL_DIR]="fast-elaborator"
TOOLS[fast_elaborator.SKILL_NAME]="fast-elaborator"
# ── simforge ──────────────────────────────────────────────
TOOLS[simforge.REPO]="Agent123123123/simforge"
TOOLS[simforge.TAG]="v0.1.1"
TOOLS[simforge.ASSET]="simforge-linux-x86_64.tar.gz"
TOOLS[simforge.BINS]="simforge"
TOOLS[simforge.SKILL_DIR]="simforge"
TOOLS[simforge.SKILL_NAME]="simforge"
# ── rtl_coding_style（仅 skill，无二进制）──────────────────────
TOOLS[rtl_coding_style.REPO]="YuunqiLiu/RTLCodingStyle"
TOOLS[rtl_coding_style.TAG]="v1.0.0"
TOOLS[rtl_coding_style.ASSET]="rtl-coding-style-skill.tar.gz"
TOOLS[rtl_coding_style.BINS]=""
TOOLS[rtl_coding_style.SKILL_DIR]="rtl-coding-style"
TOOLS[rtl_coding_style.SKILL_NAME]="rtl-coding-style"

# ── 新增工具请在此追加 ──────────────────────────────────────────
# TOOLS[my_tool.REPO]="owner/repo"
# TOOLS[my_tool.TAG]="v1.0.0"
# TOOLS[my_tool.ASSET]="my_tool-linux-x86_64.tar.gz"
# TOOLS[my_tool.BINS]="my_tool"
# TOOLS[my_tool.SKILL_DIR]="skill"
# TOOLS[my_tool.SKILL_NAME]="my-tool"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  获取所有已注册的工具名（去重）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
tool_names() {
  printf '%s\n' "${!TOOLS[@]}" | sed 's/\..*//' | sort -u
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  主流程
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
total=0
for name in $(tool_names); do
  repo="${TOOLS[$name.REPO]}"
  tag="${TOOLS[$name.TAG]}"
  asset="${TOOLS[$name.ASSET]}"
  bins="${TOOLS[$name.BINS]}"
  skill_dir="${TOOLS[$name.SKILL_DIR]:-}"
  skill_name="${TOOLS[$name.SKILL_NAME]:-}"

  echo ""
  echo "━━━ $name ($repo @ $tag) ━━━"

  # ── 1. 下载（每次都重新下载，确保获取最新版本）────────────────
  archive="$WORK/$asset"

  echo "  🔍 Fetching asset URL via GitHub API ..."
  asset_url=$(curl -fsSL \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$repo/releases/tags/$tag" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    if a['name'] == '$asset':
        print(a['url'])
        break
")

  if [[ -z "$asset_url" ]]; then
    echo "  ❌ Asset '$asset' not found in release $tag"
    continue
  fi

  echo "  ⬇ Downloading $asset ..."
  curl -fSL \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/octet-stream" \
    -o "$archive" "$asset_url"
  echo "  ✅ Downloaded."

  # ── 2. 解压 ──────────────────────────────────────────────────
  extract_dir="$WORK/${name}_${tag}"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"

  echo "  📦 Extracting to $extract_dir ..."
  if [[ "$asset" == *.tar.gz || "$asset" == *.tgz ]]; then
    tar xzf "$archive" -C "$extract_dir"
  elif [[ "$asset" == *.zip ]]; then
    unzip -qo "$archive" -d "$extract_dir"
  else
    echo "  ❌ Unknown archive format: $asset"
    continue
  fi

  # ── 3. 二进制 → tool/ ───────────────────────────────────────
  for bin in $bins; do
    [[ -z "$bin" ]] && continue
    # 在解压目录中查找该文件（可能在子目录里）
    found=$(find "$extract_dir" -name "$bin" -type f | head -1)
    if [[ -z "$found" ]]; then
      echo "  ⚠ Binary not found: $bin"
      continue
    fi
    cp "$found" "$TOOL/$bin"
    chmod +x "$TOOL/$bin"
    echo "  🔧 Installed binary: tool/$bin"
  done

  # ── 4. Skill → skills/ ──────────────────────────────────────
  if [[ -n "$skill_dir" && -n "$skill_name" ]]; then
    found_skill=$(find "$extract_dir" -type d -name "$skill_dir" | head -1)
    if [[ -z "$found_skill" ]]; then
      echo "  ⚠ Skill dir not found: $skill_dir"
    else
      target="$SKILLS/$skill_name"
      rm -rf "$target"
      mkdir -p "$target"
      # 将 skill 目录里的文件拷入，并把主 .md 文件重命名为 SKILL.md
      for f in "$found_skill"/*; do
        base=$(basename "$f")
        if [[ "$base" == *.md ]]; then
          cp "$f" "$target/SKILL.md"
          echo "  📝 Installed skill: skills/$skill_name/SKILL.md (from $base)"
        else
          cp -r "$f" "$target/$base"
          echo "  📝 Copied: skills/$skill_name/$base"
        fi
      done
    fi
  fi

  ((++total))
done

echo ""
echo "🎉 $total tool(s) integrated."
echo "   Binaries in: $TOOL/"
echo "   Skills in:   $SKILLS/"
echo "   Run deploy.sh to activate on this machine."
