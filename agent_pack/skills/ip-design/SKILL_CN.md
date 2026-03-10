# IP Design Skill (RTL) — 中文翻译版

> 本文件是 SKILL.md 的中文参考翻译，仅供阅读理解。**实际生效的是英文版 SKILL.md**。

---

## 元数据

```yaml
name: ip-design
description: RTL/IP 设计指南 — 全新设计、已有 RTL 补文档、已有文档写 RTL。
  覆盖：规格优先工作流、用户确认门控、项目结构、RTL/filelist/TB/testcase/SDC 同步。
  适用于：设计新 IP、为已有 RTL 写文档、从已有文档实现 RTL、添加 TB，
  或 RTL 设计交付物的任意组合。
```

---

## 核心原则

1. **计划优先**：进入计划模式，列出步骤，逐步执行。
2. **规格优先**：始终生成标准 spec.md → 评审 → 用户确认 → 再做下游工作。
3. **下游同步**：任何需求/RTL 变更必须同步更新 filelist、TB、testcase、SDC。
4. **纯净 RTL**：可综合的 Verilog/SystemVerilog。无宏定义。简洁可移植。
5. **诚实状态**：被阻塞或未验证的任务，绝不标记为完成。见 `reference/status_template.md`。
6. **语言一致**：所有文档跟随用户的沟通语言。
7. **透明共识**：绝不偷偷更改已确认的方案。见 `reference/consensus_rules.md`。
8. **原子更新**：文字 + 图表 + 结构 = 规格文档。必须一起更新。见 `reference/change_management.md`。

## 工作流总览

```
Step 0: 确定入口点 + 交付物
  → Step 1: 项目结构
    → Step 2: 撰写 spec.md（信息来源取决于入口点）
      → Step 3: 规格评审
        → ⛔ 门控: 用户确认规格
          → Step 4: RTL        ← 用户可选
            → Step 5: RTL 评审  ← 当 Step 4 执行或已有 RTL 时
              → Step 6: TB + 冒烟   ← 用户可选
                → Step 7: 全部测试  ← 用户可选
              → Step 8: SDC          ← 用户可选
                → Step 9: Makefile   ← 用户可选
```

**Steps 0–3 和门控始终执行。** Steps 4–9 是用户可选的交付物。

**阻塞规则**（始终对活跃步骤生效）：
- 未确认的规格 → 不做下游工作。
- 未评审的 RTL → 不做 TB。
- 编译未执行或失败 → Step 6 不算完成。
- 任何测试失败 → Step 7 不算完成。

---

## 工作流详解

### Step 0: 入口点与交付物

**0a. 从用户请求确定入口点。**

| 用户说（示例） | 入口 | 规格来源 |
|---------------|------|---------|
| "设计一个 XX" / "从零开始" / "design a new XX" | **NEW** | 从需求撰写 |
| "我有 RTL" / "已有代码" / "I have existing RTL" | **HAS_RTL** | 从 RTL 提取，见 `reference/rtl2doc_guide.md` |
| "我有文档" / "已有 spec" / "I have a design doc" | **HAS_DOC** | 改写已有文档，见 `reference/doc2doc_guide.md` |

⚠️ **入口点由用户决定。绝不从文件系统自动检测。**

**如不明确**，问一次："请问您的起点是什么？（从零设计 / 已有 RTL / 已有文档）"

**如 HAS_RTL 但找不到 RTL 文件**，问："请提供 RTL 文件路径，或放入 `<project>/rtl/`。"

**如 HAS_DOC 但找不到文档**，问："请提供现有文档路径。"

**0b. 确定交付物。**

门控通过后，默认交付物取决于入口：

| 入口 | 门控后默认交付物 | 用户可覆盖？ |
|------|----------------|-------------|
| **NEW** | RTL → 评审 → TB → 测试 → SDC → Makefile（全部） | 可移除任一 |
| **HAS_RTL** | 评审 → TB → 测试 → SDC → Makefile（跳过 RTL） | 可添加 RTL 重写，可移除任一 |
| **HAS_DOC** | RTL → 评审 → TB → 测试 → SDC → Makefile（全部） | 可移除任一 |

询问用户："门控通过后，您需要以下哪些交付物？（默认：[列出默认项]）"

或用户可能提前指定："只要文档" / "文档和 TB" / "全部" — 尊重其选择。

在 status.md 中记录入口点和已选交付物。

**完成标准**：入口点和交付物已确定。进入 Step 1。

---

### Step 1: 项目结构

创建文件夹布局：

```
<project>/
  status.md       ← 来自 reference/status_template.md
  docs/
    spec.md
    *_arch.drawio  ← 可编辑的图表源文件
    *_arch.png     ← 导出的真实 PNG（不是 ASCII 文本）
  rtl/
  tb/              ← 仅基础设施（不含测试激励）
  testcase/        ← 每个测试独立文件（tc001_*.sv, tc002_*.sv）
  work/            ← gitignored 仿真产物
  filelist/
    rtl.f
    tb.f
  constraint/
    design.sdc
```

**完成标准**：所有目录已创建。status.md 已从模板创建。进入 Step 2。

---

