#!/usr/bin/env bash
set -u

SCRIPT="${1:-}"
if [[ -z "$SCRIPT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SCRIPT="$SCRIPT_DIR/block-dangerous.sh"
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL script not found: $SCRIPT" >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

run_raw() {
  mode="$1"
  input="$2"
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  printf '%s' "$input" | GUARDRAILS_AGENT="$mode" bash "$SCRIPT" >"$stdout_file" 2>"$stderr_file"
  actual="$?"
  stdout="$(cat "$stdout_file")"
  stderr="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

pass() {
  echo "PASS $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL $1: $2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

run_block_case() {
  name="$1"
  input="$2"

  run_raw claude "$input"
  if [[ "$actual" == "2" && "$stderr" == *"已拦截"* ]]; then
    pass "claude blocks $name"
  else
    fail "claude blocks $name" "expected exit 2 and block stderr, got exit $actual stdout=[$stdout] stderr=[$stderr]"
  fi

  run_raw codex "$input"
  if [[ "$actual" == "0" && "$stdout" == *'"decision":"block"'* ]]; then
    pass "codex blocks $name"
  else
    fail "codex blocks $name" "expected exit 0 and decision:block stdout, got exit $actual stdout=[$stdout] stderr=[$stderr]"
  fi
}

run_allow_case() {
  name="$1"
  input="$2"

  for mode in claude codex; do
    run_raw "$mode" "$input"
    if [[ "$actual" == "0" && "$stdout" != *'"decision":"block"'* && "$stderr" != *"已拦截"* ]]; then
      pass "$mode allows $name"
    else
      fail "$mode allows $name" "expected allow, got exit $actual stdout=[$stdout] stderr=[$stderr]"
    fi
  done
}

run_no_python_fail_closed() {
  name="$1"
  input="$2"
  temp_path="$(mktemp -d)"
  cp "$(command -v cat)" "$temp_path/cat"
  chmod +x "$temp_path/cat"

  for mode in claude codex; do
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"
    printf '%s' "$input" | PATH="$temp_path" GUARDRAILS_AGENT="$mode" /bin/bash "$SCRIPT" >"$stdout_file" 2>"$stderr_file"
    actual="$?"
    stdout="$(cat "$stdout_file")"
    stderr="$(cat "$stderr_file")"
    rm -f "$stdout_file" "$stderr_file"

    if [[ "$mode" == "claude" ]]; then
      if [[ "$actual" == "2" && "$stderr" == *"Guardrails failed closed"* ]]; then
        pass "$mode fails closed without Python for $name"
      else
        fail "$mode fails closed without Python for $name" "expected exit 2 and fail-closed stderr, got exit $actual stdout=[$stdout] stderr=[$stderr]"
      fi
    else
      if [[ "$actual" == "0" && "$stdout" == *'"decision":"block"'* && "$stdout" == *"Guardrails failed closed"* ]]; then
        pass "$mode fails closed without Python for $name"
      else
        fail "$mode fails closed without Python for $name" "expected exit 0 and fail-closed decision:block, got exit $actual stdout=[$stdout] stderr=[$stderr]"
      fi
    fi
  done

  rm -rf "$temp_path"
}

echo "Testing guardrails script: $SCRIPT"

run_block_case "force push compact JSON" '{"tool_input":{"command":"git push --force origin main"}}'
run_block_case "force push flag after ref" '{"tool_input":{"command":"git push origin main --force"}}'
run_block_case "spaced JSON reset hard" '{"tool_input": {"command": "git reset --hard"}}'
run_block_case "Codex cmd key clean" '{"tool_name":"Bash","tool_input":{"cmd":"git clean -xdf"}}'
run_block_case "compound rm" '{"tool_input":{"command":"pwd && rm -rf build"}}'
run_block_case "absolute rm" '{"tool_input":{"command":"/bin/rm -rf build"}}'
run_block_case "sudo rm" '{"tool_input":{"command":"sudo rm -rf build"}}'
run_block_case "command rm" '{"tool_input":{"command":"command rm old.txt"}}'
run_block_case "PowerShell Remove-Item" '{"tool_input":{"command":"Remove-Item -Recurse -Force build"}}'
run_block_case "PowerShell del" '{"tool_input":{"command":"del old.txt"}}'
run_block_case "PowerShell erase" '{"tool_input":{"command":"erase old.txt"}}'
run_block_case "PowerShell rmdir" '{"tool_input":{"command":"rmdir old_dir"}}'
run_block_case "PowerShell rd" '{"tool_input":{"command":"rd old_dir"}}'
run_block_case "PowerShell ri alias" '{"tool_input":{"command":"ri old_dir"}}'
run_block_case "PowerShell command wrapper Remove-Item" '{"tool_input":{"command":"powershell -Command \"Remove-Item -Recurse -Force build\""}}'
run_block_case "PowerShell encoded command Remove-Item" '{"tool_input":{"command":"powershell -EncodedCommand UgBlAG0AbwB2AGUALQBJAHQAZQBtACAALQBSAGUAYwB1AHIAcwBlACAALQBGAG8AcgBjAGUAIABiAHUAaQBsAGQA"}}'
run_block_case "pwsh command wrapper Remove-Item" '{"tool_input":{"command":"pwsh -NoProfile -Command \"Remove-Item -Recurse -Force build\""}}'
run_block_case "cmd wrapper del" '{"tool_input":{"command":"cmd /c del old.txt"}}'
run_block_case "find delete" '{"tool_input":{"command":"find . -name \"*.tmp\" -delete"}}'
run_block_case "find exec rm" '{"tool_input":{"command":"find . -name \"*.tmp\" -exec rm {} \\;"}}'
run_block_case "xargs rm" '{"tool_input":{"command":"find . -name \"*.log\" | xargs rm"}}'
run_block_case "env wrapper rm" '{"tool_input":{"command":"env FOO=1 rm -rf build"}}'
run_block_case "time wrapper rm" '{"tool_input":{"command":"time rm old.txt"}}'
run_block_case "time option wrapper rm" '{"tool_input":{"command":"time -p rm old.txt"}}'
run_block_case "nice wrapper rm" '{"tool_input":{"command":"nice -n 10 rm old.txt"}}'
run_block_case "nohup wrapper rm" '{"tool_input":{"command":"nohup rm old.txt"}}'
run_block_case "checkout force" '{"tool_input":{"command":"git checkout -f main"}}'
run_block_case "restore staged dot" '{"tool_input":{"command":"git restore --staged ."}}'
run_block_case "clean long force" '{"tool_input":{"command":"git clean --force -d"}}'
run_block_case "reset merge" '{"tool_input":{"command":"git reset --merge"}}'
run_block_case "reset keep" '{"tool_input":{"command":"git reset --keep"}}'
run_block_case "worktree remove force after path" '{"tool_input":{"command":"git worktree remove ../tmp --force"}}'
run_block_case "worktree remove force before path" '{"tool_input":{"command":"git worktree remove --force ../tmp"}}'
run_block_case "worktree remove short force" '{"tool_input":{"command":"git worktree remove -f ../tmp"}}'
run_block_case "tag delete" '{"tool_input":{"command":"git tag -d v1.0.0"}}'
run_block_case "tag delete long" '{"tool_input":{"command":"git tag --delete v1.0.0"}}'
run_block_case "push delete" '{"tool_input":{"command":"git push origin --delete old-branch"}}'
run_block_case "push colon delete" '{"tool_input":{"command":"git push origin :old-branch"}}'
run_block_case "push plus refspec" '{"tool_input":{"command":"git push origin +main"}}'
run_block_case "remote set-url" '{"tool_input":{"command":"git remote set-url origin git@example.com:x/y.git"}}'
run_block_case "remote remove" '{"tool_input":{"command":"git remote remove origin"}}'
run_block_case "rebase interactive long" '{"tool_input":{"command":"git rebase --interactive main"}}'
run_block_case "branch delete force long" '{"tool_input":{"command":"git branch --delete --force old-branch"}}'
run_block_case "rsync delete" '{"tool_input":{"command":"rsync -a --delete src/ dst/"}}'
run_block_case "rsync delete family" '{"tool_input":{"command":"rsync -a --delete-excluded src/ dst/"}}'
run_block_case "docker volume rm" '{"tool_input":{"command":"docker volume rm postgres_data"}}'
run_block_case "docker volume prune" '{"tool_input":{"command":"docker volume prune -f"}}'
run_block_case "docker system prune volumes" '{"tool_input":{"command":"docker system prune --volumes -f"}}'
run_block_case "docker compose down volumes short" '{"tool_input":{"command":"docker compose down -v"}}'
run_block_case "docker compose down volumes long" '{"tool_input":{"command":"docker compose down --volumes --remove-orphans"}}'
run_block_case "docker compose file option down volumes" '{"tool_input":{"command":"docker compose -f docker-compose.yml down -v"}}'
run_block_case "docker-compose down volumes" '{"tool_input":{"command":"docker-compose down -v"}}'
run_block_case "docker-compose file option down volumes" '{"tool_input":{"command":"docker-compose -f docker-compose.yml down --volumes"}}'
run_block_case "bash lc inner rm" '{"tool_input":{"command":"bash -lc \"rm -rf build\""}}'
run_block_case "git global option reset hard" '{"tool_input":{"command":"git -C repo reset --hard"}}'
run_block_case "docker global option volume prune" '{"tool_input":{"command":"docker --context prod volume prune -f"}}'

run_allow_case "force-with-lease" '{"tool_input":{"command":"git push --force-with-lease origin main"}}'
run_allow_case "normal git status" '{"tool_input":{"command":"git status --short"}}'
run_allow_case "current directory pwd" '{"tool_input":{"command":"pwd"}}'
run_allow_case "list current directory" '{"tool_input":{"command":"ls -la"}}'
run_allow_case "PowerShell Get-ChildItem" '{"tool_input":{"command":"Get-ChildItem ."}}'
run_allow_case "PowerShell dir" '{"tool_input":{"command":"dir ."}}'
run_allow_case "find without delete" '{"tool_input":{"command":"find . -name \"*.tmp\" -print"}}'
run_allow_case "xargs echo" '{"tool_input":{"command":"printf test | xargs echo"}}'
run_allow_case "rsync without delete" '{"tool_input":{"command":"rsync -a src/ dst/"}}'
run_allow_case "docker compose down" '{"tool_input":{"command":"docker compose down"}}'
run_allow_case "docker rm container" '{"tool_input":{"command":"docker rm old_container"}}'
run_allow_case "quoted search pattern with rm words" '{"tool_input":{"command":"Select-String -Pattern \"rmdir|del|Remove-Item|rm\" file.txt"}}'
run_allow_case "PowerShell text containing rm" '{"tool_input":{"command":"Write-Output \"rm -rf build\""}}'
run_allow_case "PowerShell text containing Remove-Item" '{"tool_input":{"command":"Write-Output \"Remove-Item -Recurse -Force build\""}}'
run_allow_case "PowerShell wrapper text containing Remove-Item" '{"tool_input":{"command":"powershell -Command \"Write-Output \\\"Remove-Item -Recurse -Force build\\\"\""}}'
run_allow_case "cmd echo text containing del" '{"tool_input":{"command":"cmd /c echo del old.txt"}}'
run_allow_case "grep text containing rm" '{"tool_input":{"command":"grep \"rm -rf\" README.md"}}'

run_no_python_fail_closed "normal command" '{"tool_input":{"command":"git status --short"}}'

echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
  exit 1
fi

exit 0
