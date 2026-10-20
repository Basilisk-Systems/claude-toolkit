# Navigation chrome

Sources:
- https://developer.apple.com/design/human-interface-guidelines/toolbars (navigation bar guidance was folded into Toolbars on 2025-06-09; the old `navigation-bars` slug returns 404)
- https://developer.apple.com/design/human-interface-guidelines/tab-bars
- https://developer.apple.com/design/human-interface-guidelines/scroll-views
- https://developer.apple.com/design/human-interface-guidelines/layout
- https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
- https://developer.apple.com/design/whats-new/
- https://developer.android.com/develop/ui/compose/components/app-bars
- https://developer.android.com/develop/ui/compose/components/navigation-bar
- https://github.com/material-components/material-components-android/blob/master/docs/components/BottomNavigation.md
- https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture
- https://developer.android.com/design/ui/mobile/guides/patterns/predictive-back
- https://developer.android.com/design/ui/mobile/guides/foundations/system-bars

## iOS navigation bar (top toolbar)
- Contents: "The title of the current view", "Navigation controls, like back and forward, and Search fields", "Actions, or bar items." "In iOS, a navigation-specific toolbar is sometimes called a navigation bar."
- "Use the standard Back and Close buttons ... Prefer the standard symbols for each, and don't use a text label that says Back or Close. If you create a custom version of either, make sure it still looks the same, behaves as people expect."
- Titles: "Provide a useful title for each window." "Don't title windows with your app name." "Keep the title under 15 characters long." Empty title is acceptable if redundant.
- "Use a large title to help people stay oriented"; it collapses to a standard title on scroll.
- Actions: "Prefer simple, recognizable symbols for items instead of text, except for actions like edit." "Prefer system-provided symbols without borders." One `.prominent` primary action, trailing side.
- Item groups: leading (back, title), center, trailing (primary action like Done). "In general, aim for a maximum of three" groups. "Keep actions with text labels separate" (fixed space between).
- "Choose items deliberately to avoid overcrowding." iOS: "Prioritize only the most important items ... Create a More menu."
- "Reduce the use of toolbar backgrounds and tinted controls" — use a scroll edge effect instead of a solid bar background (Liquid Glass era).
- Ergonomics (designing-for-iOS): controls "in the middle or bottom area of the display" are easier to reach; "it's especially important let people swipe to navigate back."

## iOS tab bar
- "Use a tab bar to support navigation, not to provide actions." Actions go in a toolbar.
- "Make sure the tab bar is visible when people navigate to different sections" — exception: a modal covering it.
- Number of tabs: no number given on the current page — "keep in mind that it's generally easier to navigate among fewer tabs." "Avoid overflow tabs" (the trailing tab becomes More). iPadOS customization: "aim for a default list of five or fewer."
- "Don't disable or hide tab bar buttons, even when their content is unavailable ... If a section is empty, explain why."
- "Include tab labels ... Use single words whenever possible."
- "Prefer filled symbols or icons for consistency with the platform."
- Badges: "a red oval containing white text and either a number or an exclamation point"; "Reserve badges for critical information."
- iOS 26: "A tab bar floats above content at the bottom of the screen. Its items rest on a Liquid Glass background."

## Android top app bar (Material 3)
| Type | When (quoted) |
|---|---|
| Small | "screens that don't require a lot of navigation or actions" |
| Center aligned | "screens that have a single, primary action" |
| Medium | "a moderate amount of navigation and actions" |
| Large | "a lot of navigation and actions" |
- `navigationIcon` — "The primary icon for navigation. Appears on the left of the app bar"; samples use the auto-mirrored back arrow with a contentDescription.
- Scroll behaviours: enterAlways, exitUntilCollapsed, pinned.

## Android navigation bar (bottom)
- "Three to five destinations of equal importance", "Compact window sizes", "Consistent destinations across app screens."
- "Each destination is represented by an icon and label text." Default `LABEL_VISIBILITY_AUTO` shows labels on all items for ≤3 items and only the selected label for ≥4 — set labeled mode to keep labels visible (RN tab navigators show labels by default).

## Back behaviour
| | iOS | Android |
|---|---|---|
| Gesture | Swipe from the leading edge (designing-for-iOS, toolbars) | Swipe from left or right edge; "Back returns to the previous view" |
| Button | Standard back chevron in nav bar | System back (gesture or 3-button) + optional app-bar up arrow |
| Preview | Interactive pop | Predictive back: "lets users preview where the back swipe takes them" |

Predictive back (Android):
- "Predictive back is enabled by default." Android 15+: back-to-home, cross-task, cross-activity animations are on by default for apps that support it.
- Opt out with `android:enableOnBackInvokedCallback="false"` — not recommended: "We strongly recommend that you implement predictive back navigation as soon as possible."
- Back callbacks that intercept suppress the animation: "Don't create these callbacks to run business logic or to log." "Use system back callbacks to run UI logic, such as displaying a dialog."
- "Avoid adding touch gestures or drag targets under these gesture areas" (gesture insets).
- RN implication: intercepting `hardwareBackPress` / `beforeRemove` only for real UI logic (unsaved-changes dialog), never for analytics.

## Edge-to-edge and safe areas
- iOS: "Respecting the safe area is essential to make sure system UI and hardware features like the Dynamic Island don't obstruct content and controls."
- Android: "Edge-to-edge is enforced on Android 15." "Avoid adding interactions or touch targets under gesture navigation insets." "Keep the gesture navigation bar transparent."
- "Determine layout based on size classes, not device type or orientation."
