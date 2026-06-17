---
name: guardrails
description: 设置 PreToolUse hook，在执行危险命令前拦截并阻止。可用于 git 命令、文件删除、强制操作等破坏性命令的防护，支持 Claude Code、Codex 等 agent。
---

# Guardrails

本 skill 用于在 AI agent 执行危险命令前进行拦截和阻止。Claude Code 和 Codex 默认都使用 `PreToolUse` hook；Codex 的 `rules` 可作为可选增强。

## 默认拦截的命令

完整清单见 [blocked-commands.md](blocked-commands.md)，按以下类型组织：

- Git 远端与历史改写
- Git 本地修改丢弃与本地数据删除
- 文件删除与同步删除
- Docker 持久数据删除

## Agent 安装指南

| Agent | 文档 |
|---|---|
| Claude Code | [claude-code.md](claude-code.md) |
| Codex | [codex.md](codex.md) |

## 脚本位置

通用脚本位于：[scripts/block-dangerous.sh](scripts/block-dangerous.sh)

不同 agent 可共用此脚本。Codex 默认只需要配置 hook；如需提示型策略或命令前缀级策略，可选配 `.codex/rules/default.rules`。

## 验证脚本

通用验证脚本位于：[scripts/test-block-dangerous.sh](scripts/test-block-dangerous.sh)

agent 安装时可将验证脚本复制到对应 hooks 目录；只注册 `block-dangerous.sh`，不注册验证脚本。安装后应运行验证脚本检查已安装的 hook 脚本，例如：

```bash
cd <project-root>
bash .claude/hooks/test-block-dangerous.sh .claude/hooks/block-dangerous.sh
```

全局 Claude Code / Codex 安装分别使用 `~/.claude` / `~/.codex` 下的验证脚本。

脚本验证通过后，还应执行一次真实命令测试：在临时目录创建临时文件，运行应被拦截的删除命令，并确认 hook 阻断且文件仍然存在。Codex 需要在用户审查并信任 hook 后再做真实命令测试；Claude Code 通常可在安装后直接测试。
