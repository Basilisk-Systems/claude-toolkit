# Lists, charts, scroll views

Sources:
- https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- https://developer.apple.com/design/human-interface-guidelines/charts
- https://developer.apple.com/design/human-interface-guidelines/charting-data
- https://developer.apple.com/design/human-interface-guidelines/scroll-views
- https://github.com/material-components/material-components-android/blob/master/docs/components/List.md

## Lists
- "Prefer displaying text in a list or table." Varying sizes / many images → collection (grid).
- "Let people edit a table when it makes sense" — reorder at least.
- Selection feedback: navigation lists highlight the row persistently; option lists flash, then show a checkmark.
- "Keep item text succinct"; long items → title only + detail view. Middle-ellipsis can keep items distinguishable.
- Style: iOS grouped style "uses headers, footers, and additional space to separate groups."
- iOS: drill-in uses a disclosure indicator (chevron); info button only reveals info about the row. Don't combine an index with trailing accessories.
- Material: "Use lists to help users find a specific item and act on it."

## Scroll views
- "Make it apparent when content is scrollable" — partial content at the edge.
- "Avoid putting a scroll view inside another scroll view with the same orientation." Horizontal inside vertical is fine.
- Auto-scroll only as much as needed (e.g. focused field hidden by keyboard).
- Paged scroll → page control, and no scroll indicator on the same axis.
- Refresh control: "Perform automatic content updates ... Don't make people responsible for initiating every update." Title only if it adds value (e.g. last updated time), never instructions.
- Scroll edge effects (iOS 26): only behind floating UI; one per view; prefer automatic style.

## When to chart
- "Not every collection of data needs to be displayed in a chart" — plain data → list/table.
- "Use a chart when you want to highlight important information about a dataset."
- "Keep a chart simple, letting people choose when they want additional details."
- "In general, prefer using common chart types" (bar, line). Novel chart → teach how to read it.

## Marks and axes
- Bar: compare categories / parts of a whole; over time when each value is a sum (daily steps).
- Line: change over time; slope shows trend. Points on the line to highlight individual values.
- Point: relationships, outliers.
- Axis range: fixed when min/max are meaningful (0–100%); dynamic when values vary widely.
- Lower bound: zero for bars; non-zero when zero hides meaningful differences (heart rate).
- "Prefer familiar sequences of values" for ticks (0, 5, 10).
- Grid lines: enough to estimate, not so many they overwhelm; fewer if the chart is interactive.

## Descriptive content
- "Write descriptions that help people understand what a chart does before they view it."
- "Summarize the main message of your chart" — title/subtitle with the takeaway (Weather's "Chance of light rain in the next hour").
- A headline "doesn't take the place of accessibility labels."

## Layout and interaction
- Data most prominent; axes/labels secondary.
- Compact width: "maximize the width of the plot area"; short Y labels; units in the title.
- "Don't require interaction to reveal critical information."
- Small marks: "consider expanding the hit target to include the entire plot area, letting people scrub."
- Align chart leading edge with surrounding views; Y axis may go trailing.
- "Prefer consistency across multiple charts"; same dataset → same type, colors, annotations across sizes.
- "Match the size of a chart to its functionality."

## Colour in charts
- "Avoid relying solely on color to differentiate between different pieces of data" — use shapes/patterns (Health uses two point shapes for blood pressure).
- "Add visual separation between contiguous areas of color" (stacked bars).
- Consider letting people customize chart colours (Accessibility page).

## Chart accessibility
- Overview: chart type, what each axis represents, axis bounds (or Audio Graphs on native).
- Label each important element, or groups, depending on purpose (Health: each bar; Maps: summarized segments).
- Context + value; no subjective words ("rapidly"); unambiguous formats ("June 6", "60 minutes").
- Describe meaning, not colours. Consistent axis order.
- Hide visible axis/tick labels from assistive tech.
- Announce chart changes; animation alone is not enough.
- RN: wrap the chart in a `View` with `accessibilityRole="image"` + summary label for small charts; expose per-point elements only if per-value reading is the point.
