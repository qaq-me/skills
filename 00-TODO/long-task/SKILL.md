---
name: long-task
description: la
---

# Long Task

使用本 skill 时，要把一个开放式或长时间运行的请求转换成可恢复、可检查、可交接的任务。重点不是“让 Agent 一直在线”，而是让任务在上下文丢失、后台进程、定时检查和换 Agent 后仍然能继续。

## 核心规则

- 开始长时间执行前，先回复用户，说明将创建哪些任务文件、是否会启动后台工作、预计如何汇报进度。
- 如果目标、验收标准、权限、预算、运行时长或破坏性风险不清楚，先使用 `grill-me` skill 或只问一个关键问题。
- 面向用户的任务文档默认用中文；命令、代码注释、进程日志和工具原始输出默认保留英文。
- 训练、推理、爬取、批处理等长命令必须放到后台或可复用 session 中执行，不要用前台命令阻塞对话。
- 不要 kill、暂停、抢占或接管不是本次 long-task 创建的进程。
- 把 `GOAL.md` 当作任务 contract。可以调整计划和状态，但未经用户同意不要修改最终目标。
- 每个工作周期结束前、handoff 前、重要里程碑后、失败后，都要更新持久状态。

## 任务目录

每个长期任务创建一个独立目录：

```text
long_task/<task-slug>/
├── GOAL.md
├── PLAN.md
├── STATE.md
├── LOG.md
└── REVIEW.md
```

`<task-slug>` 使用短小的 lowercase slug；如果目录已存在，追加日期或编号。如果当前项目已有更强的 long-task 约定，优先遵守项目约定，但必须保留同等信息。

### GOAL.md

记录稳定 contract：

- 任务名和创建时间
- 最终目标
- 验收标准
- 非目标和边界
- 必须取得的用户确认或审批
- 阶段目标及状态：`pending`、`in_progress`、`done`、`blocked`
- 最终交付物

### PLAN.md

记录执行计划：

- 分阶段步骤
- 预计使用的命令、脚本或工具
- 要启动的后台任务，以及如何识别它们
- review 和测试/验证步骤
- 进度汇报节奏
- 高风险操作的回滚或恢复策略

### STATE.md

记录当前运行状态：

- 当前阶段和下一步动作
- 最新已完成工作
- 活跃命令、session、PID、日志路径、输出路径和 owner
- blocker、待决策事项和重试次数
- 最后更新时间
- 给下一轮 Agent 的 resume instruction

### LOG.md

追加简短时间戳事件。记录启动过的命令、关键输出、失败、决策、用户批准和状态迁移。不要粘贴大段日志；大日志只记录路径和摘要。

### REVIEW.md

接近结束时创建或更新。记录本次完成了什么、做过哪些测试、还剩什么风险，以及 `GOAL.md` 里的验收标准是否满足。

## 启动流程

1. 判断任务为什么属于 long task：运行时间长、多轮工作、需要监控、需要后台进程、需要阶段化执行，或需要可恢复 handoff。
2. 只澄清会阻塞执行的问题。高影响设计选择先问用户；常规实现细节保守决策并写入任务文件。
3. 创建任务目录和初始 `GOAL.md`、`PLAN.md`、`STATE.md`、`LOG.md`。
4. 向用户说明任务目录、验收标准、执行阶段和续跑机制。只有当任务存在明显成本、风险、外部副作用或范围不确定时，才必须等用户确认后继续。
5. 用可后台运行的方式开始执行，并把日志、session、PID 或其他标识写入 `STATE.md`。
6. 按约定节奏汇报进度，同时继续推进任务。

## 按平台选择续跑机制

### Claude Code

- 如果环境支持，优先使用 Claude Code 的原生续跑机制，例如 `/loop`。
- loop prompt 必须明确要求下一轮读取：
  - `skills/long-task/loop task.md`
  - `long_task/<task-slug>/GOAL.md`
  - `long_task/<task-slug>/PLAN.md`
  - `long_task/<task-slug>/STATE.md`
  - `long_task/<task-slug>/LOG.md`
- 默认 loop 周期为 30 分钟，除非用户指定其他周期，或任务需要更快监控。
- 开启 loop 前，告诉用户周期、任务目录和 loop instruction 的大意。
- 如果 `/loop` 不可用，就在 `STATE.md` 中写清楚手动 resume prompt；不要声称任务能自动续跑。

### Codex

- Codex 不一定有 Claude 风格的 `/loop`。根据当前环境实际支持，优先选择以下机制之一：
  - 可轮询的长时间 shell session
  - 后台进程，并在 `STATE.md` 记录 PID 和日志
  - 只有在用户明确要求自动唤醒、且当前存在 automation/reminder 工具时，才创建 Codex automation 或 reminder
  - 如果没有自动续跑能力，就在 `STATE.md` 写精确的手动 resume prompt
- 长命令要以可轮询方式启动。记录命令、工作目录、session id 或 PID、日志文件和预期 heartbeat。
- 如果当前 turn 必须在任务完成前结束，`STATE.md` 中要留下可直接复制使用的 resume instruction，要求下一轮 Codex 先读 `skills/long-task/loop task.md` 和任务目录文件。
- 不要虚构平台能力。如果没有自动唤醒能力，就明确说明，并提供可靠的手动恢复路径。

## 后台执行记录

本 skill 启动的每个后台任务，都要记录：

- 完整命令和工作目录
- 开始时间
- owner：本次 long-task run
- 进程标识：session id、PID、job id 或 scheduler id
- stdout/stderr 或日志路径
- 预期输出文件
- health check 命令
- 如果用户稍后要求停止任务，什么条件下可以安全停止

生成的监控文件、临时文件、测试文件优先放在项目规则允许的 `logs/`、`temp/`、`test/` 或当前任务目录中。

## 进度与 handoff

每个工作周期都要：

- 检查 `GOAL.md`、`PLAN.md`、`STATE.md` 和最近日志
- 对比实际进度和计划
- 如果阶段目标完成，更新 `GOAL.md`
- 向 `LOG.md` 追加一条简短事件
- 更新 `STATE.md` 的下一步和活跃任务信息
- 告诉用户本轮完成了什么、什么还在运行、下一次检查是什么时候

handoff 给另一个 Agent 时，只传递继续执行所需的信息：任务目录、当前阶段、活跃进程、最新输出、blocker 和下一条命令。

## 完成条件

只有满足以下条件后，才算完成：

- `GOAL.md` 中每条验收标准都已满足，或明确标记未满足并写明原因
- 本次 long-task 创建的活跃任务已经结束，或已按用户可见的说明继续运行
- `REVIEW.md` 记录了 review 和验证结果
- `STATE.md` 标记为 `status: done` 或 `status: blocked`
- 本任务创建的 loop、reminder 或 monitor 已取消或更新
- 用户收到简洁的最终报告，包括交付物、测试结果和剩余风险