### Step 2: 撰写 spec.md

**此步骤始终执行。无论入口点如何，规格必须符合我们的标准。**

**按入口点的信息来源：**

| 入口 | 操作 |
|------|------|
| **NEW** | 从用户需求撰写。为未指定的参数提议默认值。 |
| **HAS_RTL** | 阅读 `reference/rtl2doc_guide.md`。系统性地从 RTL 提取。不要发明行为——记录 RTL 实际做了什么。如 RTL 中缺少信息（如时钟频率），询问用户。 |
| **HAS_DOC** | 阅读 `reference/doc2doc_guide.md`。将已有文档改写为标准格式。保留所有信息。如已有文档有缺口，标记并询问用户填补。 |

**spec.md 必须包含**（所有入口）：

- 时钟定义表（名称、频率、周期、域）
- 复位定义（名称、极性、同步/异步、域）
- I/O 定义表（信号、方向、位宽、时钟/复位域）
- 参数表（名称、默认值、有效范围、派生值）
- 功能列表及边界情况行为
- 模块层次树 + 微架构图（见 `reference/microarch_diagram_guidelines.md`）
  - 创建 `docs/*_arch.drawio` → 导出真实 PNG → 在 spec 中嵌入 `![](./xxx_arch.png)`
- 验证计划：测试用例列表，需有**具体**激励和**可自动化**的通过标准

**一致性验证**（写完后必须执行）：

1. 从以下三处提取模块名：文本规格、图表、交付物列表
2. 三个列表必须完全一致
3. 对于 HAS_RTL / HAS_DOC：交叉检查规格与源材料——不允许信息丢失
4. 如有不匹配 → 在继续之前修复所有

**注释规则**（从此步骤开始适用于所有项目文件）：

- 文件头：≤ 10 行
- 行内注释：仅用于非显而易见的设计决策
- 禁止：教科书式解释、在代码中重复规格内容
- 目标比例：代码 ≥ 60%，注释 ≤ 40%

**完成标准**：spec.md 包含所有必需章节。图表是与文本匹配的真实 PNG。进入 Step 3。

---

### Step 3: 规格评审 — 强制执行

此评审必须进行。根据工具可用性选择一种方式：

**方式 A — 子代理（首选）：**

调用 `runSubagent`，description 为 "Spec document review"，prompt 如下：

```
你是独立的规格评审员。执行以下步骤：
1. 阅读文件：skills/skills/ip-design/reference/doc_review_checklist.md
2. 阅读文件：<project_path>/docs/spec.md
3. 按全部 7 个检查类别评估：
   完整性、内部一致性、清晰度、参数规格、
   验证计划质量、设计论证、格式
4. 每个类别：状态（✅/⚠️/❌）+ 发现 + 建议修复
5. 返回结构化报告：
   - 结论：✅ 就绪 / ⚠️ 需改进 / ❌ 重大缺口
   - 问题表：# | 严重度 🔴/🟡/🔵 | 类别 | 问题 | 修复
```

**HAS_RTL 补充**：标准评审后，使用 `reference/rtl2doc_guide.md` Phase 3 交叉检查规格与 RTL。

**HAS_DOC 补充**：标准评审后，交叉检查规格与原始文档——验证改写过程中无信息丢失。

**方式 B — 自我评审（备选）**：相同检查表，记录在 status.md，注明"自我评审模式"。

**评审后**：修复所有 ⚠️ 和 ❌ 问题。进入门控。

**完成标准**：评审报告记录在 status.md。所有问题已解决。

---

### ⛔ 门控：用户确认 — 严格协议

**G1.** 在 status.md 中写入：`## ⛔ 门控：等待用户确认`

**G2.** 发送此消息（翻译为用户语言）：
```
✅ spec.md 已完成并经过内部评审。
📋 请审阅 docs/spec.md，特别注意：[列出 3-5 个关键参数]
⏸️ 等待您的确认。请回复"确认"或提出修改意见。
⚠️ 在您明确确认之前，我不会开始任何下游工作。
📦 确认后将执行：[列出已选定的交付物]
```

**G3.** 检查是否有明确确认：
- ✅ 有效："确认" / "没问题" / "可以" / "同意" / "通过" / "好的" / "confirmed" / "OK" / "yes"
- ❌ 无效："继续" / "你继续" 单独出现 → 回复："我需要您对 spec 的明确确认。请回复'确认'。"

**G4.** 确认后：在 status.md 中写入 `## ⛔ 门控：已通过 — 用户于 <日期> 确认`

**G5.** 继续执行已选定的交付物。

---

### Step 4: RTL + Filelist

**执行条件**：用户选择了 RTL 作为交付物（NEW、HAS_DOC 默认；HAS_RTL 默认跳过，除非用户要求重写）。

**如 HAS_RTL 且不重写**：仅在缺失时创建 `filelist/rtl.f`，然后跳到 Step 5。

创建可综合 RTL。更新 `filelist/rtl.f`（依赖顺序：叶子模块在前）。

**编码规则**：

