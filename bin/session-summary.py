#!/usr/bin/env python3
"""
Claude Code Session Summary Extractor

Parses a Claude Code session transcript (.jsonl) and produces structured
telemetry: tokens, agents, tools, files, commits, duration, and more.

Usage:
    # Summarize a specific session
    session-summary.py <transcript.jsonl>

    # Summarize and append to session log
    session-summary.py <transcript.jsonl> --log

    # JSON output (for piping)
    session-summary.py <transcript.jsonl> --json

    # Summarize all sessions from today
    session-summary.py --today

    # Summarize all sessions from a project
    session-summary.py --project <project-path>
"""

import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
CLAUDE_DIR = Path.home() / ".claude"
SESSION_LOG_DIR = CLAUDE_DIR / "session-logs"

# Opus pricing per 1M tokens (as of 2025)
PRICING = {
    "claude-opus-4-6": {"input": 15.00, "output": 75.00, "cache_read": 1.50, "cache_create": 18.75},
    "claude-sonnet-4-6": {"input": 3.00, "output": 15.00, "cache_read": 0.30, "cache_create": 3.75},
    "claude-haiku-4-5-20251001": {"input": 0.80, "output": 4.00, "cache_read": 0.08, "cache_create": 1.00},
    # Fallback
    "default": {"input": 15.00, "output": 75.00, "cache_read": 1.50, "cache_create": 18.75},
}


def estimate_cost(model: str, usage: dict) -> float:
    """Estimate USD cost from token usage."""
    rates = PRICING.get(model, PRICING["default"])
    cost = 0.0
    cost += usage.get("input_tokens", 0) * rates["input"] / 1_000_000
    cost += usage.get("output_tokens", 0) * rates["output"] / 1_000_000
    cost += usage.get("cache_read_input_tokens", 0) * rates["cache_read"] / 1_000_000
    cost += usage.get("cache_creation_input_tokens", 0) * rates["cache_create"] / 1_000_000
    return cost


