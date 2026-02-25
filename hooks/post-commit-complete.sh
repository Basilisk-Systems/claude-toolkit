#!/bin/bash
# Post-commit hook: Remind Claude to run /complete after git commits

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Check if this is a git commit command (not amend, which is usually a follow-up)
if echo "$command" | grep -qE '^git\s+commit\s+' && ! echo "$command" | grep -qE '\-\-amend'; then
  # Extract ticket ID from commit message if present (format: DR2-V1-XXX or DRNG-XXX)
  ticket=$(echo "$command" | grep -oE '(DR2-V1-[0-9]+|DRNG-[0-9]+)' | head -1)

  if [ -n "$ticket" ]; then
    echo "Git commit detected for ticket $ticket. Run '/complete $ticket' to update CHANGELOG and README."
  else
    echo "Git commit detected. If this completes a ticket, run '/complete [ticket-id]' to update CHANGELOG and README."
  fi
fi

exit 0
