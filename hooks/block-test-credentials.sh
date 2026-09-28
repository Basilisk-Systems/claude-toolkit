#!/bin/bash
# =============================================================================
# BLOCK TEST-CREDENTIALS HOOK
# =============================================================================
# PURPOSE: Keeps Claude from ever reading ~/.claude/TEST_CREDENTIALS.md (the
#          secrets file) or its .bak copies. Non-secret values (URLs, pool and
#          client IDs, usernames) live in ~/.claude/TEST_CONFIG.md, which stays
#          readable.
# TRIGGER: PreToolUse, matcher "*" (every tool, including subagents' calls)
#
# HOW IT WORKS:
# 1. Claude Code pipes the tool call as JSON to stdin
# 2. Any path/command field naming the file (case-insensitive) is blocked.
#    Write/Edit *content* is not checked, so docs may still mention the name.
# 3. Content reads that would reach the file without naming it are blocked:
#    - Grep over the ~/.claude root or the home directory
#    - Bash, checked per pipeline stage: a reader (grep, cat, sed, ...) given
#      the ~/.claude root or a root glob; a recursive reader given ~; find
#      -exec or find | xargs from those roots; cd into the root, then a
#      recursive or globbed read
#
# OUTPUT: exit 0 → allow; exit 2 + stderr → block (stderr is shown to Claude)
#
# LIMITS: A guard against accidental reads, not a security boundary. Paths
#         built at runtime (variables, symlinks, scripts) are not seen.
#         Pair it with permissions.deny Read/Edit rules on the same path.
# =============================================================================

exec python3 -c '
import json, os, re, shlex, sys

try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
tool = data.get("tool_name") or ""
ti = data.get("tool_input") or {}
if not isinstance(ti, dict):
    sys.exit(0)
home = re.escape(os.path.expanduser("~"))
H = r"(?:~|\$HOME|\$\{HOME\}|" + home + r")"
ROOT_ARG = re.compile(r"^" + H + r"/\.claude(?:/\*?)?$")  # ~/.claude, ~/.claude/, ~/.claude/*
HOME_ARG = re.compile(r"^" + H + r"/?$")
READERS = {"grep", "egrep", "fgrep", "rg", "ag", "ack", "cat", "tac", "nl", "head", "tail",
           "less", "more", "awk", "gawk", "sed", "strings", "xxd", "od", "base64", "bat",
           "cp", "rsync", "tar", "zip"}
RECURSIVE_BY_DEFAULT = {"rg", "ag", "ack"}
PREFIXES = {"sudo", "env", "command", "time", "nohup", "nice"}


def deny(reason):
    print("BLOCKED by block-test-credentials.sh: " + reason, file=sys.stderr)
    print("Secrets file is off-limits. Use ~/.claude/TEST_CONFIG.md for non-secret values;",
          file=sys.stderr)
    print("for a secret, ask the user or write a script that prompts for it (read -rs).",
          file=sys.stderr)
    sys.exit(2)


fields = [ti.get(k) for k in ("file_path", "path", "pattern", "glob", "command", "notebook_path")]
if any(isinstance(f, str) and re.search("test_credentials", f, re.I) for f in fields):
    deny(tool + " references TEST_CREDENTIALS")

if tool == "Grep":
    p = ti.get("path") or ""
    if ROOT_ARG.match(p) or HOME_ARG.match(p):
        deny("Grep over the ~/.claude root or home directory; narrow the path")

if tool != "Bash":
    sys.exit(0)


def words(stage):
    try:
        toks = shlex.split(stage, comments=True)
    except ValueError:
        toks = stage.split()
    while toks and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]) or toks[0] in PREFIXES):
        toks = toks[1:]
    return toks


in_root = False
for statement in re.split(r"&&|\|\||;|\n", ti.get("command") or ""):
    stages = [words(s) for s in statement.split("|")]
    for i, toks in enumerate(stages):
        if not toks:
            continue
        prog = os.path.basename(toks[0])
        args = toks[1:]
        root = any(ROOT_ARG.match(a) for a in args)
        homedir = any(HOME_ARG.match(a) for a in args)
        recursive = prog in RECURSIVE_BY_DEFAULT or any(
            a in ("-r", "-R", "--recursive") or re.match(r"^-[A-Za-z]*[rR][A-Za-z]*$", a)
            for a in args
        )
        if prog == "cd":
            in_root = bool(args) and bool(ROOT_ARG.match(args[0]))
            continue
        if prog in READERS:
            if root or (homedir and recursive):
                deny(prog + " over the ~/.claude root or home directory; narrow the path")
            if in_root and (recursive or any("*" in a for a in args)):
                deny(prog + " after cd into ~/.claude; narrow the path")
        if prog == "find" and (root or homedir or in_root):
            if any(a in ("-exec", "-execdir", "-ok", "-okdir") for a in args):
                deny("find -exec from the ~/.claude root or home directory")
            if i + 1 < len(stages) and stages[i + 1] and stages[i + 1][0] == "xargs":
                deny("find | xargs from the ~/.claude root or home directory")
sys.exit(0)
'
