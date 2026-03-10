# Coverage Closure Strategy Reference

## Overview

Coverage closure is a standard downstream task after all testcases pass. It quantifies how thoroughly the DUT has been exercised, identifies verification gaps, and produces evidence for signoff. This document covers **IC verification industry common knowledge** on coverage closure.

---

## 1. What Counts: DUT-only Coverage

### Core Principle

> **只收敛 DUT（Design Under Test）的覆盖率，不收敛 TB/TC 基础设施。**

Testbench、testcase driver、monitor、scoreboard 等验证基础设施 **不是设计交付物**，它们的覆盖率不反映设计质量。

### 实操方法

| 范围 | 是否需要收敛 | 处理方式 |
|------|-------------|---------|
| DUT RTL 模块 | ✅ 是 | 新增 testcase / 修改激励 |
| Testbench top | ❌ 否 | Waiver（scope-level） |
| Testcase 文件 | ❌ 否 | Waiver（scope-level） |
| DUT 内的 DFT 逻辑 | ❌ 通常否 | Waiver + 注明原因 |
| DUT 内的 debug 逻辑 | ❌ 通常否 | Waiver + 注明原因 |
| DUT 内的保留/unused 端口 | ❌ 否 | Waiver + 注明原因 |

### 如何定位 DUT scope

```
cov_reader navigate <tb_top>.u_dut          # 进入 DUT 实例
cov_reader summary                          # 查看 DUT 子模块覆盖率
```

如果 DUT 子模块均 100%，所有覆盖率 hole 都在 TB/TC 侧 → 全部用 waiver 处理即可。

---

## 2. Coverage Types and Their Meaning

### 2a. Code Coverage（代码覆盖率）

| 类型 | 含义 | 典型目标 | 优先级 |
|------|------|---------|--------|
| **Line** | 每行可执行代码是否被执行 | ≥ 95% | 高 |
| **Branch** | 每个 if/else/case 的每个分支是否被走到 | ≥ 95% | 高 |
| **Condition** | 布尔表达式中每个子条件的 true/false 组合 | ≥ 90% | 中 |
| **Toggle** | 每个信号的 0→1 和 1→0 翻转 | ≥ 90% | 中 |
| **FSM** | 状态机的状态和状态转移是否被覆盖 | ≥ 95% | 高 |

### 2b. Functional Coverage（功能覆盖率）

| 类型 | 含义 | 典型目标 |
|------|------|---------|
| **Covergroup/Coverpoint** | 用户定义的功能场景覆盖点 | 100% |
| **Cross coverage** | 多个 coverpoint 的交叉组合 | ≥ 95% |
| **Assertion coverage** | SVA/PSL 断言被 trigger 和 succeed 的比例 | 100% |

> 功能覆盖率由验证工程师在 testplan 中定义，体现 **设计意图** 的覆盖。代码覆盖率是 **实现层面** 的覆盖。两者互补，缺一不可。

---

## 3. Coverage Closure Workflow

```
Step 1: 收集覆盖率
    ↓
Step 2: 合并多 testcase 覆盖率
    ↓
Step 3: Summary 总览（各类型百分比）
    ↓
Step 4: 定位 DUT scope → 只看 DUT 覆盖率
    ↓
Step 5: 分类覆盖率 hole
    ↓
Step 6: 处理 hole（新 TC / waiver）
    ↓
Step 7: 重新收集 → 验证目标达成
    ↓
Step 8: 生成报告 → signoff
```

### Step 5 详解：覆盖率 Hole 分类

| 分类 | 处理方式 | 示例 |
|------|---------|------|
| **可测试的 DUT hole** | 新增/修改 testcase | FIFO full 场景未覆盖、某 FSM 状态未到达 |
| **不可测试的 DUT hole** | Waiver + 原因 | dead code、DFT 引脚、保留字段 |
| **TB/TC 基础设施** | Waiver（scope-level） | testbench、driver、monitor |
| **工具/环境限制** | Waiver + 注明工具 bug | 某些 condition 组合工具报告不准确 |

---

## 4. Waiver Strategy Best Practices

### 原则

1. **能修则修，不能修才 waive** — waiver 是最后手段，不是第一选择
2. **写清原因** — 每个 waiver 必须有 `reason` 字段解释 why
3. **Scope-level 优于 item-level** — 对 TB/TC 整模块排除，不要逐行 waive
4. **Per-item waiver 有格式限制** — VDB 上 branch per-arm waiver 可能静默失败（详见 cov-reader Known Limitations）
5. **Waiver 文件版本控制** — `.cwv.yaml` 必须入库，可追溯
6. **Validate before apply** — 用 `validate_waiver()` 检查语法和匹配数

### 常见 Waiver 原因模板

| 原因类别 | reason 模板 |
|---------|------------|
| TB infrastructure | `"Testbench infrastructure, not DUT code"` |
| DFT logic | `"DFT scan chain / BIST logic, not exercised in functional sim"` |
| Debug-only logic | `"Debug port / trace logic, non-functional path"` |
| Dead code (by design) | `"Reserved field / unused encoding, dead code by architecture spec"` |
| Tool limitation | `"Tool reports unreachable condition combination (VCS bug ID: XXX)"` |
| Async reset | `"Async reset deassertion branch only reachable at power-up"` |
| Power domain | `"Power-gated domain, not testable in RTL sim without UPF"` |

---

## 5. VCS Coverage Collection Cheat Sheet

### 编译时标志

