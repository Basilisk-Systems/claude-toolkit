#!/bin/bash
# Pipe-tests hooks/block-test-credentials.sh with synthetic PreToolUse payloads.
# Never touches the real secrets file. Run: bash hooks/tests/test-block-test-credentials.sh
HOOK="$(cd "$(dirname "$0")/.." && pwd)/block-test-credentials.sh"
pass=0
fail=0

run() { # run <want-exit> <label> <tool> <tool_input-json>
  local rc
  jq -nc --arg t "$3" --argjson i "$4" '{tool_name: $t, tool_input: $i}' | bash "$HOOK" 2>/dev/null
  rc=$?
  if [ "$rc" = "$1" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL (got $rc, want $1): $2"
  fi
}
bash_cmd() { jq -nc --arg c "$1" '{command: $c}'; }
F="$HOME/.claude/TEST_""CREDENTIALS.md"

# --- blocked: names the file
run 2 "Read secrets file" Read "$(jq -nc --arg p "$F" '{file_path: $p}')"
run 2 "Read .bak copy" Read "$(jq -nc --arg p "$F.bak-2026-09-28" '{file_path: $p}')"
run 2 "Bash cat, lower case" Bash "$(bash_cmd 'cat ~/.claude/test_credentials.md')"
run 2 "Grep glob names file" Grep '{"pattern":"x","glob":"TEST_CREDENTIALS*"}'
# --- blocked: reaches the file without naming it
run 2 "Grep ~/.claude root" Grep "$(jq -nc --arg p "$HOME/.claude" '{pattern: "x", path: $p}')"
run 2 "Grep ~/.claude/ root" Grep '{"pattern":"x","path":"~/.claude/"}'
run 2 "Grep home dir" Grep "$(jq -nc --arg p "$HOME" '{pattern: "x", path: $p}')"
run 2 "grep -rn root" Bash "$(bash_cmd 'grep -rn foo ~/.claude')"
run 2 "grep root glob" Bash "$(bash_cmd 'grep foo $HOME/.claude/*')"
run 2 "cat root glob" Bash "$(bash_cmd 'cat ~/.claude/*')"
run 2 "rg over home" Bash "$(bash_cmd 'rg password ~')"
run 2 "grep -r over \$HOME" Bash "$(bash_cmd 'grep -r foo $HOME')"
run 2 "cd root then grep -r ." Bash "$(bash_cmd 'cd ~/.claude && grep -rn foo .')"
run 2 "cd root then cat *" Bash "$(bash_cmd 'cd ~/.claude; cat *')"
run 2 "find -exec grep" Bash "$(bash_cmd 'find ~/.claude -type f -exec grep foo {} +')"
run 2 "find | xargs grep" Bash "$(bash_cmd 'find ~/.claude -type f | xargs grep foo')"
run 2 "sudo prefix" Bash "$(bash_cmd 'sudo grep -r foo ~/.claude')"
# --- allowed
run 0 "Read TEST_CONFIG.md" Read "$(jq -nc --arg p "$HOME/.claude/TEST_CONFIG.md" '{file_path: $p}')"
run 0 "Grep a subdirectory" Grep "$(jq -nc --arg p "$HOME/.claude/skills" '{pattern: "x", path: $p}')"
run 0 "Glob over root (names only)" Glob '{"pattern":"*.md","path":"~/.claude"}'
run 0 "grep one file" Bash "$(bash_cmd 'grep foo ~/.claude/settings.json')"
run 0 "cat one file" Bash "$(bash_cmd 'cat ~/.claude/settings.json')"
run 0 "grep non-recursive in home" Bash "$(bash_cmd 'grep foo ~/.bashrc')"
run 0 "ls root" Bash "$(bash_cmd 'ls ~/.claude')"
run 0 "ls root piped to grep" Bash "$(bash_cmd "ls -la ~/.claude | grep -E '^l'")"
run 0 "find root, head elsewhere" Bash "$(bash_cmd 'find ~/.claude -maxdepth 1 -type l; cd /tmp && git log | head -5')"
run 0 "cd root, then cd away" Bash "$(bash_cmd 'cd ~/.claude && cd skills && grep -r foo .')"
run 0 "Write content mentions it" Write '{"file_path":"/tmp/x.md","content":"see TEST_CREDENTIALS.md"}'
run 0 "Edit content mentions it" Edit '{"file_path":"/tmp/x.md","old_string":"a","new_string":"TEST_CREDENTIALS"}'
run 0 "non-JSON input" Bash '"not an object"'

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
