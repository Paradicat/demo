---
name: design-microarch
description: "Use when processing RTL modules at the microarchitecture level - including FIFO, state machines, counters, arbiters, decoders, or any Verilog/SystemVerilog hardware design. Load this skill immediately upon identifying RTL design tasks, before diving into brainstorming，planning or implementation."
---

# RTL Microarchitecture Design Guide

## Overview

This skill provides microarchitecture design guidance for RTL modules. It covers design principles, naming conventions, interface design, module partitioning, and architectural decisions that should be established **before** writing code.

**Core principle**: Good microarchitecture decisions made early prevent costly refactoring later.

## When to Use

Load this skill when:
- User requests RTL design ("design a FIFO", "create a state machine", "build a counter")
- Starting brainstorming phase for any Verilog/SystemVerilog task
- Discussing module interfaces, partitioning, or architecture
- Evaluating different design approaches

**Do NOT wait until coding phase.** Microarchitecture decisions shape the entire design process.

## Core Design Principles

### 1. Interface-First Design

- **低时序耦合**: 接口定义应当保证没有时序耦合。时序耦合指的是模块之间产生了严格的时序关系，例如模块A处理某个输入信号后，模块B必须在同一个时钟周期内对这个信号做出反应。这种耦合会导致设计的脆弱性和难以维护，因为任何微小的时序变化都可能引发功能错误。接口定义应当能够支持模块之间的松耦合，使得模块A和模块B之间没有严格的时序依赖关系，从而提高设计的健壮性和可维护性。

低时序耦合的接口设计包括但不限于下方式：

1. 使用握手信号（如valid/ready）来管理数据传输，避免模块之间的时序依赖。这种形式下接口命名可以统一以业务名称为前缀，xxx_vld、xxx_rdy、xxx_data等，形成一套清晰的接口命名规范。

2. 使用阈值机制来控制数据流，例如上游给下游xxx_en和xxx_data、xxx_addr等载荷，而下游通过xxx_stall等信号来反馈是否准备好接收数据。但这种情况下需要严格计算上游en传播到下游，下游stall再传播到上游的总时间，下游应当有足够的buffer来吸收这个时间，否则就会产生时序耦合。

3. 使用Credit-based flow control机制来管理数据流，例如上游给下游xxx_vld(xxx_en)和xxx_data等载荷，而下游通过xxx_credit等信号来反馈可用的buffer数量，从而实现流量控制。这里要注意下游的credit必须是基于内部真实能够接收数据的buffer数量来设计的，而不能是一个虚拟的值，否则也会产生时序耦合。

4. 采用无流量控制的接口设计，例如上游直接给下游xxx_vld(xxx_en)和xxx_data等载荷，而下游没有任何反馈信号来控制数据流。这种设计虽然简单，但需要保证下游模块能够在任何时候都准备好接收数据，或者当前的这个上下游数据传输是可接受丢包的。

5. 采用标准协议作为链接层，例如AXI、APB、Wishbone等，这些协议其实都是上述方案的变体或者多方案合一的方案，已经被广泛验证过，可以直接使用。

6. 某些特殊的pipeline场景，允许出现严格的时序耦合。但要在更上层的设计中严格论证这个时序耦合是可控的，并且在接口设计中明确标注这个时序耦合的存在和要求。

Define interfaces before implementation:

```
Module Interface Template:
- Clock and reset naming (clk, rst_n)
- Data signals: prefix-based naming (in_vld, in_rdy, in_data)
- Control signals: clear semantic names
- Parameter naming: ALL_CAPS with explicit types
```


### 2. Module Partitioning

