# Loop Task

这是 `long-task` skill 创建的长期任务在每个续跑周期内要执行的指令。

## 必读输入

行动前必须读取：

- `skills/long-task/SKILL.md`
- `long_task/<task-slug>/GOAL.md`
- `long_task/<task-slug>/PLAN.md`
- `long_task/<task-slug>/STATE.md`
- `long_task/<task-slug>/LOG.md`

如果不知道任务目录，先检查 `long_task/`，选择 `STATE.md` 不是 `done` 或 `blocked` 的任务。如果有多个活跃任务，先问用户要继续哪一个。

## 单轮流程

1. 检查 `GOAL.md`，确认最终目标、验收标准、边界和阶段状态。
2. 检查 `STATE.md`，确认当前阶段、活跃任务、预期输出、blocker 和 resume instruction。
3. 只检查本任务创建的活跃进程。不要 kill、暂停或修改无关进程。
4. 阅读最近日志和输出。优先 tail 或摘要，不要整段加载巨大日志。
5. 决定下一步安全动作：
   - 按计划继续执行
   - 用有边界的小改动重试失败步骤
   - 当旧计划无法达到目标时更新计划
   - 当目标、权限、成本或风险改变时询问用户
   - 没有用户输入就无法继续时标记 blocked
   - 全部验收标准满足时结束任务
6. 只执行下一段连贯工作。长命令必须用可后台运行的方式执行，并记录标识。
7. 本轮结束前更新持久文件。

## 状态更新

每轮必须更新：

- `STATE.md`：当前状态、最新工作、活跃进程信息、blocker、下一步、最后更新时间
- `LOG.md`：本轮发生了什么的简短时间戳事件

阶段状态变化时更新 `GOAL.md`。只有旧计划无法达成未变更的最终目标时，才更新 `PLAN.md`，并在 `LOG.md` 记录原因。

## 汇报

每轮结束后向用户报告：

- 当前阶段和状态
- 相比上一轮完成了什么
- 活跃任务，以及日志/结果在哪里
- 下一次计划检查，或下一项需要用户决策的内容

除非遇到失败或修改计划，否则报告保持简短。

## 完成或阻塞

任务完成时：

- 验证 `GOAL.md` 中每条验收标准
- 写入或更新 `REVIEW.md`
- 将 `STATE.md` 设置为 `status: done`
- 取消或更新本任务创建的 loop、reminder 或 monitor
- 汇报最终交付物、验证结果和剩余风险

任务阻塞时：

- 将 `STATE.md` 设置为 `status: blocked`
- 记录准确 blocker，以及所需的最小用户决策或外部变化
- 留下从读取本文件和任务目录开始的 resume instruction
