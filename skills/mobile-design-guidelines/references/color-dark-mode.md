# Colour, contrast and dark mode

Sources:
- https://developer.apple.com/design/human-interface-guidelines/color
- https://developer.apple.com/design/human-interface-guidelines/dark-mode
- https://developer.apple.com/design/human-interface-guidelines/accessibility (Vision)
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.android.com/guide/topics/ui/accessibility/apps
- https://developer.android.com/develop/ui/compose/designsystems/material3
- https://github.com/material-components/material-components-android/blob/master/docs/theming/Color.md
- https://developer.android.com/develop/ui/views/theming/darktheme

## Contrast minimums
iOS (Accessibility Inspector, WCAG AA):
| Text size | Weight | Minimum ratio |
|---|---|---|
| Up to 17 pt | All | 4.5:1 |
| 18 pt and up | All | 3:1 |
| All | Bold | 3:1 |

- Dark Mode page: "At a minimum, make sure the contrast ratio between colors is no lower than 4.5:1. For custom foreground and background colors, strive for a contrast ratio of 7:1, especially in small text."
- "If your app doesn't provide this minimum contrast by default, ensure it at least provides a higher contrast color scheme when the system setting Increase Contrast is turned on."
- Android: text "smaller than 18sp, or if the text is bold and smaller than 14sp" → at least 4.5:1; "all other text" → at least 3:1.
- Non-text contrast (icons, borders, chart marks): not specified as a ratio on the fetched pages beyond "foreground text and icons" being covered by the text table.

## Semantic colour
- "Avoid using the same color to mean different things" — if brand color marks interactive text, don't use it on noninteractive text.
- "Avoid hard-coding system color values." "Avoid redefining the semantic meanings of dynamic system colors ... don't use the separator color as a text color."
- iOS foreground roles: label, secondaryLabel, tertiaryLabel ("Text that describes an unavailable item"), quaternaryLabel ("Watermark text"), placeholderText, separator, opaqueSeparator, link.
- iOS backgrounds: systemBackground / secondary / tertiary (or the Grouped set for grouped lists) — "Primary for the overall view, Secondary for grouping content ... Tertiary for grouping content within secondary elements."
- Material roles: primary ("prominent buttons, active states"), secondary ("less prominent components ... filter chips"), tertiary ("contrasting accents"), error, surface + surfaceContainer{Lowest..Highest}, each paired with an on-* role. "Use on-primary on top of primary ... to provide accessible contrast." Disabled: "acceptable to use 'on-x' colors with alpha values."

## Never colour alone
- "Avoid relying solely on color to differentiate between objects, indicate interactivity, or communicate essential information ... use text labels or glyph shapes."
- "People who are color blind may have particular difficulty with pairings such as red-green and blue-orange. Offer visual indicators, like distinct shapes or icons."
- Toggles: "Avoid relying solely on different colors to communicate state."
- Charts: see charts-lists.md.
- "Red communicates danger in some cultures, but has positive connotations in other cultures."

## Dark mode
- "People often choose Dark Mode as their default interface style, and they generally expect all apps and games to respect their preference."
- "Avoid offering an app-specific appearance setting" — people "may think your app is broken because it doesn't respond to their systemwide appearance choice."
- "Ensure that your app looks good in both appearance modes" incl. Auto switching "potentially while your app is running."
- "In rare cases, consider using only a dark appearance" — immersive media apps.
- Color page: "If you define a custom color, make sure to supply light and dark variants, and an increased contrast option for each variant." "Even if your app ships in a single appearance mode, provide both light and dark colors to support Liquid Glass adaptivity."
- Dark palette colors "aren't necessarily inversions of their light counterparts."
- "Soften the color of white backgrounds" in content images.
- iOS Dark Mode uses base and elevated backgrounds; "Prefer the system background colors" so sheets read as elevated.
- Android: dark theme since Android 10; recommended in-app options are Light / Dark / "System default (the recommended default option)". "Avoid using hardcoded colors or icons intended for use under a light theme."
- Note the platforms differ: Apple says avoid an in-app appearance setting; Android documents one with System default as default.

## Testing
- "Test your app's color scheme under a variety of lighting conditions" — bright surroundings mute colors.
- Test Dark Mode with Increase Contrast and Reduce Transparency, "both separately and together."

## Materials / Liquid Glass
- Liquid Glass "forms a distinct functional layer for controls and navigation elements ... that floats above the content layer." "Don't use Liquid Glass in the content layer." "Use Liquid Glass effects sparingly."
- Color on glass: "Apply color sparingly ... To emphasize primary actions, apply color to the background rather than to symbols or text ... Refrain from adding color to the background of multiple controls."