Split modules by:
- **Functionality**: 每个模块都应当有较为明确的功能职责，避免一个模块承担过多功能。在对模块进行划分时，上层模块负责一个较大的明确的功能，而下层模块则负责更细粒度的子功能，逐层拆分。直到一个功能单一、清晰的模块为止。
- **Timing**: 不要让非常关键的路径跨越多个模块，通常来说最多只能跨越两个模块。
- **Reusability**: Generic modules vs application-specific modules， 在模块划分的过程中可以考虑是否适用于功能抽象这种方式，即把一些通用的功能划分为一个模块，而业务/场景相关的功能划分到其它模块。通过采取这种方式，可以显著降低模块的复杂度，并且提高模块的可复用性。于此同时，可以考虑当前你有没有已经可以引用的模块，如果有的话，你就可以直接引用，而不需要重新设计一个新的模块。
- **Clock domains**: Separate modules for different clock domains， 除非它们之间的交互非常简单，否则不要把不同clock domain的逻辑放在同一个模块里。
- **Hierarchical levels**: Top-level vs mid-level vs leaf modules， 通常来说，除了leaf modules, 其它上层模块都应该只包含实例化和连接，最多在极端情况下允许出现一些简单的组合逻辑。

### 3. 流水线划分

- 流水线的划分需要一个目标，即两级寄存器之间最多能够接受有多少等价到二进制输入门的组合逻辑门。这个数据完全是由需求决定的，向需求方提问，和需求提供方明确这个需求，而不是由设计者主观决定。如果确实没有这个需求，可以默认为20级组合逻辑。定义好这个LOL的值后，我们在绝大部分地方不能超过，但如果在一些非常特殊的地方确实需要超过这个数值，我们也可以适当放宽这个数值，并且需要和需求提供方沟通清楚。在放宽的同时，我们需要评估这个在前期的适当放宽是否能在后期被优化，这个优化目前我们主要考虑的是我们的延迟估计是基于二输入逻辑门的，而实际工程中，综合工具可能映射成更复杂的逻辑门以降低真实延迟，因此我们在这里可以考虑略微放宽，但通常不能超过15%。

### 4. 参数化

- 在设计时我们应当尽量进行参数化设计，以提高模块的复用性和适应性。在进行参数化时需要注意以下几点:
  - 参数必须在一定范围内真实可切换，也就是说参数值的改变并不会导致功能失效。例如，参数值就不能和电路结构/电路中的常量值产生耦合关系，这时候参数切换就会导致功能失效。
  - 参数耦合约束必须清晰明确，也就是说如果存在参数之间的耦合关系，这个耦合关系必须被清晰地定义和文档化，以便用户在使用时能够正确地设置参数值。


### 5. Physical Awareness

- 在设计时，尽量进行低耦合设计，对于timing较为紧张的路径，可能出现长距离路由的路径，或者必须跨越多个模块的路径，就必须采取低耦合的设计，考虑到未来通过pipeline插入来解决时序问题。

- 在模块划分时，对于装载了实际电路逻辑的模块，需要考虑floorplanning的需求，如果这些电路有可能被放在不同的区域，那么就需要考虑拆分到不同的模块里，以便后续的floorplanning和布局布线。并且他们之间的接口设计也需要考虑到这个物理上的分布，尽量减少跨区域的信号数量和频率，以及采用低耦合的接口设计来降低跨区域通信的时序风险。


### 3. Naming Conventions

**Signal naming**:
- Active-low suffix: `_n` (rst_n)
- Valid/ready pairs: `xxx_vld`, `xxx_rdy`, `xxx_data`
- Vector prefix: `v_` for independent signals of same type
- Consistent prefix for related signals

**Module naming**:
- Descriptive and unique: `sc_bus_arbiter` not `arbiter`
- One module = one file
- File name = module name

**Parameter naming**:
- ALL_CAPS: `DATA_WIDTH`, `FIFO_DEPTH`
- Explicit type: `parameter integer unsigned DATA_WIDTH = 8`

### 4. Clock Domain Crossing

For async designs:
- Identify all clock domains upfront
- 在需要同步器时，采用可参数化配置的同步器，默认值为3拍。
- 对于跨时钟域编码器的设计，有gray code、bitwise encoding、dual-rail encoding等多种方案可选，选择时需要根据实际需求和设计复杂度进行权衡，并且在接口设计中明确标注所采用的编码方式。 

### 5. Reset Strategy

- Define reset type per module (async vs sync)
- Synchronous release always
- 对于每个寄存器reset value，我们应当充分考虑是否需要明确其复位状态。对于一些寄存器，如果其复位状态是什么都不影响功能正确性，我们可以选择不指定reset value，以节省资源和简化设计。但对于那些需要在复位后进入特定状态的寄存器，我们必须明确指定reset value，以确保系统能够正确启动和运行。