def parse_transcript(path: str) -> dict:
    """Parse a session transcript JSONL and extract telemetry."""
    session_id = Path(path).stem
    timestamps = []
    models = set()
    tool_counts: Counter = Counter()
    agent_spawns = []
    files_written = set()
    files_edited = set()
    files_read = set()
    git_commits = []
    bash_commands = []
    user_messages = 0
    assistant_turns = 0
    project = None
    branch = None
    cwd = None
    version = None

    # Token accumulators per model
    usage_by_model: dict[str, dict] = {}

    with open(path) as f:
        for line in f:
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = obj.get("type")
            ts = obj.get("timestamp")
            if ts:
                timestamps.append(ts)

            # Grab session metadata from any message
            if not cwd and obj.get("cwd"):
                cwd = obj["cwd"]
            if not branch and obj.get("gitBranch"):
                branch = obj["gitBranch"]
            if not version and obj.get("version"):
                version = obj["version"]
            if not project and obj.get("sessionId"):
                session_id = obj["sessionId"]

            # --- User messages ---
            if msg_type == "user":
                msg = obj.get("message", {})
                content = msg.get("content", [])
                # Count non-meta user messages (actual human input)
                if not obj.get("isMeta", False):
                    # Check if it's a tool_result (auto) or actual user text
                    if isinstance(content, str):
                        user_messages += 1
                    elif isinstance(content, list):
                        has_text = any(
                            isinstance(c, dict) and c.get("type") == "text"
                            and not c.get("tool_use_id")
                            for c in content
                        )
                        has_tool_result = any(
                            isinstance(c, dict) and c.get("type") == "tool_result"
                            for c in content
                        )
                        if has_text and not has_tool_result:
                            user_messages += 1

            # --- Assistant messages ---
            if msg_type == "assistant":
                assistant_turns += 1
                msg = obj.get("message", {})
                usage = msg.get("usage", {})
                model = msg.get("model", "unknown")
                models.add(model)

                # Accumulate usage per model
                if model not in usage_by_model:
                    usage_by_model[model] = {
                        "input_tokens": 0,
                        "output_tokens": 0,
                        "cache_read_input_tokens": 0,
                        "cache_creation_input_tokens": 0,
                    }
                for key in usage_by_model[model]:
                    usage_by_model[model][key] += usage.get(key, 0)

                # Parse tool uses
                content = msg.get("content", [])
                for c in content:
                    if not isinstance(c, dict) or c.get("type") != "tool_use":
                        continue

                    name = c.get("name", "unknown")
                    tool_counts[name] += 1
                    inp = c.get("input", {})

                    if name == "Task":
                        agent_spawns.append({
                            "type": inp.get("subagent_type", "unknown"),
                            "description": inp.get("description", ""),
                            "model": inp.get("model"),
                            "background": inp.get("run_in_background", False),
                        })
                    elif name == "Write":
                        fp = inp.get("file_path", "")
                        if fp:
                            files_written.add(fp)
                    elif name == "Edit":
                        fp = inp.get("file_path", "")
                        if fp:
                            files_edited.add(fp)
                    elif name == "Read":
                        fp = inp.get("file_path", "")
                        if fp:
                            files_read.add(fp)
                    elif name == "Bash":
                        cmd = inp.get("command", "")
                        bash_commands.append(cmd)
                        # Detect git commits
                        if "git commit" in cmd:
                            # Try to extract commit message
                            # HEREDOC format: git commit -m "$(cat <<'EOF'\n<msg>\nEOF\n)"
                            match = re.search(r"<<'?EOF'?\s*\n(.+?)\nEOF", cmd, re.DOTALL)
                            if not match:
                                # Simple -m "msg" or -m 'msg'
                                match = re.search(r'-m\s+["\'](.+?)["\']', cmd)
                            if match:
                                msg_text = match.group(1).strip().split("\n")[0][:120]
                            else:
                                msg_text = "(message not parsed)"
                            git_commits.append(msg_text)

    # Derive project name from cwd
    if cwd:
        project = Path(cwd).name

    # Calculate duration
    duration_seconds = 0
    start_time = None
    end_time = None
    if timestamps:
        try:
            start_time = timestamps[0]
            end_time = timestamps[-1]
            t1 = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
            t2 = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
            duration_seconds = int((t2 - t1).total_seconds())
        except (ValueError, TypeError):
            pass

    # Calculate total cost
    total_cost = 0.0
    for model, usage in usage_by_model.items():
        total_cost += estimate_cost(model, usage)

    # Total tokens
    total_input = sum(u["input_tokens"] for u in usage_by_model.values())
    total_output = sum(u["output_tokens"] for u in usage_by_model.values())
    total_cache_read = sum(u["cache_read_input_tokens"] for u in usage_by_model.values())
    total_cache_create = sum(u["cache_creation_input_tokens"] for u in usage_by_model.values())

    # Shorten file paths (relative to cwd if possible)
    def shorten(fp: str) -> str:
        if cwd and fp.startswith(cwd):
            return fp[len(cwd):].lstrip("/")
        home = str(Path.home())
        if fp.startswith(home):
            return "~" + fp[len(home):]
        return fp

    return {
        "session_id": session_id,
        "project": project,
        "branch": branch,
        "cwd": cwd,
        "claude_code_version": version,
        "start_time": start_time,
        "end_time": end_time,
        "duration_seconds": duration_seconds,
        "duration_human": format_duration(duration_seconds),
        "user_messages": user_messages,
        "assistant_turns": assistant_turns,
        "models": sorted(models),
        "tokens": {
            "input": total_input,
            "output": total_output,
            "cache_read": total_cache_read,
            "cache_create": total_cache_create,
            "total": total_input + total_output + total_cache_read + total_cache_create,
        },
        "estimated_cost_usd": round(total_cost, 4),
        "tools": dict(tool_counts.most_common()),
        "agents": agent_spawns,
        "files": {
            "read": sorted(shorten(f) for f in files_read),
            "written": sorted(shorten(f) for f in files_written),
            "edited": sorted(shorten(f) for f in files_edited),
        },
        "git_commits": git_commits,
    }


def format_duration(seconds: int) -> str:
    """Format seconds into human-readable duration."""
    if seconds < 60:
        return f"{seconds}s"
    minutes = seconds // 60
    secs = seconds % 60
    if minutes < 60:
        return f"{minutes}m {secs}s"
    hours = minutes // 60
    mins = minutes % 60
    return f"{hours}h {mins}m"


