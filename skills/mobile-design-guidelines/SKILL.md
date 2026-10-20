---
name: mobile-design-guidelines
description: Platform design rulebook distilled from Apple's Human Interface Guidelines (iOS 26 / Liquid Glass era) plus Material 3 and Android guidance where Android differs, written for React Native + Expo apps. Covers layout and touch targets, Dynamic Type and type scales, colour/contrast/dark mode, button prominence and emphasis, navigation bars, tab bars and back behaviour (incl. Android predictive back), forms and pickers, sheets/alerts/action sheets, feedback/loading/haptics, onboarding/accounts/permissions, lists and charts, accessibility and notifications, each rule cited to its source page. Complements mobile-ux-patterns (Iduna-specific flows). TRIGGER when designing or reviewing any mobile screen or component, choosing button styles or variants, deciding navigation chrome (headers, tab bars, back buttons, modals), making typography, colour, contrast or dark-mode decisions, answering accessibility, VoiceOver/TalkBack, Dynamic Type or font-scaling questions, or asking "is X standard on iOS/Android?". SKIP for web UI, backend or infrastructure work, and implementation details of a design that is already settled.
---

# Mobile Design Guidelines (HIG + Material 3)

## How to use this skill
1. Find the section for the decision you are making (sections 1–13 follow screen-building order).
2. Apply the imperative rules; quoted text is the guideline's own wording.
3. Numbers marked "not specified" were not stated on the source page — do not invent one.
4. iOS rules are the baseline; the "Android" lines say where Material 3 differs.
5. For fuller notes, open the linked file in `references/` (one per guideline group).
6. For Iduna, read the final "Iduna mapping" and "Open deviations" before changing tokens or components.
7. Flows, offline UX and health-app tone live in the `mobile-ux-patterns` skill, not here.
8. Store submission rules (Sign in with Apple obligation, review) live in `app-store-publishing`.
9. Sources were fetched 2026-10-16 (Apple DocC JSON; Android/Material from developer.android.com and the material-components-android docs, since m3.material.io is client-rendered).
10. When a guideline and an existing implementation disagree, report it; don't silently "fix" settled design.

---

## 1. Platform posture
- **One design, native components.** iOS guidance: "Help people concentrate on primary tasks and content by limiting the number of onscreen controls." Use platform-native controls where they exist (date pickers, switches, alerts, action sheets, share sheet) so each OS gets its own behaviour; keep custom content (cards, charts) the same on both.
- "Adapt seamlessly to appearance changes — like device orientation, Dark Mode, and Dynamic Type."
- Put frequent controls "in the middle or bottom area of the display"; "let people swipe to navigate back or initiate actions in a list row."
- "With people's permission, integrate information available through platform capabilities ... without asking people to enter data" (HealthKit / Health Connect before manual entry).
- **Where iOS and Android legitimately differ:** back (edge swipe + chevron vs system back + predictive preview), top-bar title placement, alert/dialog button layout, action sheet vs bottom sheet, snackbar (Android only), in-app theme toggle (Android allows, Apple discourages), touch target (44 pt vs 48 dp). Let native-stack / `Alert.alert` / datetimepicker render each platform's version.
- **Liquid Glass (iOS 26).** "Liquid Glass forms a distinct functional layer for controls and navigation elements — like tab bars and sidebars — that floats above the content layer." "Don't use Liquid Glass in the content layer." "Use Liquid Glass effects sparingly. Standard components from system frameworks pick up the appearance and behavior of this material automatically." Toolbars: "Reduce the use of toolbar backgrounds and tinted controls."
- **Why Iduna ignores chrome effects:** RN draws its own content, and the guidance itself says standard components get the material automatically. Hand-rolled glass/blur in the content layer is explicitly discouraged, and an Android twin would not exist. Rely on native-stack / native tab bars to pick up the system look; don't imitate it. One Liquid Glass rule still applies to custom colours: "provide both light and dark colors" even for a light-only app.

Source: https://developer.apple.com/design/human-interface-guidelines/designing-for-ios · https://developer.apple.com/design/human-interface-guidelines/materials · https://developer.apple.com/design/human-interface-guidelines/toolbars · https://developer.apple.com/design/human-interface-guidelines/color · https://developer.apple.com/design/whats-new/ — details: [references/platform-layout-icons.md](references/platform-layout-icons.md), [references/material-differences.md](references/material-differences.md)

