# Claude Code 安装指南

本文件说明如何在 Claude Code 中安装 Guardrails 安全护栏。默认拦截清单见 [blocked-commands.md](blocked-commands.md)。

## 执行分工

| 动作                                                     | 执行者                     |
| ------------------------------------------------------ | ----------------------- |
| 检查 bash / Python / Windows Git Bash 环境                         | agent 执行，缺失时先报告并征求用户处理方式 |
| 选择项目级或全局级安装                                            | 用户确认                    |
| 复制 hook 脚本和验证脚本                                        | agent 可执行               |
| 合并 `.claude/settings.json` 或 `~/.claude/settings.json` | agent 可执行，需避免覆盖已有 hooks |
| 运行验证脚本                                                 | agent 执行并向用户报告结果        |
| 审查最终 settings 变更                                       | 用户可选确认                  |

Claude Code 通常不需要像 Codex 那样额外执行 `/hooks` trust 步骤。

本 skill 的脚本同时支持 Claude Code 和 Codex。Claude Code 阻断使用 stderr + `exit 2`；Codex 阻断使用 stdout JSON 协议。Claude Code 安装时建议显式设置 `GUARDRAILS_AGENT=claude`，避免在特殊环境下自动识别错误。

## 安装步骤

### 1. 检查运行环境

安装或更新 hook 前，agent 必须先检查 hook 运行环境，确认后再复制脚本和写配置。

| 平台 | 必须确认 |
|---|---|
| Linux / macOS | `bash` 可用；`python3` 或 `python` 可用 |
| Windows + Git Bash | `bash.exe` 路径明确；在 Git Bash 环境里 `python3` 或 `python` 可用 |
| Windows + WSL fallback | 用户明确使用 WSL；WSL 路径、`bash`、`python3` / `python` 都可用 |

Windows 配置前应先确定 `bash.exe` 的真实路径；不能确定时应询问用户，不要写入猜测路径。推荐查找 Git Bash 的顺序：

1. 用户明确提供的 Git Bash 路径，例如 `D:\develop\Git\bin\bash.exe`。
2. PATH 中的 `bash.exe`，例如在 PowerShell 中运行 `Get-Command bash.exe`。
3. 环境变量拼出的常见路径，例如：
   - `$env:ProgramFiles\Git\usr\bin\bash.exe`
   - `$env:ProgramFiles\Git\bin\bash.exe`
   - `${env:ProgramFiles(x86)}\Git\usr\bin\bash.exe`
   - `$env:LocalAppData\Programs\Git\usr\bin\bash.exe`
4. `C:\Windows\System32\bash.exe` 或 `wsl.exe`（WSL，仅在用户明确使用 WSL 工作流时作为 fallback）。

找不到 Git Bash 时，agent 应停止安装流程并说明原因：请用户先安装 Git for Windows，或提供 Git Bash 的实际路径；获得用户许可后，agent 可以协助运行 `winget install --id Git.Git -e`。不要配置一个不可运行的 hook 命令。

找不到 `python3` 或 `python` 时，agent 也应停止安装流程并说明原因：hook 需要 Python 解析命令结构；请用户安装 Python 或修复 Git Bash / WSL 的 `PATH`；获得用户许可后，agent 可以协助运行 `winget install --id Python.Python.3 -e`。Python 可用后再继续安装。

如果安装后 hook 运行环境的 `PATH` 发生变化，导致脚本运行时找不到 `python3` 或 `python`，脚本会 fail closed：阻断本次 shell 命令，并提示用户安装 Python 或修复 hook 运行环境的 `PATH`。

WSL fallback 可能有额外问题：Windows 路径需要换成 WSL 路径（例如 `C:\Users\<用户名>\.claude` 对应 `/mnt/c/Users/<用户名>/.claude`），而且 WSL 内需要单独安装 `bash` 和 `python3` / `python`。如果用户不是明确使用 WSL，优先建议安装 Git for Windows 并使用 Git Bash。

### 2. 确认安装范围