def print_summary(data: dict) -> None:
    """Print a human-readable summary."""
    print("=" * 64)
    print(f"  Session Summary: {data['session_id'][:12]}...")
    print("=" * 64)
    print(f"  Project:    {data['project'] or 'unknown'}")
    print(f"  Branch:     {data['branch'] or 'unknown'}")
    print(f"  Duration:   {data['duration_human']}")
    print(f"  Model(s):   {', '.join(data['models'])}")
    print(f"  CC Version: {data['claude_code_version'] or 'unknown'}")
    print()

    # Tokens & Cost
    t = data["tokens"]
    print("  Tokens:")
    print(f"    Input:        {t['input']:>10,}")
    print(f"    Output:       {t['output']:>10,}")
    print(f"    Cache read:   {t['cache_read']:>10,}")
    print(f"    Cache create: {t['cache_create']:>10,}")
    print(f"    Total:        {t['total']:>10,}")
    print(f"  Estimated Cost: ${data['estimated_cost_usd']:.4f}")
    print()

    # Interaction
    print(f"  User messages:    {data['user_messages']}")
    print(f"  Assistant turns:  {data['assistant_turns']}")
    print()

    # Tools
    if data["tools"]:
        print("  Tool Usage:")
        for tool, count in data["tools"].items():
            print(f"    {tool:<20} {count:>4}x")
        print()

    # Agents
    if data["agents"]:
        print(f"  Agents Spawned ({len(data['agents'])}):")
        for a in data["agents"]:
            model_tag = f" [{a['model']}]" if a.get("model") else ""
            bg_tag = " (bg)" if a.get("background") else ""
            print(f"    - [{a['type']}]{model_tag}{bg_tag} {a['description']}")
        print()

    # Files
    files = data["files"]
    modified = sorted(set(files["written"]) | set(files["edited"]))
    if modified:
        print(f"  Files Modified ({len(modified)}):")
        for f in modified[:20]:
            print(f"    {f}")
        if len(modified) > 20:
            print(f"    ... and {len(modified) - 20} more")
        print()

    if files["read"]:
        print(f"  Files Read: {len(files['read'])}")
        print()

    # Commits
    if data["git_commits"]:
        print(f"  Git Commits ({len(data['git_commits'])}):")
        for c in data["git_commits"]:
            print(f"    - {c}")
        print()

    print("=" * 64)


def append_to_log(data: dict) -> Path:
    """Append summary to monthly session log."""
    SESSION_LOG_DIR.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc)
    log_file = SESSION_LOG_DIR / f"{now.strftime('%Y-%m')}.jsonl"

    with open(log_file, "a") as f:
        f.write(json.dumps(data, default=str) + "\n")

    return log_file


def find_project_transcripts(project_path: str) -> list[str]:
    """Find all transcript files for a project."""
    # Claude Code stores transcripts in ~/.claude/projects/<encoded-path>/
    encoded = project_path.replace("/", "-").lstrip("-")
    transcript_dir = CLAUDE_DIR / "projects" / encoded
    if not transcript_dir.exists():
        return []
    return sorted(str(p) for p in transcript_dir.glob("*.jsonl"))


def find_today_transcripts() -> list[str]:
    """Find all transcript files modified today."""
    today = datetime.now().strftime("%Y-%m-%d")
    results = []
    projects_dir = CLAUDE_DIR / "projects"
    if not projects_dir.exists():
        return []
    for jsonl in projects_dir.rglob("*.jsonl"):
        mtime = datetime.fromtimestamp(jsonl.stat().st_mtime).strftime("%Y-%m-%d")
        if mtime == today:
            results.append(str(jsonl))
    return sorted(results)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    import argparse

    parser = argparse.ArgumentParser(description="Claude Code Session Summary")
    parser.add_argument("transcript", nargs="?", help="Path to transcript .jsonl file")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of human-readable")
    parser.add_argument("--log", action="store_true", help="Append summary to session log")
    parser.add_argument("--today", action="store_true", help="Summarize all sessions from today")
    parser.add_argument("--project", type=str, help="Summarize all sessions for a project path")

    args = parser.parse_args()

    transcripts = []

    if args.today:
        transcripts = find_today_transcripts()
        if not transcripts:
            print("No sessions found for today.")
            sys.exit(0)
    elif args.project:
        transcripts = find_project_transcripts(args.project)
        if not transcripts:
            print(f"No sessions found for project: {args.project}")
            sys.exit(1)
    elif args.transcript:
        transcripts = [args.transcript]
    else:
        parser.print_help()
        sys.exit(1)

    all_summaries = []
    for t in transcripts:
        if not os.path.exists(t):
            print(f"File not found: {t}", file=sys.stderr)
            continue
        data = parse_transcript(t)
        all_summaries.append(data)

        if args.log:
            log_path = append_to_log(data)

    if args.json:
        if len(all_summaries) == 1:
            print(json.dumps(all_summaries[0], indent=2, default=str))
        else:
            print(json.dumps(all_summaries, indent=2, default=str))
    else:
        for data in all_summaries:
            print_summary(data)
            print()

        if args.log:
            print(f"Logged to: {log_path}")

        # Print aggregate if multiple sessions
        if len(all_summaries) > 1:
            total_cost = sum(d["estimated_cost_usd"] for d in all_summaries)
            total_duration = sum(d["duration_seconds"] for d in all_summaries)
            total_turns = sum(d["assistant_turns"] for d in all_summaries)
            print(f"{'─' * 64}")
            print(f"  Aggregate: {len(all_summaries)} sessions")
            print(f"  Total duration: {format_duration(total_duration)}")
            print(f"  Total turns:    {total_turns}")
            print(f"  Total cost:     ${total_cost:.4f}")
            print(f"{'─' * 64}")


if __name__ == "__main__":
    main()
