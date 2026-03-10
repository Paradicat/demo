# Verdi PLI 库 LTO 版本不匹配导致链接失败

## 基本信息

| 字段 | 值 |
|------|-----|
| 工具 | VCS L-2016.06 + Verdi 2016 |
| 操作系统 | Ubuntu (GCC 11+) |
| 发现日期 | 2026-02-16 |
| 严重程度 | 阻塞 |

## 现象

VCS 编译 RTL 和 testbench 时，parsing 和 elaboration 均成功，但在最后的链接阶段报错：

```
lto1: fatal error: bytecode stream in file
'/home/.../verdi_2016/share/PLI/VCS/LINUX64/pli.a'
generated with LTO version 2.2 instead of the expected 6.2
compilation terminated.
lto-wrapper: fatal error: g++ returned 1 exit status
compilation terminated.
/usr/bin/ld: error: lto-wrapper failed
collect2: error: ld returned 1 exit status
```

VCS 自动链接了 Verdi 的 PLI 库 `pli.a`，该库是用旧版 GCC（LTO 2.2）编译的，而系统当前的 GCC（LTO 6.2）无法解析这个旧版 LTO bytecode。

## 根因分析

1. **Verdi PLI 库编译版本过旧**：Verdi 2016 的 `pli.a` 是用 GCC 4.x 编译的，带有 LTO 2.2 格式的 bytecode
2. **系统 GCC 版本过新**：Ubuntu 上的 GCC 11+ 使用 LTO 6.2，无法向后兼容解析 LTO 2.2
3. **VCS 自动集成 Verdi**：当环境变量 `VERDI_HOME` 或 `NOVAS_HOME` 被设置时，VCS 会自动在链接阶段加入 Verdi 的 PLI 库

## 解决方案

### 方案 A：禁用 Verdi PLI 集成（推荐）

在 VCS 编译命令中添加 `+vcs+novarun`，阻止 VCS 链接 Verdi PLI 库：

```bash
vcs -full64 -sverilog \
    +vcs+novarun \
    -f filelist/rtl.f -f filelist/tb.f \
    -o simv
```

> **注意**：VCS L-2016.06 会报 `Warning-[UNK_COMP_ARG] Unknown compile time plus argument 'vcs+novarun'`，但实际效果是不链接 Verdi PLI。可忽略此告警。

### 方案 B：同时解决 PIE 链接问题

如果禁用 Verdi PLI 后出现 PIE 相关错误：

```
/usr/bin/ld: .../vcs_save_restore_new.o: relocation R_X86_64_32S against symbol
'_sigintr' can not be used when making a PIE object
```

需要额外添加 `-no-pie` 链接选项：

```bash
vcs -full64 -sverilog \
    +vcs+novarun \
    -LDFLAGS -Wl,--no-as-needed \
    -LDFLAGS -no-pie \
    -f filelist/rtl.f -f filelist/tb.f \
    -o simv
```

### 方案 C：完整的 Makefile 配置

```makefile
VCS_FLAGS  = -full64
VCS_FLAGS += -sverilog
VCS_FLAGS += -timescale=1ns/1ps
VCS_FLAGS += -debug_access+all
VCS_FLAGS += +lint=TFIPC-L
VCS_FLAGS += +vcs+novarun
VCS_FLAGS += -LDFLAGS -Wl,--no-as-needed
VCS_FLAGS += -LDFLAGS -no-pie
```

### 方案 D：从根本上解决（需要 IT 支持）

- 升级 Verdi 到与系统 GCC 兼容的版本
- 或者安装 VCS 配套版本的 GCC（如 GCC 4.8），并通过 VCS 的 `-gcc_home` 选项指定

## 备注

- `-lca` 和 `-kdb` 选项也会触发 Verdi 库的链接，如不需要 Verdi KDB 数据库，建议一并去掉
- 去掉 Verdi 集成后，`$fsdbDumpfile` / `$fsdbDumpvars` 系统调用将不可用。如需波形，改用 VCD 格式：`$dumpfile` / `$dumpvars`
- 该问题在 VCS 2016 + Ubuntu 22.04/24.04 上普遍存在，CentOS 7（GCC 4.8）上不会出现