如果用户已经明确要求项目级或全局级安装，agent 直接按用户指定范围继续，不需要再次询问。只有用户没有说明安装范围时，agent 才应向用户确认：仅安装到当前项目，还是安装到全局。

| 范围 | settings 文件 | hook 脚本位置 |
|---|---|---|
| 项目级 | `.claude/settings.json` | `.claude/hooks/` |
| 全局级 | `~/.claude/settings.json` | `~/.claude/hooks/` |

### 3. 复制脚本

脚本源文件：

- hook 脚本：[scripts/block-dangerous.sh](scripts/block-dangerous.sh)
- 验证脚本：[scripts/test-block-dangerous.sh](scripts/test-block-dangerous.sh)

复制到目标位置：

| 范围 | hook 脚本 | 验证脚本 |
|---|---|---|
| 项目级 | `.claude/hooks/block-dangerous.sh` | `.claude/hooks/test-block-dangerous.sh` |
| 全局级 | `~/.claude/hooks/block-dangerous.sh` | `~/.claude/hooks/test-block-dangerous.sh` |

推荐赋予执行权限，方便手动直接运行；但后续 settings 使用 `bash <脚本路径>`，因此不依赖 executable bit：

```bash
chmod +x <脚本路径>
```

### 4. 在 settings 中注册 hook

如果 settings 文件中已经存在 `hooks.PreToolUse` 数组，请合并进去，不要覆盖其他 hook。

项目级示例（`.claude/settings.json`）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "GUARDRAILS_AGENT=claude bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/block-dangerous.sh\""
          }
        ]
      }
    ]
  }
}
```

全局级示例（`~/.claude/settings.json`）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "GUARDRAILS_AGENT=claude bash ~/.claude/hooks/block-dangerous.sh"
          }
        ]
      }
    ]
  }
}
```

### 5. 验证安装

agent 应使用通用验证脚本测试安装后的 hook 脚本，并向用户报告结果。

项目级示例：

```bash
cd <project-root>
bash .claude/hooks/test-block-dangerous.sh .claude/hooks/block-dangerous.sh
```

全局级示例：

```bash
bash ~/.claude/hooks/test-block-dangerous.sh ~/.claude/hooks/block-dangerous.sh
```

验证脚本会覆盖每类代表性拦截命令和允许命令，最后输出 `Summary: <passed> passed, 0 failed`。

脚本验证通过后，还应执行一次真实命令测试，确认 Claude Code 的 PreToolUse 能阻断实际工具调用。推荐在临时目录中创建临时文件，然后执行 `rm`，期望结果是命令被 hook 阻断且文件仍然存在。Windows 环境还应抽样测试 `Remove-Item`、`del`、`rmdir` 等 PowerShell 删除命令。

同时应测试正常命令不会误拦，例如 `pwd`、`ls -la`、PowerShell `Get-ChildItem .` / `dir .`；也应测试普通文本不会误拦，例如 `Write-Output "rm -rf build"`、`grep "rm -rf" README.md`。本 skill 的目标是拦截实际执行的危险命令，不是拦截文本中出现的关键词。

### 6. 根据需求自定义

编辑复制后的 hook 脚本，添加或移除拦截规则。修改后应重新运行验证脚本。

## 跨平台说明

脚本使用 `bash` 编写，并使用 `python3`（或 `python`）解析 hook JSON 和命令结构。为减少把引号内普通文本误判为删除命令的情况，当前版本不再使用简单 `sed` 解析作为完整替代。

| 平台 | 支持情况 | 注意事项 |
|---|---|---|
| Linux | 支持 | 通常已预装 bash；需要 python3 或 python |
| macOS | 支持 | 系统 bash 可用；需要 python3 或 python |
| Windows | 需要 Git Bash 或 WSL | 优先使用 Git Bash；只有找不到 Git Bash 时再 fallback 到 WSL |

本脚本不是 Windows 原生 PowerShell 脚本；Windows 原生环境需要通过 Git Bash 或 WSL 运行。
