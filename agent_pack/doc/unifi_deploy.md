# 单用户全局统一 Agent 配置方案

> **目标**：在单个用户的 Home 目录下，部署一个"包"，使 GitHub Copilot、Claude Code、OpenCode 三个工具共享同一套 Skills 和全局指令，无需重复维护。
> **最后更新**：2026-02

---

## 一、核心思路

三个工具各自有"全局配置目录"，但路径不同：

| 工具 | 全局配置目录 |
|------|------------|
| Claude Code | `~/.claude/` |
| OpenCode | `~/.config/opencode/` |
| GitHub Copilot | `~/.copilot/`、`~/.claude/`（兼容读取） |

**策略**：建立一个统一源目录 `~/.agent-pkg/`，存放所有真实文件；各工具的配置目录通过软链接指向这里。维护只改 `~/.agent-pkg/`，三工具自动同步。

---

## 二、哪些内容能共享，哪些不能

| 内容 | 能否共享 | 说明 |
|------|:--------:|------|
| **Skills**（`SKILL.md`） | ✅ | `~/.claude/skills/` 被三工具原生扫描，整个目录软链接即可 |
| **全局指令**（`CLAUDE.md` / `AGENTS.md`） | ✅ | 同一个物理文件，分别软链接到两个工具的对应路径 |
| **Agents 定义** | ⚠️ 部分共享 | Claude Code 和 OpenCode 的 Agent 文件格式（schema）**不同**，需分别维护，但可以放在同一个包里统一管理 |
| **opencode.json 配置** | ❌ 仅 OpenCode | Claude Code 不识别此格式 |

---

## 三、包目录结构

所有真实文件集中存放在 `~/.agent-pkg/`：

```
~/.agent-pkg/
├── skill_integration.sh             # 项目构建时运行：将 third_party_skills/ 软链接进 skills/
├── deploy.sh                        # 用户部署时运行：在 ~/.claude/ 和 ~/.config/opencode/ 下创建软链接
├── .gitignore
├── GLOBAL.md                        # 全局指令（三工具共用的核心内容）
│
├── skills/                          # ⭐ 三工具共享的 Skills 主目录（真实目录）
│   ├── .gitkeep
│   ├── code-review/                 #   自有 skill（真实文件，入 Git）
│   │   └── SKILL.md
│   ├── test-generator/              #   自有 skill（真实文件，入 Git）
│   │   └── SKILL.md
│   ├── awesome-skill → ../third_party_skills/awesome-skill   # 软链接，入 Git，由 skill_integration.sh 创建后提交
│   └── db-helper     → ../third_party_skills/db-helper       # 软链接，入 Git，由 skill_integration.sh 创建后提交
│
├── third_party_skills/              # 第三方 Skills（真实文件，由 git submodule 管理）
│   ├── awesome-skill/
│   │   └── SKILL.md
│   └── db-helper/
│       └── SKILL.md
│
├── opencode/                        # OpenCode 专属配置
│   ├── opencode.json
│   └── agents/
│       ├── reviewer.md
│       └── planner.md
│
└── claude/                          # Claude Code 专属配置
    └── agents/
```

---

## 四、软链接映射关系

部署后的链接结构：

```
# Claude Code 全局目录
~/.claude/
├── CLAUDE.md           ──symlink──→  ~/.agent-pkg/GLOBAL.md
├── skills/             ──symlink──→  ~/.agent-pkg/skills/
└── agents/             ──symlink──→  ~/.agent-pkg/claude/agents/

# OpenCode 全局目录
~/.config/opencode/
├── AGENTS.md           ──symlink──→  ~/.agent-pkg/GLOBAL.md   （同一个物理文件）
├── skills/             ──symlink──→  ~/.agent-pkg/skills/      （同一个目录）
├── opencode.json       ──symlink──→  ~/.agent-pkg/opencode/opencode.json
└── agents/             ──symlink──→  ~/.agent-pkg/opencode/agents/

# GitHub Copilot（通过 ~/.claude/skills/ 自动覆盖，无需额外操作）
```

**关键点**：
- `~/.claude/CLAUDE.md` 和 `~/.config/opencode/AGENTS.md` 指向**同一个物理文件** `GLOBAL.md`
- `~/.claude/skills/` 和 `~/.config/opencode/skills/` 指向**同一个物理目录** `~/.agent-pkg/skills/`
- `~/.agent-pkg/skills/` 是真实目录，其中的第三方 skill 条目是指向 `third_party_skills/` 子目录的**软链接**
- 遍历链路：`~/.claude/skills/` → `~/.agent-pkg/skills/` → `awesome-skill`（软链接）→ `third_party_skills/awesome-skill/SKILL.md`，每层只跳一次，三工具 glob 扫描均设置 `symlink: true`，完全支持
- Copilot 自动扫描 `~/.claude/skills/`，不需要额外配置

