# Codex Memory

只在当前 agent 是 Codex 时读取本文件。Claude Code 不需要读取本文件。

## 定位

Codex memory 是跨会话记忆层，不是 repo 事实来源。它可以提供历史偏好、旧决策和排障线索；涉及当前路径、命令、脚本名、实验状态时，必须回到当前 repo 的代码、`README.md`、`AGENTS.md` 和 `docs/` 验证。

## 路径

| 用途 | 路径 |
|---|---|
| memory 根目录 | `~/.codex/memories/` |
| registry | `~/.codex/memories/MEMORY.md` |
| 摘要 | `~/.codex/memories/memory_summary.md` |
| rollout 记录 | `~/.codex/memories/rollout_summaries/` |
| ad-hoc 更新 note | `~/.codex/memories/extensions/ad_hoc/notes/` |

## 读取规则

- 先读 `memory_summary.md` 给出的摘要，再按关键词查 `MEMORY.md`。
- 只有 `MEMORY.md` 明确指向的 rollout、skill 或 note 才继续打开；避免无差别扫全部历史。
- 从 memory 得到的事实如果可能漂移，回答或写文档前必须回 repo 验证。

## 更新规则

- 遵循当前 Codex memory/update note 机制；不要直接把手改 `MEMORY.md`、`memory_summary.md` 或 `rollout_summaries/` 当成主要控制面。
- 只有用户明确要求更新 memory，或当前环境规则明确允许时，才写入 memory 更新 note。
- 更新 note 放在 `~/.codex/memories/extensions/ad_hoc/notes/`，文件名使用 `<timestamp>-<short-slug>.md`。
- note 只写一件稳定事实、偏好、长期约定或 stale-memory 修正；不要把阶段实时进度、一次性 bug 过程或未验证路径写进 memory。

## 适合写入

- 用户长期偏好。
- 跨项目工作方式。
- 反复出现的踩坑和修正。
- 当前 repo 已验证过的稳定约定。

## 不适合写入

- 当前阶段实时状态。
- 可以从 repo 文档或 git 历史直接得到的信息。
- 一次性排错过程。
- 旧路径、旧命令、旧脚本名，除非作为 stale-memory correction 明确写清楚“已过时”和“当前真相在哪”。
