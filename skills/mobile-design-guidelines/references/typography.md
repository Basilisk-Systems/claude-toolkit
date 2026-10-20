# Typography and Dynamic Type

Sources:
- https://developer.apple.com/design/human-interface-guidelines/typography
- https://developer.apple.com/design/human-interface-guidelines/accessibility (Vision)
- https://developer.apple.com/design/human-interface-guidelines/layout (Adaptability)
- https://developer.android.com/develop/ui/compose/designsystems/material3
- https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md
- https://developer.android.com/design/ui/mobile/guides/layout-and-content/grids-and-units

## Size floors (iOS)
| Platform | Default size | Minimum size |
|---|---|---|
| iOS, iPadOS | 17 pt | 11 pt |

- "Follow the recommended default and minimum text sizes for each platform — for both custom and system fonts."
- "If you use a custom font with a thin weight, aim for larger than the recommended sizes."
- "In general, avoid light font weights ... prefer Regular, Medium, Semibold, or Bold ... avoid Ultralight, Thin, and Light."
- Accessibility: "Ideally, give people the option to enlarge text by at least 200 percent."

## iOS text styles at the default ("Large") Dynamic Type size
| Style | Weight | Size pt | Leading pt | Emphasized |
|---|---|---|---|---|
| Large Title | Regular | 34 | 41 | Bold |
| Title 1 | Regular | 28 | 34 | Bold |
| Title 2 | Regular | 22 | 28 | Bold |
| Title 3 | Regular | 20 | 25 | Semibold |
| Headline | Semibold | 17 | 22 | Semibold |
| Body | Regular | 17 | 22 | Semibold |
| Callout | Regular | 16 | 21 | Semibold |
| Subhead | Regular | 15 | 20 | Semibold |
| Footnote | Regular | 13 | 18 | Semibold |
| Caption 1 | Regular | 12 | 16 | Semibold |
| Caption 2 | Regular | 11 | 13 | Semibold |

Range: at xSmall Body is 14 pt; at xxxLarge Body is 23 pt; at AX5 (largest accessibility size) Body is 53 pt, Large Title 60 pt, Caption 2 40 pt. Full tables per size are on the typography page (Specifications).

## Material 3 type scale (Android, sp)
| Role | Size/line height | Weight |
|---|---|---|
| displayLarge / Medium / Small | 57/64, 45/52, 36/44 | Regular |
| headlineLarge / Medium / Small | 32/40, 28/36, 24/32 | Regular |
| titleLarge | 22/28 | Regular (Typography.md) |
| titleMedium / titleSmall | 16/24, 14/20 | Medium |
| bodyLarge / Medium / Small | 16/24, 14/20, 12/16 | Regular |
| labelLarge / Medium / Small | 14/20, 12/16, 11/16 | Medium |

"Emphasized styles are used to create hierarchy and are recommended for showing selection, actions, headlines" (e.g. titleMedium emphasized = Bold 16sp).

## Rough cross-platform mapping (author's mapping, not in either guideline)
| Purpose | iOS style | Material role |
|---|---|---|
| Screen title in content | Title 1 (28) / Large Title (34) | headlineMedium (28) / headlineSmall (24) |
| Section heading | Headline (17 semibold) | titleMedium (16 medium) |
| Body text | Body (17) | bodyLarge (16) |
| Secondary text | Subhead (15) / Footnote (13) | bodyMedium (14) |
| Captions, axis labels | Caption 1 (12) | bodySmall (12) / labelMedium (12) |
| Button label | Headline/Body weight | labelLarge (14 medium) |

## Hierarchy
- "Adjust font weight, size, and color as needed to emphasize important information."
- "Minimize the number of typefaces you use."
- "Prioritize important content when responding to text-size changes" — people "don't always want to increase the size of every word" (e.g. tab titles).
- "If you need to display three or more lines of text, avoid tight leading."

## Dynamic Type / font scaling rules
- "Make sure your app's layout adapts to all font sizes." Test with "Larger Accessibility Text Sizes" on.
- "Increase the size of meaningful interface icons as font size increases."
- "Keep text truncation to a minimum as font size increases ... aim to display as much useful text at the largest accessibility font size as you do at the largest standard font size."
- "Consider using a stacked layout where text appears above secondary items" at large sizes; "Reduce the number of columns."
- "Maintain a consistent information hierarchy regardless of the current font size."
- Layout: "horizontally adjacent views may need to stack vertically ... table rows ... may need to grow in height so that text isn't cropped."
- Custom fonts must implement the same behaviors as system fonts (Dynamic Type, Bold Text).
- Android: "Always specify font sizes in sp units or scalable pixels." "Notate specs in dp and sp, instead of pixels."

## React Native notes (implementation, not guideline)
- RN `Text` scales with the OS setting by default (`allowFontScaling` true). Don't disable it; if a fixed-size element would break, cap with `maxFontSizeMultiplier` on that element only, never globally.
- Avoid fixed `height` on text containers; use padding + `minHeight`.
- System font in RN = SF Pro on iOS, Roboto on Android — matches both guidelines.
