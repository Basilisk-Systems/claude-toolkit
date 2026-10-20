# Accessibility

Sources:
- https://developer.apple.com/design/human-interface-guidelines/accessibility
- https://developer.apple.com/design/human-interface-guidelines/typography
- https://developer.apple.com/design/human-interface-guidelines/charts
- https://developer.apple.com/design/human-interface-guidelines/feedback
- https://developer.apple.com/design/human-interface-guidelines/sheets
- https://developer.android.com/guide/topics/ui/accessibility/apps

Principles: an accessible interface is "Intuitive", "Perceivable" ("doesn't rely on any single method to convey information"), "Adaptable."

## Vision
- "Support larger text sizes ... Ideally, give people the option to enlarge text by at least 200 percent."
- Text sizes: iOS default 17 pt, minimum 11 pt.
- Contrast: up to 17 pt → 4.5:1; 18 pt+ or bold → 3:1 (Accessibility Inspector, WCAG AA). Check in light and dark.
- "Prefer system-defined colors" — they adapt to Increase Contrast.
- "Convey information with more than color alone."
- "Describe your app's interface and content for VoiceOver."

## Mobility
| Platform | Default control | Minimum control |
|---|---|---|
| iOS, iPadOS | 44x44 pt | 28x28 pt |
| Android | 48x48 dp ("Larger is even better") | — |
- "Consider spacing between controls as important as size": ~12 pt padding around bezeled elements, ~24 pt around non-bezeled.
- "Support simple gestures for common interactions ... avoid custom multifinger and multihand gestures."
- "Offer alternatives to gestures ... if you use a swipe gesture to dismiss a view, also make a button available."
- Voice Control needs good labels. Support Switch Control, Full Keyboard Access.

## Hearing
- Pair audio cues with haptics and visual cues. Captions/transcripts for media.

## Cognitive
- "Prefer system gestures and behaviors people are already familiar with."
- "Minimize use of time-boxed interface elements ... Prefer dismissing views with an explicit action."
- "Avoid autoplaying audio and video content without also providing controls."
- Reduce Motion: "reduce automatic and repetitive animations, including zooming, scaling, and peripheral motion." Practices:
  - "Tightening animation springs to reduce bounce effects"
  - "Tracking animations directly with people's gestures"
  - "Avoiding animating depth changes in z-axis layers"
  - "Replacing transitions in x-, y-, and z-axes with fades"
  - "Avoiding animating into and out of blurs"
- Assistive Access: one interaction per screen; "Always ask for confirmation twice whenever people perform an action that's difficult to recover from."

## Screen-reader labels (Android page, applies equally to VoiceOver)
- "Use descriptions to convey the purpose and result of the interaction, not the visual details."
- Expose the type via role ("Role.Button or Role.Switch") so readers announce it correctly.
- "Avoid redundancies ... make the button's description 'Submit', not 'Submit button'."
- "Each description should be unique" — list items reflect their own content.
- Hide purely decorative elements from assistive tech.
- Text elements don't need a separate description — the text is announced.

## Charts
- "Make every chart in your app accessible." Provide a chart overview (type, axes, bounds) and labels per important element or group.
- Labels: give context with the value; "Avoid using subjective terms"; "'June 6' is clearer than '6/6'"; "Describe what the chart's details represent, not what they look like."
- "Hide visible text labels for axes and ticks from assistive technologies."
- Announce changes; don't rely on animation alone.

## Feedback
- "Make sure all feedback is accessible" — combine color, text, sound, haptics.

## React Native mapping (implementation)
| Need | RN prop |
|---|---|
| Name | `accessibilityLabel` (verb/purpose, no "button") |
| Type | `accessibilityRole` ("button", "switch", "header", "image", "link", "tab") |
| Selected / disabled / checked | `accessibilityState={{ selected, disabled, checked }}` |
| Extra info | `accessibilityHint` (result of action) |
| Value of slider/progress | `accessibilityValue` |
| Decorative | `accessible={false}` / `importantForAccessibility="no-hide-descendants"` |
| Live error text | `accessibilityLiveRegion="polite"` (Android) + `AccessibilityInfo.announceForAccessibility` |
| Reduce Motion | `AccessibilityInfo.isReduceMotionEnabled()` / Reanimated `useReducedMotion()` |
| Extend target | `hitSlop` (doesn't change layout) or `minHeight/minWidth` |
