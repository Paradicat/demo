# urg 运行时缺少 libncursesw.so.5

## 基本信息

| 字段 | 值 |
|------|-----|
| 工具 | VCS urg（覆盖率合并工具） |
| 操作系统 | Ubuntu 22.04+（默认安装 ncurses 6，不含 ncurses 5） |
| 发现日期 | 2026-02-28 |
| 严重程度 | 有规避方案 |

## 现象

运行 `urg -dir <vdb>` 或 `urg -dir <vdb1> -dir <vdb2>` 时报错：

```
urg: error while loading shared libraries: libncursesw.so.5: cannot open shared object file: No such file or directory
```

## 根因分析

1. **urg 动态链接了 ncurses 5.x**：VCS 随附的 `urg` 二进制文件动态依赖 `libncursesw.so.5`
2. **Ubuntu 22.04+ 仅提供 ncurses 6**：系统默认安装的是 `libncursesw.so.6`，不提供 `.so.5` 的兼容链接
3. **不影响 VCS 本身**：VCS 编译和仿真不依赖 ncurses，仅 `urg` 这个覆盖率合并/报告工具受影响

## 解决方案

### 方案 A：跳过 urg，使用 VCS -cm_dir 自动合并（推荐）

VCS 运行时支持通过 `-cm_dir <shared_dir>` 让所有 testcase 的覆盖率数据自动合并到同一个 VDB 目录，无需事后用 `urg` 合并：

```makefile
COV_DIR = $(WORK_DIR)/cov_merge.vdb

# 编译时指定 -cm_dir
simv_cov:
	$(VCS_BIN) $(VCS_FLAGS) -cm line+tgl+branch+cond \
	    -cm_dir $(COV_DIR) \
	    -f filelist/rtl.f -f filelist/tb.f -o $@

# 运行时也使用相同的 -cm_dir
run_%: simv_cov
	./simv_cov +tc_name=$* -cm line+tgl+branch+cond -cm_dir $(COV_DIR)
```

运行完成后直接用 `cov_reader open $(COV_DIR)` 读取合并后的 VDB，完全绕过 `urg`。

### 方案 B：安装 ncurses 5 兼容库

```bash
# Ubuntu
sudo apt install libncurses5

# 如果包不可用，可创建符号链接（不推荐，可能有兼容性风险）
sudo ln -s /usr/lib/x86_64-linux-gnu/libncursesw.so.6 \
           /usr/lib/x86_64-linux-gnu/libncursesw.so.5
```

### 方案 C：使用容器或 conda 环境

在 Docker 或 conda 环境中安装 ncurses 5 运行时，避免影响宿主系统。

## 注意事项

- **方案 A 是首选**：当使用 `cov_reader` 进行覆盖率分析时，不需要 `urg` 生成报告——`cov_reader` 可以直接读取 VDB
- 方案 B 的符号链接方式存在兼容性风险，仅作为临时 workaround
- 如果必须使用 `urg`（例如需要生成 HTML 报告给其他团队），则需要安装 ncurses 5 兼容库