### 6. 输出 

微架构设计应该包含以下输出：

- **微架构示意图**: 应当逐层展示模块划分和接口关系。
  - 对于不存在太多实际电路逻辑的上层模块和中层模块，应该画出接口和子模块之间的连接关系，不一定需要展示内部细节。
  - 对于有实际电路逻辑的下层模块，应该画出具体的电路逻辑，比如打拍，状态机，arbiter，寄存器组等。一些繁杂但不敏感的逻辑可以用一个组合逻辑块表示。但通常不需要画出过于细节的电路逻辑，比如组合逻辑门级的细节。
  - 对于不同的层次，在图上的接口的表征可以不同：对于高层次的模块，如果该模块的功能确实涵盖了整个协议，一个协议接口（例如AXI）就可以用一根线表示；对于中层次的模块，如果该模块的功能涵盖了协议的一部分，那么可以用多根线来表示这个接口；对于低层次的模块，通常需要用更细粒度的线来表示每个信号。（比如对于一个AXI SRAM Controller，它对外的输入就是一个AXI接口。而对于它内部的AXI Read Controller，它的输入就是AXI AR和AXI R这两个接口信号线了。）

- **接口定义**: 每个模块的接口定义应当清晰地列出所有输入输出信号的名称、类型（单比特/向量）、方向（输入/输出）、功能描述、所属时钟域、是否有时序耦合等信息。

- **参数化**: 每个模块的参数列表应当清晰地列出所有参数的名称、类型、默认值、功能描述、可选值范围等信息。


## Quick Reference

| Design Aspect | Key Considerations |
|--------------|-------------------|
| **Interface** | Define before implementation, use consistent prefixes |
| **Partitioning** | Single responsibility, separate timing domains |
| **Naming** | Meaningful, consistent, prefix-based for buses |
| **Parameters** | Type-explicit, ALL_CAPS, synthesizable defaults |
| **Clock Domains** | Identify early, plan CDC structures |
| **Reset** | Document type, synchronous release |

## Design Decision Checklist

Before coding, answer:

- [ ] What are the interfaces (inputs/outputs/parameters)?
- [ ] Is this single or multiple clock domains?
- [ ] What's the reset strategy?
- [ ] How should the module be partitioned?
- [ ] What naming conventions apply?
- [ ] Are there reusable sub-modules?
- [ ] What's the parameterization strategy?

## Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| **Inconsistent naming** | Debugging nightmare | Define naming convention upfront |
| **Late partitioning** | Rewrites, bugs | Partition during design phase |
| **No interface spec** | Integration failures | Define all interfaces first |
| **Ignoring CDC** | Metastability, data corruption | Identify clock domains early |
| **Hard-coded values** | Non-reusable modules | Parameterize from start |

## Architectural Patterns

### FIFO Pattern
```
Interfaces:
- Write side: wr_clk, wr_rst_n, wr_en, wr_data, full
- Read side: rd_clk, rd_rst_n, rd_en, rd_data, empty
Key decisions: Depth, width, clock domains, full/empty logic
```

### State Machine Pattern
```
Interfaces:
- Control inputs, status outputs
- State-specific data paths
Key decisions: Encoding (one-hot/binary), state partitioning, FSM type (Moore/Mealy)
```

### Arbiter Pattern
```
Interfaces:
- Request/Grant pairs per master
- Shared resource interface
Key decisions: Arbitration policy, priority scheme, fairness
```

## Integration with Other Skills

- **rtl-coding-style**: This skill focuses on microarchitecture; rtl-coding-style focuses on coding style
- **verification-env**: Consider verification needs during microarchitecture design
- **verification-testplan**: Microarchitecture decisions affect testability

## Real-World Impact

**Good microarchitecture**:
- Clean interfaces → easy integration
- Consistent naming → faster debugging
- Clear partitioning → maintainable code
- Early CDC planning → reliable operation

**Poor microarchitecture**:
- Interface changes late in project → schedule slips
- Inconsistent naming → 2-3x debugging time
- Monolithic modules → hard to test, verify, reuse
- Unplanned CDC → field failures