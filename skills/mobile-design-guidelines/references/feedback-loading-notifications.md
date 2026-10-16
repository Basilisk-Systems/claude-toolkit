# Feedback, loading, progress, haptics, notifications

Sources:
- https://developer.apple.com/design/human-interface-guidelines/feedback
- https://developer.apple.com/design/human-interface-guidelines/loading
- https://developer.apple.com/design/human-interface-guidelines/progress-indicators
- https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- https://developer.apple.com/design/human-interface-guidelines/notifications
- https://developer.android.com/develop/ui/compose/components/snackbar

## Feedback
- Match delivery to significance: status passively; data-loss warnings interrupt.
- "Make sure all feedback is accessible" — color + text + sound + haptics.
- "Consider integrating status feedback into your interface" near the items it describes.
- "Use alerts to deliver critical — and ideally actionable — information."
- "When it makes sense, confirm that a significant action or task has completed ... people typically expect their action or task to succeed, they only need to know when it doesn't."
- "Show people when a command can't be carried out and help them understand why."

## Loading
- "Show something as soon as possible ... consider showing placeholder text, graphics, or animations as content loads." (This is the guideline basis for skeletons; the HIG does not name skeletons explicitly.)
- "Let people do other things in your app ... while they wait."
- Use determinate indicators when duration is known, indeterminate when not.

## Progress indicators
- Determinate (bar or ring, fills leading→trailing / clockwise) vs indeterminate (spinner).
- "When possible, use a determinate progress indicator."
- "Be as accurate as possible" — don't jump to 90% then stall.
- "Keep progress indicators moving"; if stalled, explain.
- Switch indeterminate→determinate when possible; "Don't switch from the circular style to the bar style."
- Description: "Avoid vague terms like loading or authenticating."
- "Display a progress indicator in a consistent location."
- Allow Cancel when safe; Pause if cancelling loses work; confirm cancellation that loses progress.
- In-button spinner: buttons page — show an activity indicator in the button, optionally with an "…ing" label.
- Refresh control: also auto-refresh; title only if valuable.

## Haptics (iOS; expo-haptics wraps these)
- "Use system-provided haptic patterns according to their documented meanings":
  - Notification — "outcome of a task or action" (success / warning / error).
  - Impact — "complement a visual experience" (snap into place, collision).
  - Selection — "while the values of a UI element are changing."
- Standard toggles, sliders, pickers already play haptics.
- "Use haptics consistently"; "complement other feedback"; "Avoid overusing haptics"; "prefer playing short haptics that complement discrete events."
- "Make haptics optional. Let people turn off or mute haptics."

## Notifications
- Require consent. "Provide concise, informative notifications."
- "Avoid sending multiple notifications for the same thing, even if someone hasn't responded."
- "Avoid sending a notification that tells people to perform specific tasks within your app" — use notification actions instead.
- "Use an alert — not a notification — to display an error message."
- Foreground: present "discoverable but not distracting" (badge, insert data).
- "Avoid including sensitive, personal, or confidential information in a notification." (Health data qualifies.)
- Title: short, title-style caps, no ending punctuation; skip generic titles (system shows app name).
- Body: complete sentences, sentence case; don't truncate yourself.
- Hidden-preview placeholder text: generic ("Reminder", "New comment").
- Don't include app name or icon.
- Sound: short, distinctive; never the only carrier of important info.
- Actions: up to four; short title-case labels describing the result; no action that just opens the app; prefer nondestructive; give each an icon.
- Badges: "only to show people how many unread notifications they have"; never the only signal; keep up to date; never fake a badge.
- Android snackbar is the in-app transient equivalent, not a notification.