---

## 五、两个脚本的职责分工

| 脚本 | 何时运行 | 做什么 |
|------|----------|--------|
| `skill_integration.sh` | **项目维护者**添加/删除第三方 skill 后运行 | 遍历 `third_party_skills/`，在 `skills/` 内创建软链接条目 |
| `deploy.sh` | **用户**首次部署或换机器后运行 | 在 `~/.claude/` 和 `~/.config/opencode/` 下创建指向本包的软链接 |

### skill_integration.sh

项目构建时运行，负责将 `third_party_skills/` 里的每个 skill 以软链接形式"集成"进 `skills/`。结果**不入 Git**（.gitignore 掉 `skills/` 下的软链接条目）。

```bash
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

# 为 third_party_skills/ 下每个子目录创建软链接
count=0
for skill_dir in "$PKG/third_party_skills/"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  ln -sfn "../third_party_skills/$skill_name" "$PKG/skills/$skill_name"
  echo "  + $skill_name"
  ((count++))
done

echo "✅ $count third-party skill(s) integrated."
echo "   Run deploy.sh on each machine to activate."
```

### deploy.sh

用户在自己机器上运行，负责在 Home 目录创建软链接。**不处理第三方 skill**，只关心 `~` 层面的链接。

```bash
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
ln -sfn "$PKG/claude/agents"          ~/.claude/agents
echo "✅ Claude Code: ~/.claude/ linked"

# ── OpenCode ──────────────────────────────────────────────────────────────
ln -sfn "$PKG/GLOBAL.md"              ~/.config/opencode/AGENTS.md
ln -sfn "$PKG/skills"                 ~/.config/opencode/skills
ln -sfn "$PKG/opencode/opencode.json" ~/.config/opencode/opencode.json
ln -sfn "$PKG/opencode/agents"        ~/.config/opencode/agents
echo "✅ OpenCode: ~/.config/opencode/ linked"

# ── Copilot ───────────────────────────────────────────────────────────────
echo "✅ Copilot: reads ~/.claude/skills/ automatically (no extra config needed)"

echo ""
echo "🎉 Done! PKG=$PKG"
echo "   To add a skill:           mkdir -p $PKG/skills/<name> && vim $PKG/skills/<name>/SKILL.md"
echo "   To update instructions:   vim $PKG/GLOBAL.md"
echo "   To add a 3rd-party skill: git submodule add <url> third_party_skills/<name> && ./skill_integration.sh"
```

```bash
# 首次使用
chmod +x skill_integration.sh deploy.sh

# 项目维护者（添加第三方 skill 后）
./skill_integration.sh

# 用户（部署到本机）
./deploy.sh
```

---

## 六、日常维护

### 新增一个 Skill

```bash
mkdir -p ~/.agent-pkg/skills/my-new-skill
cat > ~/.agent-pkg/skills/my-new-skill/SKILL.md << 'EOF'
---
name: my-new-skill
description: 描述这个 Skill 的功能，Agent 会根据此描述决定何时调用。
---

# My New Skill

## 步骤
1. ...
2. ...
EOF
```

三工具**无需任何额外操作**即可发现新 Skill（软链接目录，文件系统变更立即生效）。

### 更新全局指令

```bash
vim ~/.agent-pkg/GLOBAL.md
```

Claude Code（读 `~/.claude/CLAUDE.md`）和 OpenCode（读 `~/.config/opencode/AGENTS.md`）同时更新。

### 更新 OpenCode 配置

```bash
vim ~/.agent-pkg/opencode/opencode.json
```

### 验证软链接状态

```bash
echo "=== Claude Code ===" && ls -la ~/.claude/
echo "=== OpenCode ==" && ls -la ~/.config/opencode/
echo "=== Skills (含第三方) ==" && ls -la ~/.agent-pkg/skills/
```

---

## 七、第三方 Skill 管理

### 目录结构约定

`third_party_skills/` 下每个子目录是一个独立的第三方 skill，可以用不同方式管理：

```bash
~/.agent-pkg/third_party_skills/
├── awesome-skill/      # 方式A：直接复制的静态文件
├── db-helper/          # 方式B：git submodule（推荐，可追踪版本）
└── api-tools/          # 方式C：git subtree
```

### 使用 git submodule 管理（推荐）

