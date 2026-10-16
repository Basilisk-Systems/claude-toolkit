# Buttons and actions

Sources:
- https://developer.apple.com/design/human-interface-guidelines/buttons
- https://developer.apple.com/design/human-interface-guidelines/toolbars (Actions)
- https://developer.apple.com/design/human-interface-guidelines/accessibility (Mobility)
- https://developer.android.com/develop/ui/compose/components/button
- https://github.com/material-components/material-components-android/blob/master/docs/components/CommonButton.md
- https://developer.android.com/guide/topics/ui/accessibility/apps

Fetched 2026-10-16. Quotes are the guideline's own wording.

## iOS — the three attributes
A button "combines three attributes": **Style** (size, color, shape), **Content** (symbol, text, or both), **Role** (system-defined meaning that "can affect its appearance").

## iOS — sizing and spacing
| Rule | Value | Source |
|---|---|---|
| Hit region | "at least 44x44 pt" | buttons |
| Default control size (iOS) | 44x44 pt | accessibility |
| Minimum control size (iOS) | 28x28 pt | accessibility |
| Padding around bezeled elements | "about 12 points" | accessibility |
| Padding around non-bezeled elements | "about 24 points ... around the element's visible edges" | accessibility |

- "It's essential to include enough space around a button so that people can visually distinguish it from surrounding components."
- "Always include a press state for a custom button. Without a press state, a button can feel unresponsive."

## iOS — style and prominence
- "Use a button that has a prominent visual style for the most likely action in a view."
- "Keep the number of prominent buttons to one or two per view. Presenting too many prominent buttons increases cognitive load."
- "Use style — not size — to visually distinguish the preferred choice among multiple options." Buttons of the same size "signal that the options form a coherent set of choices"; different sizes side by side "can make the interface look confusing and inconsistent."
- "Avoid applying a similar color to button labels and content layer backgrounds."
- Toolbars: "Use the .prominent style for key actions such as Done or Submit ... Only specify one primary action, and put it on the trailing side of the toolbar."

## iOS — content
- "Ensure that each button clearly communicates its purpose."
- "Try to associate familiar actions with familiar icons" (e.g. `square.and.arrow.up` for share).
- "Consider using text when a short label communicates more clearly than an icon." Use "title-style capitalization, consider starting the label with a verb" — e.g. "Add to Cart".
- Alert buttons are the exception: sentence-style capitalization, no ending punctuation (see modality.md).

## iOS — roles
| Role | Meaning | Appearance |
|---|---|---|
| Normal | "No specific meaning." | default |
| Primary | "the button people are most likely to choose" | "uses an app's accent color" |
| Cancel | "cancels the current action" | — |
| Destructive | "can result in data destruction" | "uses the system red color" |

- "Assign the primary role to the button people are most likely to choose."
- "Don't assign the primary role to a button that performs a destructive action, even if that action is the most likely choice. Because of its visual prominence, people sometimes choose a primary button without reading it first."

## iOS — async buttons
- "Configure a button to display an activity indicator when you need to provide feedback about an action that doesn't instantly complete." You can also swap the label — "'Checkout' could change to 'Checking out…'".

## Material 3 — emphasis ladder (Android)
CommonButton.md lists "five button styles, in order of emphasis": Elevated, Filled, Filled tonal, Outlined, Text. The Compose guide labels them by emphasis:

| Style | Emphasis | Use for (quoted) |
|---|---|---|
| Filled | High | "most prominent button after the FAB"; "final or unblocking actions in a flow such as Save, Join now, or Confirm" |
| Filled tonal | Between filled and outlined | "a lower-priority button requires slightly more emphasis than an outline would give, such as Next in an onboarding flow" |
| Elevated | Like tonal | "essentially outlined buttons with a shadow ... only use them when absolutely necessary, such as when the button requires visual separation from a patterned background" |
| Outlined | Medium | "actions that need attention but aren't the primary action"; "the button used to give someone the opportunity to change their mind or escape a flow"; "pair well with filled buttons to indicate a secondary, alternate action" |
| Text | Low | "low emphasis actions, such as when presenting multiple options"; "navigational links, or secondary functions like 'Learn More' or 'View details'" |

Android target size: "at least 48dpx48dp. Larger is even better." Material components enforce it; "when creating custom interactive elements, you need to set the size yourself."

## Route switches ("Don't have an account? Sign up")
Neither platform has a page for this pattern. Derivation from the rules above:
- It is a navigation to an alternate flow, not the primary action → Material "Text" ("navigational links") / iOS non-prominent style.
- Keep it to one prominent button per view: the primary is Sign in / Continue.
- Hit region still 44x44 pt / 48x48 dp even when rendered as text.

## Destructive actions
- iOS: system red via the destructive role; never the primary role (above).
- Confirm only uncommon, irreversible destruction (see modality.md, Alerts).
- Material color role for errors/destruction: `colorError` / `colorOnError` (Color.md).