## 2. Layout and spacing
| Item | iOS | Android |
|---|---|---|
| Touch target | "at least 44x44 pt" (default 44x44, minimum 28x28) | "at least 48dpx48dp. Larger is even better." |
| Padding between controls | ~12 pt around bezeled elements; ~24 pt around non-bezeled | not specified |
| Grid | not specified (HIG uses layout guides) | "8 dp grid for layout, components, and spacing"; 4 dp for icons/type |
| Screen side margins | not specified (system layout margins) | not specified on fetched pages |
| Safe areas | "Respecting the safe area is essential" | Edge-to-edge "enforced on Android 15"; no touch targets under gesture insets |

- "Consider spacing between controls as important as size."
- "Order content by relative importance" — top and leading side first. "Group related items" with space, containers or separators. "Use progressive disclosure."
- "Determine layout based on size classes, not device type or orientation."
- Large text: "horizontally adjacent views may need to stack vertically ... table rows ... may need to grow in height."
- RN: get insets from `react-native-safe-area-context`; reach targets with `minHeight/minWidth` and `hitSlop`; never fixed `height` on text rows.

```tsx
// Icon-only control: 48 floor satisfies 44 pt (iOS) and 48 dp (Android)
<Pressable
  accessibilityRole="button"
  accessibilityLabel="Add meal"
  hitSlop={8}
  style={({ pressed }) => [{ minWidth: 48, minHeight: 48, alignItems: "center", justifyContent: "center" }, pressed && { opacity: 0.6 }]}
>
  <Ionicons name="add" size={24} />
</Pressable>
```

Source: https://developer.apple.com/design/human-interface-guidelines/layout · https://developer.apple.com/design/human-interface-guidelines/accessibility · https://developer.apple.com/design/human-interface-guidelines/buttons · https://developer.android.com/guide/topics/ui/accessibility/apps · https://developer.android.com/design/ui/mobile/guides/layout-and-content/grids-and-units · https://developer.android.com/design/ui/mobile/guides/foundations/system-bars — details: [references/platform-layout-icons.md](references/platform-layout-icons.md)

## 3. Typography
iOS text styles at the default Dynamic Type size (Large):

| iOS style | Weight | pt / leading | Material role (sp) |
|---|---|---|---|
| Large Title | Regular | 34 / 41 | headlineLarge 32/40 |
| Title 1 | Regular | 28 / 34 | headlineMedium 28/36 |
| Title 2 | Regular | 22 / 28 | titleLarge 22/28 |
| Title 3 | Regular | 20 / 25 | — |
| Headline | Semibold | 17 / 22 | titleMedium 16/24 (Medium) |
| Body | Regular | 17 / 22 | bodyLarge 16/24 |
| Callout | Regular | 16 / 21 | — |
| Subhead | Regular | 15 / 20 | bodyMedium 14/20 / titleSmall 14/20 |
| Footnote | Regular | 13 / 18 | — |
| Caption 1 | Regular | 12 / 16 | bodySmall 12/16 · labelMedium 12/16 |
| Caption 2 | Regular | 11 / 13 | labelSmall 11/16 |

