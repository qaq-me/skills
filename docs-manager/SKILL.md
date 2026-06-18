---
name: docs-manager
description: Use for knowledge cleanup after broad project changes according to global rules, or when the user explicitly invokes this skill.
---

# Docs Manager

你是项目知识库编辑，不是流水账记录员。你的目标是让项目在阶段结束后保持可读、可接手、可恢复：文档说明当前事实，agent 入口说明本项目怎么工作，memory 只保存值得跨会话复用的稳定经验。

## 核心分层

| 层级                        | 读者                 | 职责                                        | 不该放什么                           |
| ------------------------- | ------------------ | ----------------------------------------- | ------------------------------- |
| `README.md`               | 人类、GitHub 访客、未来接手者 | 项目是什么、当前状态、如何开始、目录导航；代码/实验目录还应写运行、测试、产物位置 | agent 私有指令、长篇阶段细节               |
| `CLAUDE.md` / `AGENTS.md` | 进入项目的 agent        | 项目定位、事实来源优先级、项目根目录导航、本项目特有规则或红线           | 全局规则复读、变更日志、docs 里的详细机制         |
| `docs/`                   | 需要深入理解项目的人和 agent  | 厚文档层；设计、命令、验收、参考资料、环境、路线、经验等按职责拆开         | 临时进度、混杂的大杂烩                     |
| 子目录 `README.md`           | 人类和 agent 的局部入口    | 解释该目录用途、结构、阅读/运行入口、产物位置和边界                | 全局规则、项目级 agent 指令、无关历史叙事、其他目录细节 |
| agent memory              | 未来会话中的 agent       | 稳定偏好、长期决策、反复踩坑、跨项目经验                      | 实时项目状态、未验证路径、一次性过程              |

判断信息归属时问两句：

1. 人类接手项目必须知道吗？是则进 `README.md`、子目录 README 或 `docs/`。
2. 下次 agent 写代码时不看到会犯错吗？是则进项目 `CLAUDE.md` / `AGENTS.md`。

## 默认项目结构

正式项目默认有三件套：

- `README.md`：人类/GitHub 入口。早期可以很短，但不要缺。
- `CLAUDE.md`：Claude Code 入口。
- `AGENTS.md`：Codex 入口。

`CLAUDE.md` 和 `AGENTS.md` 默认内容保持一致。项目级配置不写平台差异；平台差异应放在全局配置中。`docs/` 按需启用：小项目可以没有；一旦创建，就必须有 `docs/README.md` 说明文档分层。

全局配置只保留调用 `docs-manager` 的调度规则，不复述项目文档结构细则。新项目初始化、三件套、`docs/`、子目录 README 和项目根目录导航的维护口径，以本 skill 为准。

项目根目录导航（route-map）是项目根 `CLAUDE.md` / `AGENTS.md` 里的目录导航表。它负责说明一级目录和根部关键文件的用途与入口，帮助 agent 从项目根快速找到该读的 README、docs 或代码入口。目录入口文件写在该目录行里，例如 `docs/` 的入口是 `docs/README.md`，不要再把 `docs/README.md` 作为根部关键文件重复列一遍；子目录内部结构交给子目录 README。

子目录统一用 `README.md` 做人和 agent 共用入口，默认不创建子目录级 `CLAUDE.md` / `AGENTS.md`。如果子目录有特殊规则或注意事项，优先写入项目级 `CLAUDE.md` / `AGENTS.md` 或该子目录 README，避免多层 agent 规则互相覆盖。

第三方源码包、vendor 目录、外部论文代码里的 README 默认视作上游文档：可以阅读，不主动改写；除非用户明确要求维护该外部目录。

`docs-manager` 不维护第三方源码包 README、vendor 文档、`trash/README.md`、临时目录、缓存目录或自动生成产物。软删除和 trash 索引由执行删除动作的 agent 按全局删除规则维护。

## 执行流程

### 1. 找项目根

默认当前目录是项目根。先检查当前目录是否有项目根标志：

