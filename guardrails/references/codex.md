# Codex 安装指南

本文件说明如何在 Codex 中安装 Guardrails 安全护栏。默认安装方式只使用 `PreToolUse` hook，与 Claude Code 的使用方式保持一致。默认拦截清单见 [blocked-commands.md](blocked-commands.md)。

Codex 还有 `rules` 机制，但本 skill 不把它作为默认配置。默认只配 hook 的原因是：本 skill 的主要目标是拦截复杂 shell 字符串，例如 `git push origin main --force`、`pwd && rm -rf build`、`rsync --delete`。这些情况更适合由 hook 脚本检查。`rules` 只能表达命令前缀，适合作为可选增强或提示型策略。

## 执行分工

| 动作 | 执行者 |
|---|---|
| 检查 bash / Python / Windows Git Bash 环境 | agent 执行，缺失时先报告并征求用户处理方式 |
| 选择项目级或全局级安装 | 用户确认 |
| 复制 hook 脚本和验证脚本 | agent 可执行 |
| 创建或合并 `.codex/hooks.json` / `~/.codex/hooks.json` | agent 可执行，需避免覆盖已有 hooks |
| 启动新 Codex 会话后审查并信任 hook | 用户必须执行 |
| 运行验证脚本 | agent 执行并向用户报告结果 |

Codex 的非 managed command hook 在未被用户信任前会被跳过。hook 配置变化后，用户需要重新审查并信任。

Codex 的信任通常绑定 hook 定义（例如 `hooks.json` 中的 `matcher`、`command`、`commandWindows`、hook 位置等），而不是持续校验脚本文件内容。因此，仅替换 `block-dangerous.sh` 内容时，Codex 通常仍沿用已信任的 hook 定义，不会再次要求用户手动信任。这个行为不代表新版脚本一定正确；脚本内容更新后，agent 必须重新运行验证脚本，并做一次真实命令阻断测试。

本 skill 的脚本同时支持 Claude Code 和 Codex。Codex 阻断使用 stdout JSON 协议：`{"decision":"block","reason":"..."}`；Claude Code 阻断继续使用 stderr + `exit 2`。脚本会自动识别 Codex 输入，也可以通过环境变量 `GUARDRAILS_AGENT=codex` 显式指定。

## 安装步骤

### 1. 检查运行环境

安装或更新 hook 前，agent 必须先检查 hook 运行环境，确认后再复制脚本和写配置。

| 平台 | 必须确认 |
|---|---|
| Linux / macOS | `bash` 可用；`python3` 或 `python` 可用 |
| Windows + Git Bash | `bash.exe` 路径明确；在 Git Bash 环境里 `python3` 或 `python` 可用 |
| Windows + WSL fallback | 用户明确使用 WSL；WSL 路径、`bash`、`python3` / `python` 都可用 |

Windows 应优先使用 Git Bash，而不是优先走 WSL。agent 配置 Windows hook 前应先确定 `bash.exe` 的真实路径；不能确定时应询问用户，不要写入猜测路径。

推荐查找顺序：

1. 用户明确提供的 Git Bash 路径，例如 `D:\develop\Git\bin\bash.exe`。
2. PATH 中的 `bash.exe`，例如在 PowerShell 中运行 `Get-Command bash.exe`。
3. 环境变量拼出的常见路径，例如：
   - `$env:ProgramFiles\Git\usr\bin\bash.exe`
   - `$env:ProgramFiles\Git\bin\bash.exe`
   - `${env:ProgramFiles(x86)}\Git\usr\bin\bash.exe`
   - `$env:LocalAppData\Programs\Git\usr\bin\bash.exe`
4. `C:\Windows\System32\bash.exe` 或 `wsl.exe`（WSL，仅在用户明确使用 WSL 工作流时作为 fallback）。

找不到 Git Bash 时，agent 应停止安装流程并说明原因：请用户先安装 Git for Windows，或提供 Git Bash 的实际路径；获得用户许可后，agent 可以协助运行 `winget install --id Git.Git -e`。不要配置一个不可运行的 `commandWindows`。

找不到 `python3` 或 `python` 时，agent 也应停止安装流程并说明原因：hook 需要 Python 解析命令结构；请用户安装 Python 或修复 Git Bash / WSL 的 `PATH`；获得用户许可后，agent 可以协助运行 `winget install --id Python.Python.3 -e`。Python 可用后再继续安装。

