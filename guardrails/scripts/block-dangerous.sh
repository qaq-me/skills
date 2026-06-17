#!/usr/bin/env bash
set -u

if [[ -t 0 ]]; then
  INPUT="$*"
else
  INPUT=$(cat)
  if [[ -z "$INPUT" && $# -gt 0 ]]; then
    INPUT="$*"
  fi
fi

if command -v python3 >/dev/null 2>&1 && python3 -c 'print(1)' >/dev/null 2>&1; then
  PYTHON_CMD=python3
elif command -v python >/dev/null 2>&1 && python -c 'print(1)' >/dev/null 2>&1; then
  PYTHON_CMD=python
else
  PYTHON_CMD=""
fi

guardrails_agent() {
  agent="${GUARDRAILS_AGENT:-auto}"
  if [[ "$agent" == "auto" ]]; then
    if [[ -n "${CODEX_HOME:-}" ]] || printf '%s\n' "$INPUT" | grep -Eq '"model"[[:space:]]*:|"permission_mode"[[:space:]]*:'; then
      agent="codex"
    else
      agent="claude"
    fi
  fi
  printf '%s\n' "$agent"
}

block_with_message() {
  message="$1"
  agent="$(guardrails_agent)"
  if [[ "$agent" == "codex" ]]; then
    if [[ -n "$PYTHON_CMD" ]]; then
      printf '{"decision":"block","reason":%s}\n' "$("$PYTHON_CMD" -c 'import json,sys; print(json.dumps(sys.stdin.read(), ensure_ascii=False))' <<<"$message")"
    else
      printf '{"decision":"block","reason":"Guardrails failed closed: 未找到 python3 或 python，无法解析命令结构，因此所有命令都会被阻断。请安装 Python，或把 python3/python 加入 hook 运行环境的 PATH 后重新验证。"}\n'
    fi
    exit 0
  fi

  echo "$message" >&2
  exit 2
}

if [[ -z "$PYTHON_CMD" ]]; then
  block_with_message "Guardrails failed closed: 未找到 python3 或 python，无法解析命令结构，因此本次 shell 命令被阻断。请安装 Python，或把 python3/python 加入 hook 运行环境的 PATH 后重新验证。"
fi

if [[ -n "$PYTHON_CMD" ]]; then
  MATCH_RESULT=$(GUARDRAILS_RAW_INPUT="$INPUT" "$PYTHON_CMD" - <<'PY'
import json
import os
import re
import sys

raw = os.environ.get("GUARDRAILS_RAW_INPUT", "")
commands = []

def add(value):
    if isinstance(value, str) and value.strip():
        commands.append(value)

def walk(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in ("command", "cmd"):
                add(child)
            walk(child)
    elif isinstance(value, list):
        for child in value:
            walk(child)

try:
    walk(json.loads(raw))
except Exception:
    pass

if not commands:
    for match in re.finditer(r"\"(?:command|cmd)\"\s*:\s*\"((?:\\\\.|[^\"\\\\])*)\"", raw):
        value = match.group(1)
        try:
            value = json.loads("\"" + value + "\"")
        except Exception:
            pass
        add(value)

if not commands and raw.strip():
    add(raw)

def split_segments(command):
    segments = []
    current = []
    quote = None
    escape = False
    i = 0
    while i < len(command):
        ch = command[i]
        if escape:
            current.append(ch)
            escape = False
            i += 1
            continue
        if quote:
            if ch == "\\" and quote == '"':
                escape = True
                current.append(ch)
            elif ch == quote:
                quote = None
                current.append(ch)
            else:
                current.append(ch)
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            current.append(ch)
            i += 1
            continue
        if ch in (";", "|", "&"):
            if current:
                segments.append("".join(current).strip())
                current = []
            if i + 1 < len(command) and command[i + 1] == ch:
                i += 2
            else:
                i += 1
            continue
        current.append(ch)
        i += 1
    if current:
        segments.append("".join(current).strip())
    return [segment for segment in segments if segment]

def tokenize(segment):
    tokens = []
    current = []
    quote = None
    escape = False
    i = 0
    while i < len(segment):
        ch = segment[i]
        if escape:
            current.append(ch)
            escape = False
            i += 1
            continue
        if quote:
            if ch == "\\" and quote == '"':
                escape = True
            elif ch == quote:
                quote = None
            else:
                current.append(ch)
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            continue
        if ch.isspace():
            if current:
                tokens.append("".join(current))
                current = []
            i += 1
            continue
        current.append(ch)
        i += 1
    if current:
        tokens.append("".join(current))
    return tokens

def basename(token):
    token = token.strip()
    token = token.rstrip("\\/")
    token = token.replace("\\", "/")
    base = token.rsplit("/", 1)[-1].lower()
    if base.endswith(".exe"):
        base = base[:-4]
    return base

def short_option_contains(tokens, letter):
    for token in tokens:
        if re.fullmatch(r"-[A-Za-z]+", token) and letter in token[1:]:
            return True
    return False

def first_command(tokens):
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token in ("&", "command"):
            index += 1
            continue
        if token == "time":
            index += 1
            while index < len(tokens) and tokens[index].startswith("-"):
                index += 1
            continue
        if token == "nohup":
            index += 1
            continue
        if token == "nice":
            index += 1
            while index < len(tokens) and tokens[index].startswith("-"):
                index += 1
                if index < len(tokens) and tokens[index - 1] in ("-n", "--adjustment"):
                    index += 1
            continue
        if token == "env":
            index += 1
            while index < len(tokens):
                env_token = tokens[index]
                if env_token == "--":
                    index += 1
                    break
                if env_token.startswith("-"):
                    index += 1
                    if index < len(tokens) and env_token in ("-u", "--unset", "-C", "--chdir", "-S", "--split-string"):
                        index += 1
                    continue
                if "=" in env_token and not env_token.startswith("="):
                    index += 1
                    continue
                break
            continue
        if token == "sudo":
            index += 1
            while index < len(tokens) and tokens[index].startswith("-"):
                index += 1
                if index < len(tokens) and tokens[index - 1] in ("-u", "-g", "-h", "-p", "-C", "-T"):
                    index += 1
            continue
        break
    return index

def find_shell_command_arg(args, flags):
    normalized = {flag.lower() for flag in flags}
    for i, arg in enumerate(args):
        lower = arg.lower()
        if lower in normalized and i + 1 < len(args):
            return args[i + 1]
        if (
            lower.startswith("-")
            and not lower.startswith("--")
            and len(lower) <= 4
            and "c" in lower[1:]
            and "-c" in normalized
            and i + 1 < len(args)
        ):
            return args[i + 1]
    return None

def find_encoded_powershell_arg(args):
    for i, arg in enumerate(args):
        if arg.lower() in ("-encodedcommand", "-enc", "-e") and i + 1 < len(args):
            try:
                import base64
                return base64.b64decode(args[i + 1]).decode("utf-16le")
            except Exception:
                return None
    return None

def command_after_cmd_c(args):
    for i, arg in enumerate(args):
        if arg.lower() in ("/c", "/k", "-c") and i + 1 < len(args):
            return " ".join(args[i + 1:])
    return None

def strip_git_globals(args):
    with_value = {
        "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
        "--config-env", "--super-prefix", "--paginate", "--no-pager",
    }
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--":
            index += 1
            break
        if not arg.startswith("-"):
            break
        if arg in with_value:
            index += 2
            continue
        if any(arg.startswith(prefix + "=") for prefix in with_value if prefix.startswith("--")):
            index += 1
            continue
        index += 1
    return args[index:]

def strip_docker_globals(args):
    with_value = {
        "-c", "--context", "-H", "--host", "--config", "-l", "--log-level",
        "--tlscacert", "--tlscert", "--tlskey",
    }
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--":
            index += 1
            break
        if not arg.startswith("-"):
            break
        if arg in with_value:
            index += 2
            continue
        if any(arg.startswith(prefix + "=") for prefix in with_value if prefix.startswith("--")):
            index += 1
            continue
        index += 1
    return args[index:]

def strip_compose_globals(args):
    with_value = {
        "-f", "--file", "-p", "--project-name", "--project-directory",
        "--profile", "--env-file", "--ansi", "--progress", "--parallel",
    }
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--":
            index += 1
            break
        if not arg.startswith("-"):
            break
        if arg in with_value:
            index += 2
            continue
        if any(arg.startswith(prefix + "=") for prefix in with_value if prefix.startswith("--")):
            index += 1
            continue
        index += 1
    return args[index:]

def analyze_tokens(tokens, original):
    idx = first_command(tokens)
    if idx >= len(tokens):
        return None
    cmd = basename(tokens[idx])
    args = tokens[idx + 1:]

    if cmd in ("bash", "sh", "zsh"):
        nested = find_shell_command_arg(args, ("-c", "-lc"))
        if nested:
            return analyze_command(nested)

    if cmd in ("powershell", "pwsh"):
        encoded = find_encoded_powershell_arg(args)
        if encoded:
            return analyze_command(encoded)
        nested = find_shell_command_arg(args, ("-command", "-c"))
        if nested:
            return analyze_command(nested)

    if cmd == "cmd":
        nested = command_after_cmd_c(args)
        if nested:
            return analyze_command(nested)

    if cmd in ("rm",):
        return ("rm", original)
    if cmd in ("remove-item", "del", "erase", "rmdir", "rd", "ri"):
        return (cmd, original)

    if cmd == "xargs" and any(basename(arg) == "rm" for arg in args):
        return ("xargs rm", original)
    if cmd == "find":
        if "-delete" in args:
            return ("find -delete", original)
        if "-exec" in args and any(basename(arg) == "rm" for arg in args):
            return ("find -exec rm", original)
    if cmd == "rsync" and any(arg == "--delete" or arg.startswith("--delete-") for arg in args):
        return ("rsync --delete family", original)

    if cmd == "git":
        git_args = strip_git_globals(args)
        if not git_args:
            return None
        sub = git_args[0]
        rest = git_args[1:]
        if sub == "push":
            if "--force" in rest or "-f" in rest:
                return ("git push --force / git push -f", original)
            if any(arg.startswith("+") and len(arg) > 1 for arg in rest):
                return ("git push +refspec", original)
            if "--delete" in rest or any(arg.startswith(":") and len(arg) > 1 for arg in rest):
                return ("git push --delete / git push :branch", original)
        if sub == "tag" and rest[:1] in (["-d"], ["--delete"]):
            return ("git tag -d / git tag --delete", original)
        if sub == "remote" and rest[:1] in (["rm"], ["remove"]):
            return ("git remote rm / git remote remove", original)
        if sub == "remote" and rest[:1] == ["set-url"]:
            return ("git remote set-url", original)
        if sub in ("filter-repo", "filter-branch"):
            return (f"git {sub}", original)
        if sub == "rebase" and ("-i" in rest or "--interactive" in rest):
            return ("git rebase -i / git rebase --interactive", original)
        if sub == "commit" and "--amend" in rest:
            return ("git commit --amend", original)
        if sub == "worktree" and len(rest) >= 1 and rest[0] == "remove" and ("--force" in rest[1:] or "-f" in rest[1:]):
            return ("git worktree remove --force / git worktree remove -f", original)
        if sub == "checkout":
            if rest == ["."] or rest == ["--", "."]:
                return ("git checkout . / git checkout -- .", original)
            if "-f" in rest or "--force" in rest:
                return ("git checkout -f / git checkout --force", original)
        if sub == "restore":
            if rest == ["."]:
                return ("git restore .", original)
            if "--staged" in rest and "." in rest:
                return ("git restore --staged .", original)
        if sub == "clean" and (short_option_contains(rest, "f") or "--force" in rest):
            return ("git clean -f / git clean --force family", original)
        if sub == "reset" and rest[:1] in (["--hard"], ["--merge"], ["--keep"]):
            return ("git reset --hard" if rest[0] == "--hard" else "git reset --merge / git reset --keep", original)
        if sub == "branch" and (rest[:1] == ["-D"] or ("--delete" in rest and "--force" in rest)):
            return ("git branch -D / git branch --delete --force", original)
        if sub == "stash" and rest[:1] == ["drop"]:
            return ("git stash drop", original)
        if sub == "stash" and rest[:1] == ["clear"]:
            return ("git stash clear", original)

    if cmd == "docker":
        docker_args = strip_docker_globals(args)
        if not docker_args:
            return None
        if docker_args[:2] == ["volume", "rm"]:
            return ("docker volume rm", original)
        if docker_args[:2] == ["volume", "prune"]:
            return ("docker volume prune", original)
        if docker_args[:2] == ["system", "prune"] and "--volumes" in docker_args[2:]:
            return ("docker system prune --volumes", original)
        if docker_args[:1] == ["compose"]:
            compose_args = strip_compose_globals(docker_args[1:])
            if compose_args[:1] == ["down"] and any(arg in ("-v", "--volumes") for arg in compose_args[1:]):
                return ("docker compose down -v", original)
    if cmd == "docker-compose":
        compose_args = strip_compose_globals(args)
        if compose_args[:1] == ["down"] and any(arg in ("-v", "--volumes") for arg in compose_args[1:]):
            return ("docker compose down -v", original)

    return None

def analyze_command(command):
    for segment in split_segments(command):
        result = analyze_tokens(tokenize(segment), segment)
        if result:
            return result
    return None

seen = set()
for command in commands:
    if command in seen:
        continue
    seen.add(command)
    result = analyze_command(command)
    if result:
        print(result[0])
        print(result[1])
        sys.exit(0)
sys.exit(1)
PY
)
  MATCH_STATUS=$?
else
  MATCH_STATUS=1
  MATCH_RESULT=""
fi

if [[ "$MATCH_STATUS" -eq 0 ]]; then
  RULE_NAME=$(printf '%s\n' "$MATCH_RESULT" | sed -n '1p')
  MATCHED_COMMAND=$(printf '%s\n' "$MATCH_RESULT" | sed -n '2,$p')
  if [[ "$RULE_NAME" == "rm" || "$RULE_NAME" == "xargs rm" || "$RULE_NAME" == "remove-item" || "$RULE_NAME" == "del" || "$RULE_NAME" == "erase" || "$RULE_NAME" == "rmdir" || "$RULE_NAME" == "rd" ]]; then
    MESSAGE="已拦截：命令 '$MATCHED_COMMAND' 命中危险规则 '$RULE_NAME'，你没有权限执行此操作。请使用软删除（mv 到 trash/ 目录）代替。"
  else
    MESSAGE="已拦截：命令 '$MATCHED_COMMAND' 命中危险规则 '$RULE_NAME'，你没有权限执行此操作。"
  fi

  block_with_message "$MESSAGE"
fi

exit 0