```bash
cd ~/.agent-pkg

# 1. 添加一个第三方 skill（submodule）
git submodule add https://github.com/example/awesome-skill third_party_skills/awesome-skill

# 2. 在 skills/ 下创建软链接条目
./skill_integration.sh

# 3. 提交软链接 + submodule 引用（Git 以 mode 120000 存储软链接目标路径）
git add skills/awesome-skill third_party_skills/awesome-skill .gitmodules
git commit -m "feat: add awesome-skill"
git push

# ── 其他维护命令 ──────────────────────────────────────────────────────────
# 更新所有第三方 skill 到最新版本
git submodule update --remote && git add third_party_skills && git commit -m "chore: update submodules"

# 用户克隆时同时拉取所有第三方 skill（submodule 和软链接同时还原）
git clone --recurse-submodules https://github.com/your/agent-pkg ~/.agent-pkg
```

添加完 submodule、运行 `skill_integration.sh` 并 **commit + push** 后，用户只需 `git clone --recurse-submodules` + `./deploy.sh`，**无需自己运行 `skill_integration.sh`**。

### 手动添加第三方 Skill

```bash
# 复制 skill 文件
cp -r /path/to/some-skill ~/.agent-pkg/third_party_skills/some-skill

# 创建软链接条目并提交
./skill_integration.sh
git add skills/some-skill third_party_skills/some-skill
git commit -m "feat: add some-skill"
```

### 移除第三方 Skill

```bash
cd ~/.agent-pkg

# 如果是 submodule
git submodule deinit third_party_skills/some-skill
git rm third_party_skills/some-skill

# 重新运行集成脚本（自动清理 skills/ 中的残留链接）并提交
./skill_integration.sh
git add skills/
git commit -m "chore: remove some-skill"
```

### Git 如何存储软链接

`skills/` 下的软链接条目（指向 `../third_party_skills/xxx`）**直接入 Git**。Git 以 `mode 120000` 存储软链接，实际存的是目标路径字符串，不会把 `third_party_skills/` 的内容重复打包。

```
# git ls-files --stage skills/ 的输出示例
120000 <hash> 0  skills/awesome-skill   ← 软链接，存目标路径字符串
100644 <hash> 0  skills/code-review/SKILL.md  ← 自有 skill，真实文件
```

克隆时软链接自动还原；`third_party_skills/` 由 submodule 机制还原。两者组合后链接立即生效，**用户无需运行 `skill_integration.sh`**。

---

## 七、GLOBAL.md 模板

`~/.agent-pkg/GLOBAL.md` 的内容同时被 Claude Code 和 OpenCode 读取，建议写兼容两者的通用指令：

```markdown
# 全局 Agent 指令

## 我的工作习惯
- 代码使用 TypeScript strict 模式
- 提交信息遵循 Conventional Commits 规范
- 测试框架优先使用 Vitest / pytest

## 通用约定
- 不要修改 lock 文件，除非明确要求
- 生成代码前先理解现有架构
- 有疑问时优先阅读项目 README 和已有代码风格

## 禁止事项
- 不要在没有确认的情况下删除文件
- 不要硬编码 API Key 或密码
```

---

## 八、SKILL.md 编写规范

每个 Skill 必须包含有效的 YAML frontmatter：

```markdown
---
name: skill-name          # 必填，1-64字符，小写字母数字+连字符，如 code-review
description: >            # 必填，1-1024字符，Agent 根据此描述决定何时调用
  清晰描述此 Skill 的功能和适用场景。
license: MIT              # 可选
---

# Skill 标题

## 目标
说明此 Skill 要完成什么任务。

## 步骤
1. 第一步
2. 第二步

## 约束
- 必须遵守的规则
```

**命名规则**（OpenCode 强制校验）：
- 正则：`^[a-z0-9]+(-[a-z0-9]+)*$`
- 目录名必须与 `name` 字段完全一致
- 不能以 `-` 开头或结尾，不能有连续 `--`

---

## 九、各工具读取路径速查

| 路径 | Claude Code | OpenCode | Copilot |
|------|:-----------:|:--------:|:-------:|
| `~/.claude/CLAUDE.md` | ✅ | ✅ fallback | ✅ 兼容 |
| `~/.config/opencode/AGENTS.md` | ❌ | ✅ | ❌ |
| `~/.claude/skills/*/SKILL.md` | ✅ | ✅ | ✅ |
| `~/.config/opencode/skills/*/SKILL.md` | ❌ | ✅ | ❌ |
| `~/.config/opencode/agents/*.md` | ❌ | ✅ | ❌ |
| `~/.claude/agents/*.md` | ✅ | ❌ | ❌ |

> **Skills 的三工具交集路径是 `~/.claude/skills/`**，这是整个方案的核心锚点。