```makefile
# 代码覆盖率
VCS_CM_FLAGS = -cm line+tgl+branch+cond+fsm

# 指定覆盖率数据库目录（多 TC 自动合并到同一 VDB）
VCS_CM_FLAGS += -cm_dir $(COV_DIR)

# 仅收集 DUT 模块的覆盖率（推荐！避免 TB 数据污染）
VCS_CM_FLAGS += -cm_hier cm_hier.cfg
```

### cm_hier.cfg 示例

```
# 只收集 DUT 的覆盖率
+tree tb_top.u_dut

# 排除特定子模块（如 DFT）
-tree tb_top.u_dut.u_dft_wrapper
-tree tb_top.u_dut.u_debug_port
```

> **`-cm_hier` 是 VCS 推荐方式**，在收集阶段就过滤掉 TB/TC，比事后 waiver 更干净。

### 运行时标志

```bash
./simv_cov +tc_name=tc001 -cm line+tgl+branch+cond+fsm -cm_dir $(COV_DIR)
```

### 覆盖率合并

- **VCS 自动合并**：编译和运行时使用相同的 `-cm_dir`，所有 TC 数据自动合并
- **urg 手动合并**：`urg -dir vdb1 -dir vdb2 -dbname merged.vdb`（注意 ncurses 依赖，详见 `eda-toolchain-debug/issues/vcs/004`）

---

## 6. Coverage 收敛常见误区

| 误区 | 正确做法 |
|------|---------|
| 追求 TB 行覆盖率 100% | 只看 DUT 覆盖率，TB 全部 waive |
| 用 waiver 凑数字到 100% | 先尽量补 TC，剩余不可测的才 waive |
| 只看 line coverage | Line + branch + condition + toggle + FSM 五项都要看 |
| 所有类型都要 100% | Toggle 通常 90% 即可（常量信号、保留位不翻转属正常） |
| 合并前看单 TC 覆盖率 | 应该看合并后的整体覆盖率 |
| 忽略 functional coverage | Code coverage 高不代表功能场景覆盖完整 |
| 不用 `-cm_hier` | 从源头过滤 TB 比事后 waiver 更干净高效 |
| 一次跑完所有 TC 才看覆盖率 | 增量策略：先跑几个 → 看 hole → 针对性补 TC → 再看 |

---

## 7. Typical Coverage Targets by Project Phase

| 阶段 | Line | Branch | Condition | Toggle | FSM | Functional |
|------|------|--------|-----------|--------|-----|-----------|
| IP block-level (signoff) | ≥ 95% | ≥ 95% | ≥ 90% | ≥ 90% | ≥ 95% | 100% |
| Subsystem integration | ≥ 90% | ≥ 90% | ≥ 85% | ≥ 85% | ≥ 90% | ≥ 95% |
| SoC top-level | ≥ 80% | ≥ 80% | ≥ 75% | ≥ 80% | ≥ 85% | ≥ 90% |

> 这些是业界典型值。具体目标由项目 signoff checklist 定义，agent 应向用户确认。

---

## 8. Incremental Coverage Closure Strategy

### 增量收敛循环

```
while (coverage < target):
    1. 查看当前 holes（按类型和模块分组）
    2. 选择 impact 最大的 hole（覆盖率最低的模块/类型）
    3. 写 1-2 个 targeted testcase
    4. 跑回归 → 看增量效果
    5. 如果某 hole 3 次尝试无法覆盖 → 标记为不可测 → waiver
```

### 高 Impact 的 testcase 策略

| 覆盖率类型 | 典型缺失场景 | 补充策略 |
|-----------|-------------|---------|
| Line | 错误处理路径 | 注入错误条件（overflow、underflow、invalid input） |
| Branch | else 分支 / default case | 构造落入 else/default 的激励 |
| Condition | 子条件独立翻转 | MC/DC 风格的激励组合 |
| Toggle | 常 0/常 1 信号 | 使用变化激励或 waive（如 tie-off 信号） |
| FSM | 未到达状态/转移 | 构造到达路径的事件序列 |
| Functional | 未命中 coverpoint bin | 对照 testplan 逐个击破 |

---

## 9. Coverage Report Deliverables

Signoff 时通常需要提交：

1. **Coverage summary report** — 各类型覆盖率百分比（effective = after waiver）
2. **Waiver file** — `.cwv.yaml`（或 vendor-specific `.el`/`.vRefine`）+ 入库
3. **Uncovered items list** — 剩余未覆盖项的 justification
4. **Regression log** — 证明所有 TC PASSED
5. **Testplan traceability** — testplan item ↔ testcase ↔ coverpoint 映射

---

## Quick Reference: cov_reader Commands for Coverage Closure

```bash
# 打开覆盖率数据库（直接读 VDB，不要转 UCIS XML）
cov_reader open work/cov_merge.vdb

# 查看总览
cov_reader summary

# 进入 DUT scope
cov_reader navigate tb_top.u_dut

# 查看当前 scope 下的 holes
cov_reader holes --type line
cov_reader holes --type branch
cov_reader holes --type toggle

# Python API：加载 waiver 后查看 effective coverage
python3 -c "
from coverage_reader import open_db, load_waivers, get_summary
db = open_db('work/cov_merge.vdb')
waivers = load_waivers('tb/waivers.cwv.yaml')
summary = get_summary(db, waivers=waivers)
for t, m in summary.items():
    print(f'{t}: {m[\"covered\"]}/{m[\"total\"]} = {m[\"percent\"]:.1f}%')
"
```
