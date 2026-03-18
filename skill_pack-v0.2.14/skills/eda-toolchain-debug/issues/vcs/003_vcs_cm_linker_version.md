# VCS 旧版本 -cm 覆盖率标志导致链接失败

## 基本信息

| 字段 | 值 |
|------|-----|
| 工具 | VCS L-2016.06（及其它 2020 年前版本） |
| 操作系统 | Ubuntu / CentOS |
| 发现日期 | 2026-02-28 |
| 严重程度 | 阻塞 |

## 现象

在 VCS 编译命令中添加 `-cm line+tgl+branch+cond` 后，parsing 和 elaboration 均成功，但在链接阶段报错：

```
undefined reference to `vfs_open'
undefined reference to `vfs_close'
undefined reference to `vfs_read'
undefined reference to `vfs_write'
...
collect2: error: ld returned 1 exit status
```

错误来源于覆盖率运行时库（`libcm*.a`）对 VFS 符号的引用，这些符号在旧版本 VCS 安装中不存在或版本不兼容。

去掉 `-cm` 标志后编译恢复正常。

## 根因分析

1. **覆盖率运行时库版本不兼容**：旧版 VCS（如 L-2016.06）的覆盖率运行时库（`libcm*.a`）引用了不存在于该版本安装中的 VFS 符号
2. **ABI 不匹配**：在旧版 VCS 上混用自定义 `-cc`/`-cpp` 编译器标志与 `-cm` 覆盖率标志，可能进一步触发 ABI 不兼容
3. **仅影响链接阶段**：parsing、elaboration 均不受影响，只有覆盖率相关的运行时库在链接时出错

## 解决方案

### 方案 A：使用新版 VCS 进行覆盖率收集（推荐）

在 Makefile 中根据 `COV` 标志切换 VCS 版本：

```makefile
COV ?= 0

ifeq ($(COV),1)
  # 新版 VCS 支持 -cm 覆盖率标志
  VCS_BIN    = /path/to/vcs/W-2024.09-SP1/bin/vcs
  VCS_FLAGS += -cm line+tgl+branch+cond
  VCS_FLAGS += -cm_dir $(COV_DIR)
  # 注意：新版 VCS 通常不需要自定义 -cc/-cpp，使用默认编译器即可
else
  # 旧版 VCS 用于日常非覆盖率仿真
  VCS_BIN    = /path/to/vcs/L-2016.06/bin/vcs
endif
```

### 方案 B：仅升级覆盖率编译目标

如果不想全面切换 VCS 版本，可以只为覆盖率回归创建独立的编译目标：

```makefile
.PHONY: cov_compile
cov_compile:
	$(VCS_NEW) $(VCS_FLAGS) -cm line+tgl+branch+cond \
	    -cm_dir $(COV_DIR) \
	    -f filelist/rtl.f -f filelist/tb.f \
	    -o simv_cov
```

## 注意事项

- 非覆盖率回归可以继续使用旧版 VCS，无需修改 RTL 或 testbench
- 切换到新版 VCS 时应去掉自定义的 `-cc`/`-cpp` 标志，因为新版 VCS 使用的系统编译器已足够兼容
- 如果新版 VCS 同时出现 Verdi PLI 链接问题，参考 [001](001_verdi_pli_lto_mismatch.md)
