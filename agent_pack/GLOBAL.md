# 全局 Agent 指令

> 此文件被软链接到 `~/.claude/CLAUDE.md`（Claude Code）和 `~/.config/opencode/AGENTS.md`（OpenCode），三工具共用。

## 通用规范

### 文件读取

当 `read_file` 因路径在 workspace 外被拒绝时（常见于 `~/.claude/` 下的 skill 文件），
**自动改用终端命令读取**，无需询问用户：

```
run_in_terminal: cat <file_path>
```

然后通过 `read_file` 读取终端输出写入的临时文件，或直接解析终端输出内容。