如果安装后 hook 运行环境的 `PATH` 发生变化，导致脚本运行时找不到 `python3` 或 `python`，脚本会 fail closed：阻断本次 shell 命令，并提示用户安装 Python 或修复 hook 运行环境的 `PATH`。

WSL fallback 可能有额外问题：Windows 路径需要换成 WSL 路径（例如 `C:\Users\<用户名>\.codex` 对应 `/mnt/c/Users/<用户名>/.codex`），而且 WSL 内需要单独安装 `bash` 和 `python3` / `python`。如果用户不是明确使用 WSL，优先建议安装 Git for Windows 并使用 Git Bash。

### 2. 确认安装范围

如果用户已经明确要求项目级或全局级安装，agent 直接按用户指定范围继续，不需要再次询问。只有用户没有说明安装范围时，agent 才应向用户确认：仅安装到当前项目，还是安装到全局。

| 范围 | hook 配置文件 | hook 脚本位置 | trust 说明 |
|---|---|---|---|
| 项目级 | `.codex/hooks.json` | `.codex/hooks/` | 仅在项目被 Codex 标记为 trusted 时加载 |
| 全局级 | `~/.codex/hooks.json` | `~/.codex/hooks/` | 不依赖项目 trust 状态 |

### 3. 复制脚本

脚本源文件：

- hook 脚本：[../scripts/block-dangerous.sh](../scripts/block-dangerous.sh)
- 验证脚本：[../scripts/test-block-dangerous.sh](../scripts/test-block-dangerous.sh)

复制到目标位置：

| 范围 | hook 脚本 | 验证脚本 |
|---|---|---|
| 项目级 | `.codex/hooks/block-dangerous.sh` | `.codex/hooks/test-block-dangerous.sh` |
| 全局级 | `~/.codex/hooks/block-dangerous.sh` | `~/.codex/hooks/test-block-dangerous.sh` |

推荐赋予执行权限，方便手动直接运行；但后续 hook 配置使用 `bash <脚本路径>`，因此不依赖 executable bit：

```bash
chmod +x <脚本路径>
```

### 4. 注册 hook

如果 `hooks.json` 已经存在，请合并 `hooks.PreToolUse`，不要覆盖其他 hook。

项目级示例（`.codex/hooks.json`）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "GUARDRAILS_AGENT=codex bash \"$(git rev-parse --show-toplevel)/.codex/hooks/block-dangerous.sh\"",
            "timeout": 30,
            "statusMessage": "Checking dangerous shell command"
          }
        ]
      }
    ]
  }
}
```

全局级示例（`~/.codex/hooks.json`）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "GUARDRAILS_AGENT=codex bash ~/.codex/hooks/block-dangerous.sh",
            "timeout": 30,
            "statusMessage": "Checking dangerous shell command"
          }
        ]
      }
    ]
  }
}
```