(The column pairing is this skill's mapping; neither guideline maps across.)

- Floors: iOS "Default size 17 pt, Minimum size 11 pt" for custom and system fonts. Thin custom weights → go larger.
- "In general, avoid light font weights" (Ultralight, Thin, Light).
- "Minimize the number of typefaces." Use weight, size and colour for hierarchy.
- Range to design for: Body is 14 pt at xSmall, 23 pt at xxxLarge, 53 pt at AX5. "Ideally, give people the option to enlarge text by at least 200 percent."
- "Make sure your app's layout adapts to all font sizes." "Keep text truncation to a minimum." "Consider using a stacked layout" at large sizes. "Maintain a consistent information hierarchy regardless of the current font size."
- "Prioritize important content when responding to text-size changes" — chrome such as tab titles needn't grow as much as content.
- "If you need to display three or more lines of text, avoid tight leading."
- Android: "Always specify font sizes in sp." RN `fontSize` already scales with the OS setting on both platforms — keep `allowFontScaling` on; cap single fragile elements with `maxFontSizeMultiplier`, never globally.

Source: https://developer.apple.com/design/human-interface-guidelines/typography · https://developer.apple.com/design/human-interface-guidelines/accessibility · https://developer.android.com/develop/ui/compose/designsystems/material3 · https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md — details: [references/typography.md](references/typography.md)

## 4. Colour and dark mode
| Text | iOS minimum | Android minimum |
|---|---|---|
| Up to 17 pt (Android: <18 sp, or bold <14 sp) | 4.5:1 | 4.5:1 |
| 18 pt+ or bold | 3:1 | 3:1 |
| Custom fg/bg colours (Dark Mode page) | "strive for a contrast ratio of 7:1, especially in small text" | — |

- Use semantic roles, not raw values: iOS label / secondaryLabel / tertiaryLabel / separator / link and systemBackground tiers; Material primary / secondary / tertiary / error / surface with paired on-* roles ("Use on-primary on top of primary").
- "Avoid using the same color to mean different things" — accent marks interactivity; don't reuse it for static text.
- "Avoid relying solely on color to differentiate between objects, indicate interactivity, or communicate essential information ... use text labels or glyph shapes." Red-green and blue-orange are the problem pairs.
- "Red communicates danger in some cultures, but has positive connotations in other cultures."
- Dark mode: people "generally expect all apps and games to respect their preference." "Avoid offering an app-specific appearance setting" (Apple). Android documents Light / Dark / "System default (the recommended default option)".
- When to support it: the HIG treats supporting both as the default ("Ensure that your app looks good in both appearance modes"); a dark-only UI is for "rare cases" like immersive media. A light-only app is not an endorsed option, and custom colours need "light and dark variants, and an increased contrast option for each."
- Dark palettes "aren't necessarily inversions." Prefer system backgrounds so sheets appear elevated. "Soften the color of white backgrounds" in images.
- Test in sunlight/dim light and with Increase Contrast + Reduce Transparency.

Source: https://developer.apple.com/design/human-interface-guidelines/color · https://developer.apple.com/design/human-interface-guidelines/dark-mode · https://developer.apple.com/design/human-interface-guidelines/accessibility · https://developer.android.com/guide/topics/ui/accessibility/apps · https://developer.android.com/develop/ui/views/theming/darktheme · https://github.com/material-components/material-components-android/blob/master/docs/theming/Color.md — details: [references/color-dark-mode.md](references/color-dark-mode.md)

## 5. Buttons and actions
- Hit region "at least 44x44 pt" (Android 48 dp). "Always include a press state for a custom button."
- **One primary per screen.** "Use a button that has a prominent visual style for the most likely action in a view." "Keep the number of prominent buttons to one or two per view." In a toolbar: "Only specify one primary action, and put it on the trailing side."
- "Use style — not size — to visually distinguish the preferred choice." Equal-weight choices get the same style and size.
- iOS roles: Normal, Primary (accent colour), Cancel, Destructive (system red). "Don't assign the primary role to a button that performs a destructive action, even if that action is the most likely choice."
- Labels: "start the label with a verb", title-style capitalization ("Add to Cart"). Prefer text when it is clearer than an icon; familiar icons for familiar actions.
- Async: show an activity indicator inside the button; optionally switch the label ("Checking out…").

Material emphasis ladder (Android):
| Style | Emphasis | Use |
|---|---|---|
| Filled | High | "final or unblocking actions in a flow such as Save, Join now, or Confirm" |
| Filled tonal | Between | "such as Next in an onboarding flow" |
| Outlined | Medium | "important but not primary"; "give someone the opportunity to change their mind or escape a flow" |
| Text | Low | "navigational links", "Learn More", "View details" |
| Elevated | — | "only ... when absolutely necessary" (patterned backgrounds) |

- **Route switches** ("Don't have an account? Sign up", "Forgot password?"): low-emphasis text button. It navigates to another flow, so it must not compete with the screen's single primary. Keep the 44/48 target.
- **Destructive:** danger colour + explicit verb ("Delete", "Erase"), never the primary role. Confirm only uncommon, irreversible destruction (section 8). Prefer Undo for common deletes.

Source: https://developer.apple.com/design/human-interface-guidelines/buttons · https://developer.apple.com/design/human-interface-guidelines/toolbars · https://developer.android.com/develop/ui/compose/components/button · https://github.com/material-components/material-components-android/blob/master/docs/components/CommonButton.md — details: [references/buttons.md](references/buttons.md)

## 6. Navigation chrome
**Top bar (iOS navigation bar = top toolbar; Android top app bar)**
- Title: "Provide a useful title." "Don't title windows with your app name." "Keep the title under 15 characters long." iOS large titles collapse on scroll. Android: small / center-aligned ("single, primary action") / medium / large.
- Back/Close: "Use the standard Back and Close buttons ... don't use a text label that says Back or Close. If you create a custom version ... make sure it still looks the same, behaves as people expect."
- Actions: symbols over text (except Edit-like actions), no bordered symbols, at most ~three groups, one prominent primary at the trailing edge.
- "Choose items deliberately to avoid overcrowding"; overflow goes in a More menu.

**Back behaviour**
- iOS: leading-edge swipe back is expected everywhere in a stack; don't disable it.
- Android: system back from either edge or the 3-button bar; "Predictive back is enabled by default" and lets users "preview where the back swipe takes them." Intercepting back suppresses the preview: "Don't create these callbacks to run business logic or to log." Use them only for UI logic like an unsaved-changes dialog. "Avoid adding touch gestures or drag targets under these gesture areas."

**Tab bar / navigation bar**
- "Use a tab bar to support navigation, not to provide actions."
- Count: HIG gives no number ("easier to navigate among fewer tabs"; "Avoid overflow tabs"); Android: "Three to five destinations of equal importance." Use 3–5.
- "Include tab labels ... Use single words whenever possible." Android hides unselected labels at ≥4 items in AUTO mode, so force labels on.
- "Prefer filled symbols or icons for consistency with the platform."
- Keep it visible across sections (modals excepted). "Don't disable or hide tab bar buttons" — explain empty sections instead.
- Badges: "Reserve badges for critical information."

```tsx
// expo-router Tabs (JS bottom tabs) show labels by default — keep it explicit; native Android
// bottom navigation in AUTO label mode hides unselected labels at ≥4 items
<Tabs screenOptions={{ tabBarShowLabel: true, ...tabBarOptions }} />
// Let native-stack own back; only intercept for UI logic (unsaved changes), never for logging
navigation.addListener("beforeRemove", (e) => { if (!dirty) return; e.preventDefault(); confirmDiscard(() => navigation.dispatch(e.data.action)); });
```

Source: https://developer.apple.com/design/human-interface-guidelines/toolbars · https://developer.apple.com/design/human-interface-guidelines/tab-bars · https://developer.android.com/develop/ui/compose/components/app-bars · https://developer.android.com/develop/ui/compose/components/navigation-bar · https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture · https://developer.android.com/design/ui/mobile/guides/patterns/predictive-back — details: [references/navigation.md](references/navigation.md)

## 7. Forms and data entry
- "Get information from the system whenever possible." "When possible, offer choices instead of requiring text entry."
- Every field gets a visible label; placeholder alone disappears on typing. "Never prepopulate a password field." Secure fields for passwords.
- "Show the appropriate keyboard type" (`number-pad`, `decimal-pad`, `email-address`). Use locale-aware number formatting: "Don't assume the actual presentation of data."
- Validate early: email "when people switch to another field"; user name/password "before people switch." "Dynamically validate field values."
- Required data: "make the button available only after people enter the data you require."
- Error placement (Material anatomy): helper/error text directly under the field, error colour + error icon, announced via a live region. Never colour-only.
- Layout: "Stack multiple text fields vertically ... use consistent widths."
- Pickers: for "medium-to-long lists"; short lists → menu; "Avoid switching views to show a picker." iOS date picker styles: compact ("when space is constrained"), inline, wheels; minute interval must divide 60. Android date picker: "Use a descriptive title for the task."
- Toggles: iOS "Use the switch toggle style only in a list row"; outside lists use a toggle-style button. Material: switches "Immediately activate or deactivate something" — no Save step. State must not be colour-only.
- Segmented controls: "no more than about five segments on iPhone", equal widths, text or icons not both, nouns in title case; for related subviews only — sections belong in tabs.

Source: https://developer.apple.com/design/human-interface-guidelines/entering-data · https://developer.apple.com/design/human-interface-guidelines/text-fields · https://developer.apple.com/design/human-interface-guidelines/pickers · https://developer.apple.com/design/human-interface-guidelines/toggles · https://developer.apple.com/design/human-interface-guidelines/segmented-controls · https://github.com/material-components/material-components-android/blob/master/docs/components/TextField.md — details: [references/forms.md](references/forms.md)

## 8. Modality
| Situation | iOS | Android |
|---|---|---|
| Short scoped task tied to current context | Sheet (medium/large detents, grabber) | Bottom sheet / dialog |
| Complex or multistep task | Full-screen modal | Full-screen dialog / screen |
| Critical, actionable info | Alert (≤3 buttons) | AlertDialog |
| Choices about an action just initiated | Action sheet | Bottom sheet / dialog |
| Non-blocking result + Undo | Inline status | Snackbar |

- "Present content modally only when there's a clear benefit." Keep it short; no "app within your app"; one modal at a time; never two alerts.
- Dismissal: "Always give people an obvious way to dismiss" — top-bar button or swipe down. Sheets: Cancel leading, Done trailing; "If you provide a Done button, always pair it with a Cancel button"; never Cancel + Done + Back together.
- Unsaved work: swipe-to-dismiss with changes → confirm with an action sheet that offers save/discard.
- **When to confirm:** "Avoid displaying alerts for common, undoable actions, even when they're destructive." Confirm "an uncommon destructive action that they can't undo." "Avoid showing an alert when your app starts." Don't use an alert only to inform.
- **Alert wording:** title says what happened, ≤2 lines, not "Error". Buttons: one or two words describing the result ("Delete", "Erase"); "Avoid using OK ... unless the alert is purely informational"; avoid "Yes"/"No"; "Always use 'Cancel'" for cancel. Sentence case, no punctuation. Cancel is never the default.
- Destructive style marks a destructive action "people didn't deliberately choose"; when the person deliberately chose it (Empty Trash), the confirm button isn't styled destructive.
- Action sheets: destructive choices at the top, Cancel at the bottom, no scrolling, title on one line.

```ts
// Uncommon, irreversible action: specific title, result-verb button in sentence case, "Cancel" (never default).
// The person deliberately chose "Delete account", so per Alerts the confirm button is NOT destructive-styled;
// use style "destructive" only when the alert surfaces a destructive outcome they didn't pick.
Alert.alert("Delete your account?", "Your logs and baseline are removed and can't be recovered.", [
  { text: "Cancel", style: "cancel" },
  { text: "Delete account", onPress: deleteAccount },
]);
// Common, undoable delete: no alert — delete, then show inline "Deleted · Undo"
```
- Android snackbar: "brief", "shouldn't interrupt", optional single action like Undo/Retry. Timed UI also has to satisfy Apple's "Minimize use of time-boxed interface elements".

Source: https://developer.apple.com/design/human-interface-guidelines/modality · https://developer.apple.com/design/human-interface-guidelines/sheets · https://developer.apple.com/design/human-interface-guidelines/alerts · https://developer.apple.com/design/human-interface-guidelines/action-sheets · https://developer.android.com/develop/ui/compose/components/dialog · https://developer.android.com/develop/ui/compose/components/snackbar — details: [references/modality.md](references/modality.md)

## 9. Feedback and loading
- Match the interruption to the significance: status inline and passive; data-loss warnings interrupt.
- Confirm only significant completions — people "only need to know when it doesn't" succeed. Explain failures and why.
- "Show something as soon as possible ... placeholder text, graphics, or animations as content loads." This is the guideline basis for skeletons over blank screens; the HIG doesn't name skeletons, so: skeleton/placeholder for content regions with known shape, spinner (indeterminate) for short unknown waits and in-button busy states.
- "When possible, use a determinate progress indicator." Keep it moving and accurate; "Don't switch from the circular style to the bar style." Avoid labels like "Loading".
- Allow Cancel when it's safe. Pull-to-refresh complements automatic refresh and doesn't replace it.
- Haptics (expo-haptics): use patterns by meaning. Notification = "outcome of a task"; Impact = physical metaphor; Selection = "while the values ... are changing." "Avoid overusing haptics." "Make haptics optional." Pair with visual feedback.

Source: https://developer.apple.com/design/human-interface-guidelines/feedback · https://developer.apple.com/design/human-interface-guidelines/loading · https://developer.apple.com/design/human-interface-guidelines/progress-indicators · https://developer.apple.com/design/human-interface-guidelines/playing-haptics — details: [references/feedback-loading-notifications.md](references/feedback-loading-notifications.md)

## 10. Onboarding, accounts, privacy
- Launch screen ≈ first screen, no text, no branding. "Restore the previous state when your app restarts."
- Onboarding: "fast, fun, and optional"; teach interactively; prefer contextual tips; "Postpone nonessential setup"; ask for ratings/purchases only after engagement.
- Accounts: only if core functionality needs one; "Explain the benefits ... in your sign-in view"; "Delay sign-in for as long as possible"; prefer passkeys; name the method ("Sign In with Face ID"); no in-app biometric opt-in setting; don't say "passcode."
- **Sign in with Apple:** when offered, "Make a Sign in with Apple button no smaller than other sign-in buttons, and avoid making people scroll to see the button." Minimum 140×30 pt; margin ≥1/10 of height; 44 pt is the recommended iOS height. Don't then ask for a password; respect private relay email. (Whether you must offer it is App Store Review Guideline 4.8 — see `app-store-publishing`.)
- **Account deletion:** "If you help people create an account within your app ... you must also help them delete it, not just deactivate it." It has to start in-app or from a direct, easy-to-find link. Say when it completes and notify when done. If the law requires keeping records (health), "clearly describe the situation." Subscriptions keep billing through Apple until cancelled — tell people.
- **Permissions:** ask "only when your app clearly needs access", ideally when the feature is first used, not at launch. Purpose string: one active, specific sentence with a period.
- **Pre-permission screens:** "Include only one button and make it clear that it opens the system alert" — "Continue"/"Next", never "Allow". "Don't provide a way for people to leave the screen ... without viewing the system alert — like offering an option to close or cancel." Optionality belongs before the screen (a separate entry point), not as a Skip on it.
- Settings: minimal, good defaults; don't duplicate system settings; task options live on their screen.

Source: https://developer.apple.com/design/human-interface-guidelines/launching · https://developer.apple.com/design/human-interface-guidelines/onboarding · https://developer.apple.com/design/human-interface-guidelines/managing-accounts · https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple · https://developer.apple.com/design/human-interface-guidelines/privacy · https://developer.apple.com/design/human-interface-guidelines/settings — details: [references/onboarding-accounts-privacy.md](references/onboarding-accounts-privacy.md)

## 11. Lists, charts and data
- Lists for text; grouped style for sections (headers, footers, spacing). Drill-in rows get a disclosure chevron; option rows get a checkmark. Keep row text succinct; let rows grow with Dynamic Type.
- Don't nest same-direction scroll views. Signal more content with partial items at the edge.
- Chart only when it highlights something: "Not every collection of data needs to be displayed in a chart." "Keep a chart simple." Prefer bar/line; teach novel charts.
- Axes: fixed range when bounds mean something; zero baseline for bars; non-zero when zero hides differences; familiar tick steps (0, 5, 10).
- "Summarize the main message of your chart" in a title/subtitle; "don't require interaction to reveal critical information."
- Compact screens: maximise plot width, short Y labels, units in the title. Small marks → make the whole plot area the scrub target.
- Colour: "Avoid relying solely on color to differentiate between different pieces of data" — add shapes/patterns; separate adjacent colour areas.
- Accessibility: "Make every chart in your app accessible." Provide an overview (type, axes, bounds) and per-element or grouped labels with context. No subjective words; "June 6" not "6/6"; describe meaning, not colour. Hide axis/tick text from screen readers. Announce changes.
- Same data across sizes (sparkline → detail) keeps the same type, colours and annotations.

Source: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables · https://developer.apple.com/design/human-interface-guidelines/scroll-views · https://developer.apple.com/design/human-interface-guidelines/charts · https://developer.apple.com/design/human-interface-guidelines/charting-data — details: [references/charts-lists.md](references/charts-lists.md)

## 12. Accessibility checklist
- [ ] Every interactive element has `accessibilityRole` and a purpose label ("Submit", not "Submit button"); list items have unique labels; decorative icons are hidden.
- [ ] Selected / disabled / checked are exposed via `accessibilityState` **and** shown visually by more than colour (fill, weight, checkmark, outline).
- [ ] Targets ≥44×44 pt iOS / ≥48×48 dp Android, with spacing (~12 pt bezeled, ~24 pt non-bezeled).
- [ ] Text scales: the layout survives AX5 (Body 53 pt) without clipping or overlap; text up to 200%; rows grow; side-by-side items stack.
- [ ] Contrast ≥4.5:1 for text under 18 pt (non-bold), ≥3:1 otherwise, in every supported appearance.
- [ ] No information by colour alone (charts, status, validation, tabs).
- [ ] Reduce Motion: tighter springs, fades instead of slides/zooms, no blur/depth animation (`useReducedMotion`).
- [ ] Every gesture has a button alternative (swipe-delete → also a Delete button/menu).
- [ ] No auto-dismissing UI as the only path; dismiss on explicit action.
- [ ] Charts: summary label plus element labels; axis text hidden from readers.
- [ ] Feedback reaches multiple senses (text + haptic/visual), and haptics are optional.
- [ ] Errors are announced (live region / announceForAccessibility) and placed next to their field.
- [ ] Verify with VoiceOver, TalkBack, Larger Text and Bold Text on.

```tsx
<Pressable
  accessibilityRole="button"                      // or "switch", "tab", "header", "link"
  accessibilityLabel="Breakfast"                  // purpose, no "button"
  accessibilityState={{ selected: isSelected, disabled }}
  style={[styles.chip, isSelected && styles.chipSelected /* border + weight, not colour only */]}
/>
const reduceMotion = useReducedMotion();          // react-native-reanimated
const entering = reduceMotion ? FadeIn : SlideInRight;
```

Source: https://developer.apple.com/design/human-interface-guidelines/accessibility · https://developer.apple.com/design/human-interface-guidelines/typography · https://developer.apple.com/design/human-interface-guidelines/charts · https://developer.android.com/guide/topics/ui/accessibility/apps — details: [references/accessibility.md](references/accessibility.md)

## 13. Notifications
- Get consent first (permission timing rules in section 10). "Provide concise, informative notifications."
- "Avoid sending multiple notifications for the same thing, even if someone hasn't responded."
- Don't tell people to go do a task in the app; offer a notification action if it can be done inline.
- "Use an alert — not a notification — to display an error message."
- "Avoid including sensitive, personal, or confidential information in a notification" — no weights, calories or medication status in the visible text. Write a generic hidden-preview body ("Reminder").
- Title: short, title-case, no ending punctuation, no app name. Body: complete sentences in sentence case; don't truncate it yourself.
- Actions: up to four; title-case verbs; never one that just opens the app; prefer nondestructive; each with an icon.
- Badge = unread notification count only, never the only signal, kept current, never faked.
- Foreground arrivals: update the view or badge quietly instead of interrupting.

Source: https://developer.apple.com/design/human-interface-guidelines/notifications — details: [references/feedback-loading-notifications.md](references/feedback-loading-notifications.md)

---

## Iduna mapping
Files: `apps/mobile/src/theme/tokens.ts`, `src/theme/useTheme.ts`, `src/theme/makeStyles.ts`, `src/theme/navigation.ts`, `src/components/ui/Button.tsx`, `src/components/BackButton.tsx`. `Button` (minHeight 44 + hitSlop 8) meets 44 pt and, effectively, 48 dp.
| Token / component | Guideline role |
|---|---|
| `colors.ink` / `inkMuted` / `inkSubtle` (dark `#ececec` / `#c2c2c2` / `#9a9a9a`) | label / secondaryLabel / tertiaryLabel (iOS); onSurface / onSurfaceVariant (Material) |
| `colors.accent` (+ `accentSoft`, `accentTint`; light `#2563eb`, dark `#60a5fa` = `accentNight` in `app.config.ts`, which also tints Android's `values-night` picker/alert resources) | app tint: links, text buttons, active tab, selection (Material primary) |
| `colors.danger` (dark `#f87171`; also the chart/heat "outside" red in both palettes) | destructive role / system red / Material error |
| `colors.surface` / `surfaceAlt`, `border` (dark `#121212` / `#1e1e1e`, `#2e2e2e`) | systemBackground / secondarySystemBackground, separator |
| `useTheme()` → `{ scheme, colors }`; `makeStyles((colors) => ({…}))` → `useStyles()` | "provide both light and dark colors": every screen builds its styles from the active palette; components never import `lightColors`/`darkColors` (static guard) and every text style carries a `color` (text-colour guard) |
| `type.title` 24 · `display` 28 | Title 1 (28) range; Material headlineSmall (24) / headlineMedium (28) |
| `type.heading` 17/600 | iOS Headline (17 semibold), also the nav-bar title via `useHeaderOptions()` |
| `type.body` 16 / lh 22 | Material bodyLarge (16); one point under iOS Body (17), chosen to keep dense rows and the share image on one line (IDNA-102 D1) |
| `type.caption` 13 · `label` 12 | Footnote 13 · Caption 1 12 (both above the 11 pt floor) |
| `space` 4/8/12/16/24/32 | matches the Android 4/8 dp grid; HIG gives no grid |
| `Button` primary (ink fill) | the one prominent action per screen (HIG prominent uses the accent colour; ink is a brand choice) |
| `Button` secondary (ink outline) | Material outlined / HIG less-prominent alternative |
| `Button` destructive (danger fill) | destructive role; never the default or primary action in a pair |
| `Button` text (accent); `leadIn` two-tone; `selected` = 2 pt accent outline on `accentSoft` | Material text / route switches like "Don't have an account? **Sign up**"; selection shown by more than colour |
| `BackButton` (platform glyph only: Material arrow / iOS chevron, a11y label "Back") | custom back for headerless onboarding/auth steps |
| `useHeaderOptions()` / `useTabBarOptions()` + `navigationTheme()` | top bar title style + tint; tab active `accent`, inactive `inkSubtle`; expo-router's `ThemeProvider` keyed to the system scheme so native chrome and modals flip with it |
### Open deviations
Resolved by IDNA-094 (2026-10-16), IDNA-102 (2026-10-19) and IDNA-103 (2026-10-20): body size (now 16), `inkSubtle` contrast (#6b6b6b, 5.3:1), heat-map header/caption contrast and glyph weight, `success` documented as fill / ≥18 pt only, chevron-only back control, no app-name title, tab icons (iOS filled in both states; Android keeps Material's outlined-inactive), `Button` built-in `selected` visual, native picker tint via a config plugin, two-tone cross links, and dark mode following the system appearance (`userInterfaceStyle: "automatic"`, no in-app toggle; every dark text token ≥ 4.5:1 on every surface it sits on, chart/heat tiers per palette). Known light-palette floors below 4.5:1 (danger/warning on `surfaceAlt`, danger on `accentSoft`, surface glyph on `heat.mild`) are pinned as `LIGHT_FLOORS` in `tokens.test.ts`, unticketed.

- **Accepted deviation — two-button pre-permission screens.** `permissions.tsx`, `pre-permission.tsx` and `health-connect.tsx` keep a "Not now" escape beside the primary action. Privacy says a pre-alert screen gets "only one button" and no way to leave without the system alert. Iduna's IDNA-051/052/053 product decision is that a user must be able to decline without seeing the system prompt (no-pressure stance for an ED-sensitive audience). Recorded 2026-10-19 (IDNA-102 D16); revisit only if App Review objects.
- Log-tab delete confirmations alert on every delete with a destructive "Delete". Alerts: avoid alerts "for common, undoable actions". Deletes are soft, so the fix is delete + inline Undo — filed as **IDNA-104**.
- Drift breakdown radar's only legend is a one-line caption; the grey no-data spokes and red outside-range labels are unexplained for sighted users — filed as **IDNA-105**.
