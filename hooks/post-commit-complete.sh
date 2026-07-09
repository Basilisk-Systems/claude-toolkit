#!/bin/bash
# Post-commit hook: Remind Claude to run /complete after git commits
#
# PostToolUse: stdout on exit 0 is NOT shown to Claude. To surface the
# reminder, print to stderr and exit 2 (non-blocking — the tool already ran,
# but stderr is fed back to Claude). Silent exit 0 when there is nothing to say.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Check if this is a git commit command (not amend, which is usually a follow-up)
if echo "$command" | grep -qE '^git\s+commit\s+' && ! echo "$command" | grep -qE '\-\-amend'; then
  # Extract ticket ID from commit message if present (format: PROJ-123 style)
  ticket=$(echo "$command" | grep -oE '[A-Z][A-Z0-9]+(-[A-Z0-9]+)*-[0-9]+' | head -1)

  if [ -n "$ticket" ]; then
    echo "Git commit detected for ticket $ticket. Run '/complete $ticket' to update CHANGELOG and README." >&2
  else
    echo "Git commit detected. If this completes a ticket, run '/complete [ticket-id]' to update CHANGELOG and README." >&2
  fi
  exit 2
fi

exit 0
