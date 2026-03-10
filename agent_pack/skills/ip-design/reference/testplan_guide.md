# Testplan 编写规范

本文档定义 `docs/testplan.md` 的格式要求和内容规范。testplan 从 spec.md 中分离，专注于验证策略。

---

## 1. 必须包含的章节

| 章节 | 内容 | 必选 |
|------|------|------|
| 测试平台架构 | 结构框图、scoreboard 策略、时钟/复位描述、仿真器选择 | ✅ |
| TB 时序/调度规则 | driver 时序、monitor 采样、跨时钟域注意事项、drain 等待 | ✅ |
| 参数测试矩阵 | 参数配置组合表，标注哪些 testcase 使用哪些配置 | ✅ |
| 测试用例列表 | 编号、名称、**文件名**、激励描述、通过标准 | ✅ |
| 覆盖率目标 | 行/条件/toggle/功能覆盖率目标值 | ✅ |

---

## 2. Testcase 命名强制规则

**编号 = 文件名前缀**，不可有别名。

```
✅ 正确：
  testplan 编号 tc006 → 文件名 testcase/tc006_concurrent_rw.sv

❌ 错误：
  testplan 编号 tc006 → 文件名 testcase/tc006_sim_read_write.sv
  （"sim_read_write" 与 testplan 中的 "concurrent_rw" 名称不一致）

❌ 更严重的错误：
  testplan 写 tc006，文件名却是 tc006a 或 test_006
```

**命名约定**：
- 前缀：`tc` + 3 位数字（`tc001`, `tc002`, ..., `tc099`, `tc100`）
- 后缀：`_<简短描述>.sv`，使用下划线分隔的英文小写
- 文件名中的描述应与 testplan 中的"测试名称"语义一致
- testplan 表格**必须包含"文件名"列**，明确指定对应的源文件

**交叉检查**（Step 7 开始前）：
- 对比 testplan.md 中的文件名列与 `testcase/` 目录下的实际文件，必须 1:1 对应
- 如有不一致，先修正 testplan 或文件名，再开始实现

---

## 3. TB 时序/调度规则

> 本节定义 testbench 中 driver、monitor、scoreboard 的时序约定，防止 Verilog 仿真调度竞争。

### 3.1 Driver 时序

Driver 驱动 DUT 输入信号时，必须在时钟沿之后添加延迟：

```systemverilog
// ✅ 正确：posedge 后偏移 1ns
@(posedge clk);
#1;
wr_en  = 1;
wr_data = data;

// ✅ 正确：使用 clocking block
clocking cb @(posedge clk);
    default input #1step output #1;
    output wr_en, wr_data;
endclocking
```

```systemverilog
// ❌ 错误：posedge 零延迟驱动 → 与 DUT 采样竞争
@(posedge clk);
wr_en = 1;  // race condition!
```

**原理**：DUT 在 `posedge clk` 采样输入。如果 driver 也在 `posedge` 零延迟驱动，Verilog 仿真器的调度顺序不确定，可能导致 DUT 采到旧值或新值（不确定行为）。延迟 `#1` 确保 DUT 先完成采样，driver 再更新信号（信号在下一个 `posedge` 才被 DUT 看到）。

### 3.2 Monitor/Scoreboard 采样

Monitor 在 `@(posedge clk)` 时采样 DUT 输出：

```systemverilog
// ✅ 正确：posedge 采样 NBA 更新后的值
forever begin
    @(posedge rclk);
    if (rd_en_d && !empty_d) begin
        // rd_data 此时是本拍 NBA 更新后的值
        actual = rd_data;
        expected = ref_queue.pop_front();
        assert(actual === expected);
    end
end
```

**关键点**：
- `@(posedge clk)` 触发时，所有 NBA（`<=`）赋值已在当前仿真时间步完成
- 采样到的是**寄存器输出的最新值**
- 如果 RTL 输出有 N 拍流水延迟，scoreboard 必须在 N 拍后才比较

### 3.3 寄存器输出延迟处理

如果 DUT 的输出是寄存器型（如异步 FIFO 的 `rd_data` 在 `rd_en` 后 1 拍才更新）：

```
时间线：
  cycle N:     rd_en=1, empty=0  → DUT 锁存 mem[raddr]
  cycle N+1:   rd_data 输出有效  → 此时 monitor 才应比较
```

**scoreboard 应对方案**：
- 在 `rd_en && !empty` 时记录"期望数据将在下一拍出现"
- 下一个 `posedge rclk` 再执行实际比较

### 3.4 跨时钟域注意事项

1. **full/empty 信号延迟**：经过 2 级同步器，有 2-3 拍延迟。测试激励不能假设 full/empty 在写入/读出后立即更新。

2. **独立队列**：scoreboard 为写端和读端使用独立队列，不共享跨时钟域变量：
   ```systemverilog
   // ✅ 正确：写端 push，读端 pop，队列本身是异步安全的
   logic [DW-1:0] ref_queue[$];

   // 写端（wclk 域）
   always @(posedge wclk) begin
       if (wr_en && !full) ref_queue.push_back(wr_data);
   end

   // 读端（rclk 域）
   always @(posedge rclk) begin
       if (rd_en_d && !empty_d) begin
           expected = ref_queue.pop_front();
           // 比较...
       end
   end
   ```
   > 注意：SystemVerilog 队列在仿真中由仿真器顺序调度，不存在真正的并发修改。但如果使用类（class）或 mailbox 等，需确认仿真器行为。

3. **drain 等待**：
   - 激励结束后，必须等待足够时间让数据通过 CDC 同步器
   - 最小等待 = `2 × 同步级数 × 慢时钟周期` + `FIFO 深度 × 读时钟周期`
   - 推荐保守值：**100 个慢时钟周期**

---

## 4. 测试用例列表格式

表格必须包含以下列：

| 列名 | 说明 | 必选 |
|------|------|------|
| 编号 | `tcNNN` 格式 | ✅ |
| 测试名称 | 简短中文描述 | ✅ |
| 文件名 | `tcNNN_<desc>.sv`，必须与编号一致 | ✅ |
| 激励描述 | 具体的操作步骤，不是笼统的"测试 XX 功能" | ✅ |
| 通过标准 | **可自动化判断**的标准，如"scoreboard 对比全部通过" | ✅ |

**通过标准要求**：
- 必须是仿真可自动判断的（grep "PASSED"）
- 不能是主观判断（如"功能正确"）
- 应指定具体的检查手段（scoreboard 对比、信号值断言、计数器检查等）

---

## 5. 覆盖率目标格式

```markdown
| 覆盖率类型     | 目标    |
|--------------|--------|
| 行覆盖率      | ≥ N%   |
| 条件覆盖率    | ≥ N%   |
| toggle 覆盖率 | ≥ N%   |
| 功能覆盖点    | 全部 hit |
```

功能覆盖点应明确列出需要覆盖的场景。

---

## 6. 审查清单

写完 testplan 后，逐项检查：

- [ ] 每个 testcase 编号唯一且连续（tc001, tc002, ...）
- [ ] 每个编号都有对应的文件名列，且格式为 `tcNNN_<desc>.sv`
- [ ] 没有"别名"——testplan 中的编号就是文件名前缀
- [ ] 激励描述足够具体，可以直接据此编写代码
- [ ] 通过标准是可自动化的，不含主观判断
- [ ] TB 时序规则已定义（driver 偏移、monitor 采样、drain 等待）
- [ ] 参数矩阵标注了哪些 testcase 使用哪些配置
- [ ] 覆盖率目标已定义
- [ ] 与 spec.md 中的模块列表一致（DUT 名称、信号名、参数名）
