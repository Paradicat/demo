# User Guide — Agent Skill Pack 部署指南

> 目标：下载 Release 包解压后，通过几步操作让 Claude Code、OpenCode、GitHub Copilot 三个工具都能使用本包提供的 Skills、全局指令和 Agents。

---

## 前置条件

在开始之前，确认以下工具已安装：

| 工具 | 确认命令 |
|------|---------|
| Claude Code | `claude --version` |
| OpenCode | `opencode --version` |
| VS Code + GitHub Copilot 扩展 | VS Code 已安装，扩展列表中看到 GitHub Copilot |
| Python 3（用于 tool_integration.sh） | `python3 --version` |
| curl | `curl --version` |

---

## 步骤一：下载并解压 Release 包

前往 [Releases 页面](https://github.com/Agent123123123/skill_pack/releases)，下载最新版本的 `skill_pack-vX.Y.Z.tar.gz`。

```bash
# 下载（以 v0.1.0 为例，替换为实际版本号）
# 或直接在浏览器下载后拖到目标目录

tar xzf skill_pack-v0.1.0.tar.gz
mv skill_pack-v0.1.0 ~/agent_pack
cd ~/agent_pack
```

> Release 包已包含所有第三方 skill 的完整内容（submodule 已在 CI 打包时展开），无需 git 或额外的网络访问。

---

## 步骤二：安装工具（可选，需要 GitHub Token）

`tool/` 目录存放需要从 GitHub Release 下载的二进制工具（如 `wave_reader`）。如果不需要这些工具可跳过此步骤。

```bash
# 交互式输入 GitHub Personal Access Token
./tool_integration.sh

# 或者通过环境变量传入
GH_TOKEN=<your-token> ./tool_integration.sh
```

脚本执行后，二进制文件会被安装到 `tool/`，对应的 skill 文件会被安装到 `skills/`。

**将 `tool/` 加入 PATH**，在 `~/.bashrc` 或 `~/.zshrc` 中追加：

```bash
export PATH="$HOME/agent_pack/tool:$PATH"
```

然后重新加载 shell：

```bash
source ~/.bashrc   # 或 source ~/.zshrc
```

验证：

```bash
wave_reader info  # 应当输出帮助信息，而不是 command not found
```

---

## 步骤三：运行 deploy.sh

`deploy.sh` 在 `~` 层面创建软链接，让 Claude Code 和 OpenCode 读取本包的文件。

```bash
chmod +x deploy.sh
./deploy.sh
```

预期输出：

```
🚀 Deploying agent config from /home/<user>/agent_pack ...
✅ Claude Code: ~/.claude/ linked
✅ OpenCode: ~/.config/opencode/ linked
✅ Copilot: reads ~/.claude/skills/ automatically (no extra config needed)
🎉 Done!
```

验证软链接是否正确创建：

```bash
ls -la ~/.claude/
# 应看到：CLAUDE.md -> .../agent_pack/GLOBAL.md
#         skills    -> .../agent_pack/skills
#         agents    -> .../agent_pack/agents

ls -la ~/.config/opencode/
# 应看到：AGENTS.md    -> .../agent_pack/GLOBAL.md
#         skills       -> .../agent_pack/skills
#         agents       -> .../agent_pack/agents
#         opencode.json -> .../agent_pack/opencode/opencode.json
```

---

## 步骤四：配置 GitHub Copilot（VS Code 用户设置）

GitHub Copilot 没有原生的全局指令目录，需要在 VS Code **用户级** `settings.json` 中手动配置，才能让 Copilot 读取本包的全局指令和 Skills。

### 4.1 打开用户设置

- 快捷键：`Ctrl+Shift+P` → 输入 `Open User Settings JSON` → 回车
- 或手动编辑：`~/.config/Code/User/settings.json`（Linux）/ `~/Library/Application Support/Code/User/settings.json`（macOS）

### 4.2 添加全局指令

让 Copilot 在每次对话中读取 `GLOBAL.md`，其中包含通用行为规范和 skill 索引：

```json
{
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ],
  "github.copilot.chat.reviewSelection.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ],
  "github.copilot.chat.commitMessageGeneration.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ],
  "github.copilot.chat.testGeneration.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ]
}
```

> 这里引用的是 `~/.claude/CLAUDE.md`，它实际上是指向本包 `GLOBAL.md` 的软链接。内容与 Claude Code / OpenCode 读取的完全一致。

### 4.3 启用 Prompt Files（skill 文件支持）

VS Code 1.97+ 支持通过 `chat.instructionsFilesLocations` 让 Copilot 自动扫描额外的指令文件目录：

```json
{
  "chat.promptFiles": true,
  "chat.instructionsFilesLocations": {
    "${env:HOME}/.claude/skills": true
  }
}
```

配置后，`~/.claude/skills/` 下的所有 `SKILL.md` 文件都会被 Copilot 作为候选指令来源加载。

> **注意**：`chat.instructionsFilesLocations` 要求 VS Code ≥ 1.97。如果设置不生效，检查 VS Code 版本（Help → About）并升级。

### 4.4 完整 settings.json 示例

将以下内容合并进你的 `settings.json`（保留已有的其他配置）：

```json
{
  "chat.promptFiles": true,
  "chat.instructionsFilesLocations": {
    "${env:HOME}/.claude/skills": true
  },
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ],
  "github.copilot.chat.reviewSelection.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ],
  "github.copilot.chat.commitMessageGeneration.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ],
  "github.copilot.chat.testGeneration.instructions": [
    { "file": "${env:HOME}/.claude/CLAUDE.md" }
  ]
}
```

**修改后不需要重启 VS Code**，Copilot 会在下次聊天时自动生效。

---

## 验证各工具

### Claude Code

```bash
claude
# 在交互界面中输入：/context 或 help
# 应看到 skills 和 agents 已加载
```

或者直接问 Claude Code：
> "list the skills you have access to"

### OpenCode

```bash
opencode
# 在交互界面中验证
```

### GitHub Copilot

在 VS Code 中打开 Copilot Chat（`Ctrl+Alt+I`），输入：
> "What skills or custom instructions do you have?"

Copilot 应当能提到 GLOBAL.md 中的内容。

---

## 功能总览

部署完成后，三个工具的功能支持情况：

| 功能 | Claude Code | OpenCode | Copilot |
|------|:-----------:|:--------:|:-------:|
| 全局指令（GLOBAL.md） | ✅ | ✅ | ✅ 通过 settings.json |
| Skills（`skills/*/SKILL.md`） | ✅ 自动 | ✅ 自动 | ✅ 通过 settings.json |
| Sub-Agents（`agents/*.md`） | ✅ | ✅ | ❌ Copilot 无此机制 |
| 工具二进制（`tool/`） | ✅ 通过 PATH | ✅ 通过 PATH | ✅ 通过 PATH（terminal） |
| 第三方 Skills | ✅ | ✅ | ✅ |

---

## 后续维护

| 操作 | 命令 |
|------|------|
| 修改全局指令 | 直接编辑 `GLOBAL.md`，三工具立即生效 |
| 新增自有 skill | `mkdir -p skills/<name> && vim skills/<name>/SKILL.md` |
| 升级到新版本 Release | 下载新版 tarball，解压到新目录，运行 `./deploy.sh` 重新链接（旧目录可删除） |
| 换机器重新部署 | 下载 Release 包，解压，运行 `./tool_integration.sh`（若需要），运行 `./deploy.sh`，配置 VS Code settings.json |
