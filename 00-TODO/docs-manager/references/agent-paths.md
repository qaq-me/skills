# Codex / Claude Code 路径速查

本文件只做路径和引用路由速查。执行 `docs-manager` 时，memory 机制只读当前平台对应文件，不要把某个平台的机制硬套到另一个平台。

## Codex

| 用途          | 路径或机制                                                          |
| ----------- | -------------------------------------------------------------- |
| 全局配置        | `~/.codex/config.toml`                                         |
| 全局指令        | `~/.codex/AGENTS.md` 或 `$CODEX_HOME/AGENTS.md`                 |
| 项目指令        | 项目根 `AGENTS.md`                                                |
| 项目 override | `AGENTS.override.md`，若存在则优先看                                   |
| memory      | `~/.codex/memories/`                                           |
| memory 机制   | `references/codex-memory.md`                                   |
| skills      | `~/.codex/skills/<name>/SKILL.md` 或项目内 `.codex/skills/<name>/` |

Codex 项目里如果同时存在 `TEAM_GUIDE.md`、`.agents.md` 等历史入口，也要作为可能的旧指令来源检查，但不要默认新建这些别名。

## Claude Code

| 用途        | 路径或机制                                           |
| --------- | ----------------------------------------------- |
| 全局指令      | `~/.claude/CLAUDE.md`                           |
| 项目指令      | 项目根 `CLAUDE.md`                                 |
| 项目 memory | `~/.claude/projects/<encoded-project-path>/memory/` |
| memory 机制 | `references/claude-code-memory.md`              |
| skills    | `~/.claude/skills/<name>/SKILL.md` 或插件提供的 skill |

## 项目内共存策略

正式项目默认同时维护：

- `README.md`：人类/GitHub 入口。
- `CLAUDE.md`：Claude Code 项目入口。
- `AGENTS.md`：Codex 项目入口。

`CLAUDE.md` 和 `AGENTS.md` 默认保持同内容。平台能力或工具规则差异应放在全局配置中，项目级配置只写项目事实、目录导航和项目特有规则。`README.md` 和 `docs/` 是平台中立文档，不需要按 agent 分两份。
