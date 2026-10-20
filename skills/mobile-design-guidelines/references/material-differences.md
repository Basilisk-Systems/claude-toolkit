# Where Android (Material 3) differs from iOS (HIG)

m3.material.io is client-rendered and could not be fetched; Material content below comes from server-rendered official sources:
- https://developer.android.com/develop/ui/compose/components/button
- https://developer.android.com/develop/ui/compose/components/app-bars
- https://developer.android.com/develop/ui/compose/components/navigation-bar
- https://developer.android.com/develop/ui/compose/components/dialog
- https://developer.android.com/develop/ui/compose/components/snackbar
- https://developer.android.com/develop/ui/compose/designsystems/material3
- https://developer.android.com/guide/topics/ui/accessibility/apps
- https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture
- https://developer.android.com/design/ui/mobile/guides/patterns/predictive-back
- https://developer.android.com/design/ui/mobile/guides/foundations/system-bars
- https://developer.android.com/design/ui/mobile/guides/layout-and-content/grids-and-units
- https://developer.android.com/develop/ui/views/theming/darktheme
- https://github.com/material-components/material-components-android/tree/master/docs (components/*.md, theming/Color.md, theming/Typography.md)

## Differences that matter for a shared RN codebase
| Topic | iOS (HIG) | Android (Material 3 / Android guides) | Shared-code decision |
|---|---|---|---|
| Touch target | 44x44 pt default, 28x28 pt minimum | 48x48 dp | Use 48 as the floor everywhere (satisfies both) |
| Grid | Not specified on HIG layout page | "8 dp grid for layout, components, and spacing"; 4 dp for icons/type | 4/8 spacing scale |
| Text units | pt, Dynamic Type text styles | sp ("Always specify font sizes in sp") | RN `fontSize` scales with OS on both |
| Body size | Body 17 pt | bodyLarge 16 sp | 16–17 |
| Contrast rule | ≤17 pt 4.5:1; ≥18 pt or bold 3:1 | <18 sp (or bold <14 sp) 4.5:1; otherwise 3:1 | 4.5:1 for all body/caption text |
| Back | Leading-edge swipe + nav-bar chevron; no "Back" text label | System back gesture from either edge / 3-button; predictive back preview; optional app-bar arrow | Let expo-router/native-stack own back; don't intercept |
| Top bar title | Leading large title collapsing, or centered standard title; <15 chars | Small (leading title), center-aligned, medium, large | Native-stack defaults per platform |
| Bottom nav count | Not specified (fewer is easier; avoid More overflow) | "Three to five destinations of equal importance" | 3–5 |
| Bottom nav labels | "Include tab labels" (single words) | Icon + label; AUTO mode hides unselected labels at ≥4 items | Always show labels |
| Tab icons | "Prefer filled symbols" | Selected state highlighted (style not specified in fetched sources) | Filled; selection also via label weight/colour |
| Primary button | Prominent style, accent background; 1–2 per view | Filled (high emphasis) | One filled primary |
| Secondary | Less prominent style | Outlined (medium) / tonal | Outlined |
| Low-emphasis / links | Plain/borderless | Text button ("navigational links") | Text button |
| Destructive | Destructive role → system red; never primary role | `colorError` roles | Danger colour + explicit verb |
| Confirm dialog | Alert: up to 3 buttons, Cancel leading/bottom, default trailing/top | AlertDialog confirm + dismiss slots | Native `Alert.alert` gives each platform its own layout |
| Choice after action | Action sheet (destructive on top, Cancel bottom) | Bottom sheet / dialog | `ActionSheetIOS` on iOS, sheet on Android |
| Transient confirmation | No system toast; inline status | Snackbar with optional Undo | Inline status on both, or a custom snackbar that is not the only path |
| Switch | Only in list rows; default green | "Toggle a single item on or off; Immediately activate" | Switch = immediate effect, in rows |
| Dark mode | Follow system; avoid in-app appearance setting | In-app Light/Dark/System allowed, System default recommended | Follow system; no toggle unless asked |
| Dynamic colour | n/a | Android 12+ wallpaper-derived scheme | Optional; brand palette is fine |
| Edge-to-edge | Respect safe areas | Enforced on Android 15; no targets under gesture insets; transparent gesture bar | `react-native-safe-area-context` insets on both |
| Date picker | Compact / inline / wheels | Material date picker dialog with descriptive title | `@react-native-community/datetimepicker` native per platform |

## Predictive back details (Android only)
- "Predictive back is enabled by default"; Android 15+ shows back-to-home, cross-task, cross-activity animations for supporting apps.
- Intercepting back (PRIORITY_DEFAULT/OVERLAY callbacks) disables the system animation; "Don't create these callbacks to run business logic or to log."
- "Avoid adding touch gestures or drag targets under these gesture areas."
- In-app full-screen preview spec (if custom): exit scale 100%→90%, enter 110%→100%, fade-through at 35% progress.
- "Only the system can dismiss the app window itself."

## Material colour roles (Color.md)
Groups: Primary, Secondary, Tertiary, Error, Surface — "each with 4-5 color roles." Every container role has a paired on-role (onPrimary, onPrimaryContainer, onError, onSurface, onSurfaceVariant...). Surfaces: surface, surfaceDim, surfaceBright, surfaceContainerLowest → Highest replace elevation overlays.
