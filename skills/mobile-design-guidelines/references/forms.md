# Forms and data entry

Sources:
- https://developer.apple.com/design/human-interface-guidelines/entering-data
- https://developer.apple.com/design/human-interface-guidelines/text-fields
- https://developer.apple.com/design/human-interface-guidelines/pickers
- https://developer.apple.com/design/human-interface-guidelines/toggles
- https://developer.apple.com/design/human-interface-guidelines/segmented-controls
- https://developer.apple.com/design/human-interface-guidelines/labels
- https://github.com/material-components/material-components-android/blob/master/docs/components/TextField.md
- https://github.com/material-components/material-components-android/blob/master/docs/components/Switch.md
- https://github.com/material-components/material-components-android/blob/master/docs/components/DatePicker.md

## Entering data
- "Get information from the system whenever possible" (settings, permission-gated data).
- "Be clear about the data you need" — prompt in the field or an introductory label; "prefill fields with reasonable default values."
- "Never prepopulate a password field."
- "When possible, offer choices instead of requiring text entry" (picker, menu).
- "Dynamically validate field values ... provide feedback as soon as you detect a problem." "Consider using a number formatter."
- "If you include a Next or Continue button after a set of text fields, make the button available only after people enter the data you require."
- Support paste / drag and drop.

## Text fields (iOS)
- For "a small amount of information"; larger text → text view.
- Placeholder disappears on typing, so "include a separate label describing the field."
- "Always use a secure text field when your app asks for sensitive data."
- "Match the size of a text field to the quantity of anticipated text."
- "Stack multiple text fields vertically when possible, and use consistent widths."
- Validation timing: email → "validate when people switch to another field"; user name/password → "before people switch to another field."
- Number formatters: "Don't assume the actual presentation of data ... formatting can vary significantly based on people's locale."
- "Show the appropriate keyboard type."
- iOS: "Display a Clear button in the trailing end." Leading end = field purpose, trailing = extra features.

## Text fields (Material, Android)
- Two variants: Filled and Outlined.
- Anatomy includes helper text and error text below the field; error uses `colorError` and an error icon; the error text has an accessibility live region. → place errors directly under the field they describe, with icon + text, not colour alone.
- Default max width 488dp; min width 56dp without label.

## Pickers and date pickers
- Picker for "medium-to-long lists"; short list → pull-down button / menu; very large → list.
- "Use predictable and logically ordered values."
- "Avoid switching views to show a picker" — show it in context.
- Minute interval may be coarsened if it "divides evenly into 60" (e.g. 0/15/30/45).
- iOS styles: Compact (button → modal editor; "Use a compact date picker when space is constrained"), Inline, Wheels, Automatic. Modes: Date, Time, Date and time, Countdown timer (max 23 h 59 min).
- "The exact values shown in a date picker, and their order, depend on the device location."
- Material date picker: "Use a descriptive title for the task" (e.g. "Select appointment date") — read by screen readers.

## Toggles / switches
- "Use a toggle to help people choose between two opposing values that affect the state of content."
- "Make sure the visual differences in a toggle's state are obvious ... Avoid relying solely on different colors."
- iOS: "Use the switch toggle style only in a list row." "Outside of a list, use a button that behaves like a toggle, not a switch."
- iOS: "Change the default color of a switch only if necessary" (default green; accent ok with enough contrast).
- Material: "Use switches to: Toggle a single item on or off; Immediately activate or deactivate something" — i.e. a switch applies instantly, no Save.

## Segmented controls
- For "closely related choices that affect an object, state, or view."
- "Aim for no more than about five to seven segments in a wide interface and no more than about five segments on iPhone."
- "Keep segment size consistent." "Prefer using either text or images — not a mix." "Use nouns or noun phrases ... title-style capitalization." No introductory text needed.
- Don't mix action segments with selection segments.
- iOS: switch "between closely related subviews"; for separate sections use a tab bar.
- Material equivalent: not covered in fetched sources (M3 uses segmented buttons / button groups; spec page is JS-only).

## Labels
- Label colors: label (primary), secondaryLabel (subheading), tertiaryLabel ("unavailable item or behavior"), quaternaryLabel (watermark).
- "Make useful label text selectable" — error messages, locations.
