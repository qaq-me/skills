# Claude Code Memory

只在当前 agent 是 Claude Code 时读取本文件。Codex 不需要读取本文件。

## 定位

Claude Code memory 是跨会话记忆层，不是 repo 事实来源。它可以保存用户偏好、项目级长期约定、反复踩坑和外部资源指针；涉及当前路径、命令、脚本名、实验状态时，必须回到当前 repo 的代码、`README.md`、`CLAUDE.md` 和 `docs/` 验证。

## 路径

| 用途 | 路径或机制 |
|---|---|
| 项目记录目录 | `~/.claude/projects/<encoded-project-path>/` |
| 项目 memory 目录 | `~/.claude/projects/<encoded-project-path>/memory/` |
| memory 索引 | `~/.claude/projects/<encoded-project-path>/memory/MEMORY.md` |

`<encoded-project-path>` 通常由项目绝对路径编码而来；本机已观察到 `/Users/qaq/agent` 对应 `/Users/qaq/.claude/projects/-Users-qaq-agent`。不要只凭规则猜路径，执行前先在当前 Claude Code 环境确认实际目录。

memory 目录不保证每个项目都已经存在。本机当前 `/Users/qaq/.claude/projects/-Users-qaq-agent/` 存在，但未观察到 `memory/`；另一个历史项目存在 `memory/`。因此不要写死“目录一定已存在”，也不要在未确认 Claude Code 当前机制前盲目创建结构。

## 文件格式

本机已观察到的 Claude Code memory 文件使用顶层 `type:`，不是嵌套的 `metadata.type`：

```markdown
---
name: <short-name-or-title>
description: <one-line summary used during recall>
type: user | feedback | project | reference
originSessionId: <optional-session-id>
---

<the fact>

**Why**: <why this matters, especially for feedback/project memories>

**How to apply**:
- <how a future agent should use it>
```

如果当前 Claude Code 环境生成的新 memory 样例与此不同，以当前环境实际样例为准，并同步修正本 reference。

## 索引格式

`MEMORY.md` 通常是指针列表，不写 frontmatter：

```markdown
- [Title](file.md) — one-line hook
```

索引只保留可召回的短 hook；详细事实写在对应 memory 文件里。

## 维护规则

- 更新前先读 `MEMORY.md` 和相关 memory 文件，避免重复或冲突。
- `feedback` 和 `project` 类型应尽量包含 `Why` 与 `How to apply`。
- 过期事实不要简单保留；修正为当前事实，或缩成明确 stale note。
- repo 已记录的信息、实时项目状态、一次性 bug 过程、未验证路径不要写进 memory。
- memory 被召回后，凡涉及文件、函数、命令、flag，都要回当前 repo 验证。