- `.git`
- `AGENTS.md`
- `CLAUDE.md`

如果当前目录有上述任意一个标志，就使用当前目录。若当前目录没有，就从当前目录开始逐级向上查找，使用第一个包含 `.git`、`AGENTS.md` 或 `CLAUDE.md` 的目录。向上也找不到时，仍使用当前目录。`README.md` 不参与项目根判断，避免把子目录 README 误判成项目根。

### 2. 盘点入口文件

只盘点和知识同步有关的入口，不要无差别阅读整个项目：

- 根目录结构。
- 根 `README.md`、`CLAUDE.md`、`AGENTS.md`。
- `docs/` 是否存在；存在则读 `docs/README.md` 和必要的子目录 README。
- 一级子目录 README。
- 当前平台的 memory 细节：Codex 只读 `references/codex-memory.md`；Claude Code 只读 `references/claude-code-memory.md`。一般不需要读取另一平台的 memory 机制文件。

对每个入口在内部标记：不用改、要改、缺失但暂不创建、缺失且应创建。

### 3. 判断本次知识影响

根据本次对话和 diff 判断哪些层需要同步：

- 面向人类的项目定位、使用方式、目录变化 -> `README.md` 或子目录 README。
- agent 下次必须遵守的项目特有规则、事实来源、项目根目录导航 -> `CLAUDE.md` / `AGENTS.md`。
- 厚文档职责变化、阶段设计、命令、验收、环境、资料口径 -> `docs/`。
- 稳定偏好、反复踩坑、跨会话经验 -> memory。

不确定具体映射时查 `references/sync-matrix.md`。

### 4. 执行编辑

按读者优先级编辑：

1. `README.md`、子目录 README、`docs/`。
2. 项目 `CLAUDE.md` / `AGENTS.md`。
3. agent memory。

编辑原则：

- 合并旧条目，不在顶部追加历史叙事。
- 删除或迁移已过期的中间态说明。
- 用绝对日期，不写“今天”“最近”“刚刚”。
- `CLAUDE.md` / `AGENTS.md` 不重复全局规则，只写项目特有内容。
- `docs/` 内部按职责分开；设计、命令、验收、参考资料、环境不要混写。

### 5. Memory 维护

Memory 是跨会话记忆层，不是 repo 事实来源。使用 memory 时必须回到当前 repo 验证路径、命令、脚本名和状态。

- Codex：按 `references/codex-memory.md` 维护。
- Claude Code：按 `references/claude-code-memory.md` 维护。

适合进入 memory 的内容：稳定用户偏好、长期项目约定、反复出现的踩坑、跨项目复用经验。项目当前状态、阶段实时进度、一次性 bug 过程应进入 repo 文档、review 文件或 git 历史。

### 6. 自检

结束前检查：

- `README.md`、`CLAUDE.md`、`AGENTS.md` 的职责没有混淆。
- 项目根目录导航能带读者到一级目录入口。
- 子目录 README 只在有独立职责或非显然结构时维护。
- `docs/` 若存在，有 `docs/README.md`，并且职责分层清楚。
- 第三方源码包 README 没被误改。
- 没有相对时间残留。
- 大改后做必要的 review / smoke / markdown 检查。

### 7. 输出格式

收尾时只列实际改动：

```markdown
## 同步完成

### 文档变更
- `<path>`：做了什么

### Memory
- `<path or memory item>`：做了什么

### 验证
- 运行了什么检查；没跑的说明原因

### 未处理
- 需要用户决定的事项
```

不要把内部盘点清单完整贴给用户；只报告有价值的结论。

## 参考文件

- `references/agent-paths.md`：Codex / Claude Code 的配置、memory、skill 路径速查。
- `references/codex-memory.md`：Codex memory 机制，只在 Codex 环境读取。
- `references/claude-code-memory.md`：Claude Code memory 机制，只在 Claude Code 环境读取。
- `references/sync-matrix.md`：常见变更应该同步到哪些知识层。
