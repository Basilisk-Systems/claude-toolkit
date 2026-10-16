# Modality: sheets, alerts, action sheets, dialogs, snackbars

Sources:
- https://developer.apple.com/design/human-interface-guidelines/modality
- https://developer.apple.com/design/human-interface-guidelines/sheets
- https://developer.apple.com/design/human-interface-guidelines/alerts
- https://developer.apple.com/design/human-interface-guidelines/action-sheets
- https://developer.apple.com/design/human-interface-guidelines/activity-views
- https://developer.apple.com/design/human-interface-guidelines/feedback
- https://developer.android.com/develop/ui/compose/components/dialog
- https://developer.android.com/develop/ui/compose/components/snackbar
- https://github.com/material-components/material-components-android/blob/master/docs/components/Dialog.md
- https://github.com/material-components/material-components-android/blob/master/docs/components/Snackbar.md

## Choosing the component
| Need | iOS | Android |
|---|---|---|
| Scoped task related to current context (form, picker) | Sheet | Bottom sheet / full-screen dialog |
| Complex or multistep task, media | Full-screen modal | Full-screen dialog / new screen |
| Critical info needing action now | Alert | Dialog (AlertDialog) |
| Choices about an action the person just initiated | Action sheet | Bottom sheet or dialog with options |
| Non-blocking confirmation / undo | Inline status (no system toast) | Snackbar |
| Share | Activity view (Share button) | System share sheet |

## Modality rules (iOS)
- "Present content modally only when there's a clear benefit."
- "Aim to keep modal tasks simple, short, and streamlined." Avoid "an app within your app"; if subviews are needed, "provide a single path."
- "Always give people an obvious way to dismiss a modal view" — iOS: "a button in the top toolbar or swipe down."
- "If closing the view could result in the loss of user-generated content, be sure to explain the situation and give people ways to resolve it" — e.g. an action sheet with a save option.
- "Make it easy to identify a modal view's task" — give it a title.
- "Let people dismiss a modal view before presenting another one." "Never ... display more than one alert at the same time."

## Sheets (iOS)
- Buttons: Cancel/Close (dismiss, no save), Done (dismiss after completing/saving), Back (previous step; "isn't intended to dismiss a sheet").
- "In iOS and iPadOS, for sheets with a single view, the Cancel button belongs on the leading edge of the top toolbar. When present, the Done button belongs on the trailing edge."
- "If you provide a Done button, always pair it with a Cancel button ... or a Back button." "Avoid showing all three buttons — Cancel, Done, and Back — together."
- "Display only one sheet at a time from the main interface."
- Detents: large (full) and medium ("about half"). Consider medium for progressive disclosure; skip it for compose-style content.
- "Include a grabber in a resizable sheet" (also works with VoiceOver).
- "Support swiping to dismiss a sheet ... If people have unsaved changes ... use an action sheet to let them confirm."

## Alerts (iOS)
When:
- "Use alerts sparingly." "Avoid using an alert merely to provide information."
- "Avoid displaying alerts for common, undoable actions, even when they're destructive." Alert for "an uncommon destructive action that they can't undo."
- "Avoid showing an alert when your app starts" — show cached data plus "a nonintrusive label."
- Feedback page: "Warn people when they initiate a task that can cause data loss that's unexpected and irreversible ... don't warn people when data loss is the expected result."
Content:
- Title, optional message, "up to three buttons"; can include a text field.
- "Write a title that clearly and succinctly describes the situation." Not "Error"; not more than two lines. Sentence → sentence case + punctuation; fragment → title case, no punctuation.
- "Include informative text only if it adds value." "Avoid explaining alert buttons."
- Tone: "be direct, and use a neutral, approachable tone ... avoid being oblique or accusatory."
Buttons:
- "Aim for a one- or two-word title that describes the result" — "View All," "Reply," "Ignore." Sentence-style capitalization, no punctuation.
- "Avoid using OK as the default button title unless the alert is purely informational." Avoid "Yes" and "No". Prefer "Erase," "Convert," "Clear," "Delete."
- "Always use 'Cancel' to title a button that cancels the alert's action."
- Placement: default/likely button "on the trailing side of a row or at the top of a stack"; Cancel "on the leading side of a row or at the bottom of a stack."
- "Use the destructive style to identify a button that performs a destructive action people didn't deliberately choose." When the person deliberately chose the action (Empty Trash), the confirm button is not styled destructive.
- "If there's a destructive action, include a Cancel button." "You don't want to make a Cancel button the default button."
- "When possible, avoid displaying an alert that scrolls" (large text sizes).
- iOS: "Use an action sheet — not an alert — to offer choices related to an intentional action."

## Action sheets (iOS)
- "Use action sheets sparingly." Title on one line; message "only if necessary."
- Cancel at the bottom. "Make destructive choices visually prominent ... place these buttons at the top."
- "Use an action sheet — not a menu — to provide choices related to an action." "Avoid letting an action sheet scroll."

## Activity views (share sheet)
- "Use the Share button to display an activity view." Don't duplicate system actions (Print). Custom action titles: a verb, no company name.

## Android dialogs
- Use cases: "Confirming user action, such as when deleting a file", "Requesting user input", "Presenting a list of options."
- AlertDialog slots: icon, title, text, confirmButton, dismissButton; onDismissRequest fires on tap outside. Both buttons close it.
- "If you only need to display a two-button dialog ... use AlertDialog"; complex forms → custom Dialog.
- Variants: basic and full-screen. Button order beyond confirm/dismiss slots: not specified in fetched sources.

## Android snackbars
- "Snackbars inform users of a process that an app has performed or will perform ... They shouldn't interrupt the user experience, and they don't require user input to disappear."
- Optional action, "such as undoing an action that was just taken, or retrying an action that had failed."
- Default duration Short; Indefinite stays until dismissed. Timed UI conflicts with Apple's "Minimize use of time-boxed interface elements" — keep the action reachable elsewhere.