Windows Git Bash 全局示例：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "GUARDRAILS_AGENT=codex bash ~/.codex/hooks/block-dangerous.sh",
            "commandWindows": "C:\\Program Files\\Git\\usr\\bin\\bash.exe -lc \"GUARDRAILS_AGENT=codex /c/Users/<用户名>/.codex/hooks/block-dangerous.sh\"",
            "timeout": 30,
            "statusMessage": "Checking dangerous shell command"
          }
        ]
      }
    ]
  }
}
```

如果 Git Bash 安装在其他位置，请把 `commandWindows` 开头的 `bash.exe` 路径换成实际路径；`/c/Users/<用户名>/...` 也要换成当前 Windows 用户目录对应的 Git Bash 路径。`commandWindows` 只是指定 hook 脚本如何运行，不代表用户命令必须由 Git Bash 执行。

### 5. 用户信任 hook

启动新的 Codex 会话后，用户需要在 Codex 中审查并信任 hook。agent 可以提醒用户完成这一步，但不应替用户静默信任自己写入的 hook。

Codex app：

1. 打开设置。
2. 进入“钩子”。
3. 查看 hook 来源、命令和脚本路径。
4. 确认命令指向预期的 `block-dangerous.sh` 后，选择信任。

Codex CLI：

1. 在会话中运行 `/hooks`。
2. 查看 hook 来源、命令和脚本路径。
3. 确认命令指向预期的 `block-dangerous.sh` 后，选择 trust。

如果当前 Codex surface 没有“钩子”设置或 `/hooks` 入口，应先确认该 surface 是否支持非 managed hooks；不要假设 hook 已经生效。

### 6. 验证安装

agent 应使用通用验证脚本测试安装后的 hook 脚本，并向用户报告结果。

项目级示例：

```bash
cd <project-root>
bash .codex/hooks/test-block-dangerous.sh .codex/hooks/block-dangerous.sh
```

全局级示例：

```bash
bash ~/.codex/hooks/test-block-dangerous.sh ~/.codex/hooks/block-dangerous.sh
```

验证脚本会覆盖每类代表性拦截命令和允许命令，最后输出 `Summary: <passed> passed, 0 failed`。

脚本验证通过后，还应在用户审查并信任 hook 后执行一次真实命令测试，确认 PreToolUse 能阻断实际工具调用，而不只是脚本本身能识别危险命令。推荐使用临时目录和临时文件，例如：

```powershell
New-Item -ItemType Directory -Force -Path .\temp\guardrails-real-test
Set-Content .\temp\guardrails-real-test\victim.txt test
rm -Force .\temp\guardrails-real-test\victim.txt
```

期望结果是 Codex 返回 `Command blocked by PreToolUse hook`，并且临时文件仍然存在。Windows 还应抽样测试 `Remove-Item`、`del`、`rmdir` 等 PowerShell 删除命令。

同时应测试正常命令不会误拦，例如 `pwd`、`ls -la`、PowerShell `Get-ChildItem .` / `dir .`；也应测试普通文本不会误拦，例如 `Write-Output "rm -rf build"`、`Select-String -Pattern "Remove-Item|rm" file.txt`。本 skill 的目标是拦截实际执行的危险命令，不是拦截文本中出现的关键词。

## 可选：rules 增强

不需要配置 `rules` 也可以使用本 skill。只用 hook 已经能完成命令前硬拦截。

如果你想在 Codex 中配置提示型策略，或希望某些稳定前缀在 sandbox 外执行时由 Codex 原生策略直接 `forbidden` / `prompt`，可以额外创建 `.codex/rules/default.rules` 或 `~/.codex/rules/default.rules`。

示例：

```python
prefix_rule(
    pattern = ["rm"],
    decision = "forbidden",
    justification = "Use soft delete: move files to trash/ instead of rm.",
    match = ["rm file.txt", "rm -rf build"],
)

prefix_rule(
    pattern = ["chmod", "-R"],
    decision = "prompt",
    justification = "Recursive chmod can break permissions; ask the user first.",
    match = ["chmod -R 777 ."],
)
```

注意：rules 是命令前缀匹配，不适合覆盖 flag 位置可变或 compound shell 命令。不要把 rules 当成 hook 脚本的完整替代。

## 跨平台说明

脚本使用 `bash` 编写，并使用 `python3`（或 `python`）解析 hook JSON 和命令结构。为减少把引号内普通文本误判为删除命令的情况，当前版本不再使用简单 `sed` 解析作为完整替代。

| 平台 | 支持情况 | 注意事项 |
|---|---|---|
| Linux | 支持 | 通常已预装 bash；需要 python3 或 python |
| macOS | 支持 | 系统 bash 可用；需要 python3 或 python |
| Windows | 需要 Git Bash 或 WSL | 优先使用 Git Bash；只有找不到 Git Bash 时再 fallback 到 WSL |

本脚本不是 Windows 原生 PowerShell 脚本；Windows 原生环境需要通过 Git Bash 或 WSL 运行。

## 注意事项

- hooks 是强拦截层，但多个匹配 hook 会并发启动，一个 hook 不能阻止另一个 hook 开始运行。
- 默认使用 `matcher: "Bash"`，与 Codex shell 工具名保持一致；如果某个 Windows surface 实测 shell 工具名不是 `Bash`，再按实际工具名调整 matcher，或临时使用 `matcher: "*"` 诊断。
- 本 skill 当前只拦截 agent 发起的命令，不阻止用户手动在终端执行相同命令。