- 文件头 ≤ 10 行
- 注释中不写教科书式解释
- 组合逻辑用 `output wire`；仅当由 always 块驱动时用 `output reg`
- 同步器寄存器上的 `(* ASYNC_REG = "TRUE" *)` 必须生效——不能被注释掉
- 不能用 `assign` 驱动 `output reg`
- 异步 FIFO 满/空标志：**仅在格雷码域比较**（Cummings 方法）

**完成标准**：所有 RTL 文件已创建。filelist/rtl.f 按依赖顺序排列。

---

### Step 5: RTL 代码评审 — 强制执行（当 RTL 存在时）

**执行条件**：Step 4 已执行，或入口为 HAS_RTL（评审已有代码）。

调用 `runSubagent`（或自我评审），使用 `reference/rtl_review_checklist.md`。检查全部 7 个类别：可综合性、CDC、时序、面积、功能正确性、可验证性、规格合规。

**评审后**：修复所有 🔴 问题。如 bug 暗示规格理解错误 → 返回用户。

**完成标准**：评审报告记录在 status.md。所有 🔴 问题已修复。

---

### Step 6: 测试平台 + 冒烟测试 — 必须编译并运行

**执行条件**：用户选择了 TB 作为交付物。

**阅读 `reference/testbench_architecture.md` 获取代码模板。**

关键规则：
- tb/ = 仅基础设施。testcase/ = 仅激励。
- **❌ 绝不使用 `import module_name::*`** — module 不是 package。
- 使用层次引用或 include 模式。
- 跨时钟共享资源：每个时钟域使用独立队列。

**编译协议**：

```
C1. 检测：which vcs / which iverilog
C2. 都不可用 → ⏸️ 阻塞，告知用户。不标记为完成。
C3. 编译 → 要求 0 错误。
C4. 运行冒烟测试 → 要求 grep "PASSED"。
C5. 记录在 status.md。
```

**完成标准**：编译 0 错误。冒烟测试输出 PASSED。证据在 status.md 中。

---

### Step 7: 全部测试用例 — 必须逐个执行

**执行条件**：用户选择了测试作为交付物（需要 Step 6）。

实现规格验证计划中的所有测试用例。每个测试在独立文件中。

对每个测试：编译 → 运行 → 验证 PASSED → 记录在 status.md。调试失败项。

**完成标准**：所有测试用例 PASSED。如有任何未执行 → 不算完成。

---

### Step 8: SDC 约束

**执行条件**：用户选择了 SDC 作为交付物。

创建与规格一致的 `constraint/design.sdc`。包含：时钟定义、异步组、CDC 约束、I/O 延迟、复位假路径、时钟不确定性。

**一致性规则**：对同一路径对，`set_clock_groups -asynchronous` 和 `set_max_delay` 互斥。

**完成标准**：SDC 存在。频率与规格匹配。无矛盾约束。

---

### Step 9: Makefile

**执行条件**：用户选择了 Makefile 作为交付物（需要 Step 6）。

创建 `tb/Makefile`。目标：`compile_<tc>`、`run_<tc>`、`regression`、`clean`。参数化：`SIM ?= vcs`。

**完成标准**：`make regression` 成功。

---

## 计划模式检查表

```
- [ ] [Step 0] 入口点 + 交付物                ← 始终
- [ ] [Step 1] 项目结构 + status.md           ← 始终
- [ ] [Step 2] spec.md（从需求/RTL/文档）      ← 始终
- [ ] [Step 3] 规格评审                        ← 始终
- [ ] [门控]   用户确认规格                     ← 始终，阻塞
- [ ] [Step 4] RTL + rtl.f                     ← 如选择
- [ ] [Step 5] RTL 评审                        ← 如 RTL 存在（新写或已有）
- [ ] [Step 6] TB + 冒烟测试                   ← 如选择
- [ ] [Step 7] 全部测试用例                     ← 如选择
- [ ] [Step 8] SDC                             ← 如选择
- [ ] [Step 9] Makefile + 回归测试              ← 如选择
```

## 参考文档

| 文档 | 路径 | 何时阅读 |
|------|------|---------|
| RTL 转文档指南 | `reference/rtl2doc_guide.md` | Step 2 HAS_RTL — 从代码提取规格 |
| 文档转文档指南 | `reference/doc2doc_guide.md` | Step 2 HAS_DOC — 改写已有文档为标准格式 |
| 文档评审检查表 | `reference/doc_review_checklist.md` | Step 3 — 规格评审标准 |
| RTL 评审检查表 | `reference/rtl_review_checklist.md` | Step 5 — 代码评审标准 |
| TB 架构 | `reference/testbench_architecture.md` | Step 6/7 — 代码模板 |
| VCS 仿真 | `reference/vcs_sim.md` | Step 6/7 — 编译和调试 |
| 图表指南 | `reference/microarch_diagram_guidelines.md` | Step 2 — 架构图标准 |
| 图表示例 | `reference/microarch_examples.md` | Step 2 — 正确/错误对比 |
| 共识规则 | `reference/consensus_rules.md` | 所有步骤 — 停止讨论协议 |
| 变更管理 | `reference/change_management.md` | 任何变更 — 原子更新规则 |
| 状态模板 | `reference/status_template.md` | Step 1 — 初始 status.md 内容 |
