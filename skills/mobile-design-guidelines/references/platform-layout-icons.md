# Platform posture, layout, materials, icons

Sources:
- https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
- https://developer.apple.com/design/human-interface-guidelines/layout
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/design/human-interface-guidelines/icons
- https://developer.apple.com/design/human-interface-guidelines/sf-symbols
- https://developer.apple.com/design/human-interface-guidelines/app-icons
- https://developer.apple.com/design/whats-new/
- https://developer.android.com/design/ui/mobile/guides/layout-and-content/grids-and-units

## Designing for iOS — best practices
- "Help people concentrate on primary tasks and content by limiting the number of onscreen controls while making secondary details and actions discoverable with minimal interaction."
- "Adapt seamlessly to appearance changes — like device orientation, Dark Mode, and Dynamic Type."
- Reach: controls "in the middle or bottom area of the display" are easier; support swipe-back and swipe row actions.
- "With people's permission, integrate information available through platform capabilities ... without asking people to enter data."

## Layout
- "Order content by relative importance" — top and leading side first.
- "Align elements ... use indentation to convey hierarchy." "Group related items" with negative space, containers, separators.
- "Use progressive disclosure."
- "Differentiate controls from content" — on iOS 26 via Liquid Glass + scroll edge effects rather than solid bar backgrounds.
- "Be prepared for text-size changes" — stack horizontally adjacent views, grow rows.
- "Determine layout based on size classes, not device type or orientation." "Keep functionality the same as size classes change."
- Safe area: "Respecting the safe area is essential."
- Margins and grid: the HIG layout page states no margin or grid values ("not specified"); it points to system layout guides and Apple Design Resources templates. Android: 8 dp grid, 4 dp for small elements.

## Liquid Glass (iOS 26, added June 2025, revised Sept/Dec 2025)
- "Liquid Glass forms a distinct functional layer for controls and navigation elements — like tab bars and sidebars — that floats above the content layer."
- "Don't use Liquid Glass in the content layer." "Use Liquid Glass effects sparingly." "Standard components from system frameworks pick up the appearance and behavior of this material automatically."
- Regular variant for text-heavy components; clear variant only over rich media, with a 35% dimming layer if content is bright.
- Standard materials (ultraThin, thin, regular, thick) for the content layer.

## Icons
- "Create a recognizable, highly simplified design." "Maintain visual consistency across all interface icons" — size, detail, stroke weight, perspective.
- "Match the weights of interface icons and adjacent text."
- Add padding for optical centering of asymmetric icons.
- SF Symbols: four rendering modes (monochrome, hierarchical, palette, multicolor); symbols may not be used in app icons or logos.
- RN note: Ionicons/Material icons stand in for SF Symbols; keep one family and one weight.

## App icons (iOS)
- 1024x1024 px square, layered; appearances: default, dark, clear light/dark, tinted light/dark.
- "Prefer illustrations to photos and avoid replicating UI components." "Keep primary content centered."
- "Use your light app icon as the basis for your dark icon."
